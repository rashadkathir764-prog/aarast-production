import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test, after } from 'node:test';

const scratch = mkdtempSync(path.join(os.tmpdir(), 'aarast-walk-ownership-'));
after(() => rmSync(scratch, { recursive: true, force: true }));
const source = fileURLToPath(new URL('./walks.ps1', import.meta.url));
const repo = path.join(scratch, 'my project');
const entry = path.join(repo, 'backend', 'src', 'main.ts').replaceAll('\\', '/');
const other = path.join(scratch, 'other-project', 'src', 'main.ts').replaceAll('\\', '/');

function shutdown(processes, owners) {
  const data = Buffer.from(JSON.stringify({ source, repo, processes, owners })).toString('base64');
  const probe = path.join(scratch, 'probe.ps1');
  // Run the real pre-clean shutdown statements, with OS enumeration and the
  // destructive operation mocked. Nothing can stop a process or reseed a DB.
  writeFileSync(probe, `
$ErrorActionPreference = 'Stop'
$caseData = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${data}')) | ConvertFrom-Json
$repo = $caseData.repo
$script:stopped = @()
$script:port = $null
function Get-CimInstance {
  param($Filter)
  if ($Filter -ne "Name='node.exe'") { throw 'Only Node may be enumerated' }
  $caseData.processes
}
function Get-NetTCPConnection {
  [CmdletBinding()] param($State, $LocalPort)
  if ($State -ne 'Listen') { throw 'Only listeners may own the API' }
  $script:port = $LocalPort
  foreach ($owner in $caseData.owners) { [pscustomobject]@{OwningProcess=$owner} }
}
function Stop-Process {
  [CmdletBinding()] param([int]$Id, [switch]$Force)
  $script:stopped += $Id
}
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($caseData.source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Walk script must parse' }
$tryBlock = $ast.Find({ param($a) $a -is [Management.Automation.Language.TryStatementAst] }, $true)
$statements = @()
foreach ($statement in $tryBlock.Body.Statements) {
  if ($statement.Extent.Text.Contains("'walks-clean.ps1'")) { break }
  $statements += $statement.Extent.Text
}
if (-not $statements.Count) { throw 'Walk shutdown must be inspected before reseeding' }
& ([scriptblock]::Create(($statements -join [Environment]::NewLine)))
[pscustomobject]@{stopped=@($script:stopped); port=$script:port} | ConvertTo-Json -Compress
`);
  const shell = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
  const run = spawnSync(shell, ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', probe], {
    encoding: 'utf8', timeout: 30000,
  });
  assert.ifError(run.error);
  assert.equal(run.status, 0, run.stderr);
  return JSON.parse(run.stdout.trim());
}

test('walk shutdown stops only this checkout entry bound to the walk API port', () => {
  const result = shutdown([
    { ProcessId: 11, CommandLine: `node "${other}"` },
    { ProcessId: 22, CommandLine: `node --env-file=.env "${entry}"` },
    { ProcessId: 33, CommandLine: `node "${entry}"` },
  ], [11, 22]);
  assert.deepEqual(result.stopped, [22]);
  assert.equal(result.port, 3116);
});

test('an unrelated Node entry on the API port is left for the occupied-port guard', () => {
  assert.deepEqual(shutdown([{ ProcessId: 11, CommandLine: `node "${other}"` }], [11]).stopped, []);
});

test('a checkout process on another port is never stopped', () => {
  assert.deepEqual(shutdown([{ ProcessId: 22, CommandLine: `node "${entry}"` }], []).stopped, []);
});

test('an entry name sharing the prefix is not ownership of the API', () => {
  assert.deepEqual(shutdown([{ ProcessId: 22, CommandLine: `node "${entry}.backup"` }], [22]).stopped, []);
});
