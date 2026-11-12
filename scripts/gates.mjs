#!/usr/bin/env node
// Every gate in docs/qa/README.md, in one command, on Windows or Linux.
//
// The gate before a commit (--quick) and before a merge or a release
// (--full): what CI runs on GitHub, here first, and the golden images and
// walks that only Windows draws. It never hides a
// result: each gate is PASS, FAIL or SKIP (a tool this machine lacks, with
// the reason), the table is printed at the end, and the exit code is 1 when
// any gate failed (or, with --strict, was skipped).
//
//   node scripts/gates.mjs --quick                 static checks and unit tests
//   node scripts/gates.mjs --full                  everything, Docker included
//   node scripts/gates.mjs --quick --only mobile   one or more areas
//   node scripts/gates.mjs --full --strict         a skip counts as a failure
//
// Areas: backend, admin, mobile, root. Each command is the README's own.

import { spawnSync } from 'node:child_process';
import { existsSync, realpathSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// The folder as the disk spells it. A terminal opened on `d:\…` (an editor's
// lower-case drive letter) gave every gate that path, and four of them
// compare paths letter for letter: the Prisma config check, the governance
// tests, the smokes and the admin tests failed there and passed on `D:\…`,
// on the same code (found 2026-11-12).
const root = realpathSync.native(join(dirname(fileURLToPath(import.meta.url)), '..'));
const isWindows = process.platform === 'win32';
const args = process.argv.slice(2);
const full = args.includes('--full');
const strict = args.includes('--strict');
const onlyIndex = args.indexOf('--only');
const only = onlyIndex >= 0 ? new Set((args[onlyIndex + 1] ?? '').split(',').filter(Boolean)) : null;

if (!full && !args.includes('--quick')) {
  console.error('Usage: node scripts/gates.mjs --quick|--full [--only backend,admin,mobile,root] [--strict]');
  process.exit(2);
}

function has(command, probe = ['--version']) {
  const result = spawnSync(command, probe, { stdio: 'ignore', shell: isWindows });
  return result.status === 0;
}

function trackedFiles(...patterns) {
  const result = spawnSync('git', ['ls-files', '--', ...patterns], { cwd: root, encoding: 'utf8' });
  return result.status === 0 ? result.stdout.split('\n').filter(Boolean) : [];
}

const tools = {
  docker: () => has('docker', ['info']) || 'Docker is not running',
  flutter: () => has('flutter') || 'Flutter is not on PATH',
  java: () => has('java', ['-version']) || 'Java is not on PATH',
  gitleaks: () => has('gitleaks', ['version']) || 'gitleaks is not installed',
};

// Golden images are drawn on Windows (docs/qa/README.md); elsewhere they are
// skipped by tag and the skip is said.
const flutterTest = isWindows
  ? ['test', '--no-pub']
  : ['test', '--no-pub', '--exclude-tags', 'golden'];

const gates = [
  // Backend
  { area: 'backend', name: 'backend check', cwd: 'backend', cmd: 'npm', args: ['run', 'check'] },
  { area: 'backend', name: 'backend architecture', cwd: 'backend', cmd: 'npm', args: ['run', 'architecture'] },
  { area: 'backend', name: 'backend prisma config security', cwd: 'backend', cmd: 'npm', args: ['run', 'security:prisma-config-merge'] },
  // RA-TS-07: unit tests are the commit gate (the header's «static checks and
  // unit tests»). Full-only, three pinned tests went out failing.
  { area: 'backend', name: 'backend tests', cwd: 'backend', cmd: 'npm', args: ['test'] },
  { area: 'backend', name: 'backend smoke:all', cwd: 'backend', cmd: 'npm', args: ['run', 'smoke:all'], full: true, needs: ['docker'] },
  { area: 'backend', name: 'backend npm audit', cwd: 'backend', cmd: 'npm', args: ['audit', '--audit-level=high'], full: true },

  // Repository root
  { area: 'root', name: 'docs-sync', cwd: '.', cmd: 'node', args: ['scripts/docs-sync.mjs', '--check'] },
  { area: 'root', name: 'docs-verify', cwd: '.', cmd: 'node', args: ['scripts/docs-verify.mjs'] },
  { area: 'root', name: 'mobile boundaries (tests)', cwd: '.', cmd: 'node', args: ['--test', 'scripts/check-mobile-boundaries.test.mjs'] },
  { area: 'root', name: 'mobile boundaries (strict)', cwd: '.', cmd: 'node', args: ['scripts/check-mobile-boundaries.mjs', '--strict'] },
  {
    area: 'root',
    name: 'deploy and supply-chain contracts',
    cwd: '.',
    cmd: 'node',
    args: () => ['--test', ...trackedFiles('deploy/**/*.test.mjs'), 'scripts/check-deploy-encoding.test.mjs', 'scripts/supply-chain-contract.test.mjs'],
    // deploy/aws/direct-ip-contract.test.mjs renders its Caddy file in a
    // container. With Docker stopped the gate failed on a pipe error that
    // read like a broken contract (2026-11-12); it is said as a missing tool.
    needs: ['docker'],
  },
  { area: 'root', name: 'admin staging build origin', cwd: '.', cmd: 'node', args: ['--test', 'admin-web/scripts/staging-build-origin.contract.mjs'] },
  { area: 'root', name: 'android release config (Gradle)', cwd: '.', cmd: 'node', args: ['scripts/test-android-release-config.mjs'], full: true, needs: ['java'] },
  { area: 'root', name: 'compose config', cwd: '.', cmd: 'docker', args: ['compose', 'config', '--quiet'], full: true, needs: ['docker'] },
  { area: 'root', name: 'secrets scan (gitleaks)', cwd: '.', cmd: 'gitleaks', args: ['detect', '--redact', '--no-banner'], full: true, needs: ['gitleaks'] },
  { area: 'root', name: 'whitespace (git diff --check)', cwd: '.', cmd: 'git', args: ['diff', '--check', 'HEAD'] },

  // Admin web
  { area: 'admin', name: 'admin test:architecture', cwd: 'admin-web', cmd: 'npm', args: ['run', 'test:architecture'] },
  { area: 'admin', name: 'admin architecture', cwd: 'admin-web', cmd: 'npm', args: ['run', 'architecture'] },
  { area: 'admin', name: 'admin tests', cwd: 'admin-web', cmd: 'npm', args: ['test', '--', '--run'] },
  { area: 'admin', name: 'admin typecheck', cwd: 'admin-web', cmd: 'npm', args: ['run', 'typecheck'] },
  { area: 'admin', name: 'admin build', cwd: 'admin-web', cmd: 'npm', args: ['run', 'build'] },
  { area: 'admin', name: 'admin smoke:honesty', cwd: 'admin-web', cmd: 'npm', args: ['run', 'smoke:honesty'] },
  { area: 'admin', name: 'admin smoke:routes', cwd: 'admin-web', cmd: 'npm', args: ['run', 'smoke:routes'] },
  { area: 'admin', name: 'admin container config', cwd: 'admin-web', cmd: 'npm', args: ['run', 'test:container-config'] },
  { area: 'admin', name: 'admin smoke:admin-runtime', cwd: 'admin-web', cmd: 'npm', args: ['run', 'smoke:admin-runtime'], full: true, needs: ['docker'] },
  { area: 'admin', name: 'admin npm audit', cwd: 'admin-web', cmd: 'npm', args: ['audit', '--audit-level=high'], full: true },

  // Mobile
  { area: 'mobile', name: 'flutter analyze', cwd: 'mobile', cmd: 'flutter', args: ['analyze', '--no-pub'], needs: ['flutter'] },
  {
    area: 'mobile',
    name: isWindows ? 'flutter test' : 'flutter test (golden images skipped: drawn on Windows)',
    cwd: 'mobile',
    cmd: 'flutter',
    args: flutterTest,
    needs: ['flutter'],
  },
];

const results = [];
for (const gate of gates) {
  if (gate.full && !full) continue;
  if (only && !only.has(gate.area)) continue;
  const missing = (gate.needs ?? []).map((tool) => tools[tool]()).find((ok) => ok !== true);
  if (missing) {
    results.push({ gate, status: 'SKIP', detail: missing });
    console.log(`\n=== SKIP  ${gate.name}: ${missing}`);
    continue;
  }
  const cwd = join(root, gate.cwd);
  if (!existsSync(cwd)) {
    results.push({ gate, status: 'FAIL', detail: `missing directory ${gate.cwd}` });
    continue;
  }
  const gateArgs = typeof gate.args === 'function' ? gate.args() : gate.args;
  console.log(`\n=== RUN   ${gate.name}  (${gate.cwd}: ${gate.cmd} ${gateArgs.join(' ')})`);
  const started = Date.now();
  const run = spawnSync(gate.cmd, gateArgs, { cwd, stdio: 'inherit', shell: isWindows });
  const seconds = Math.round((Date.now() - started) / 1000);
  const status = run.status === 0 ? 'PASS' : 'FAIL';
  const detail = run.error ? run.error.message : `exit ${run.status ?? run.signal}, ${seconds}s`;
  results.push({ gate, status, detail });
  console.log(`=== ${status}  ${gate.name} (${detail})`);
}

console.log(`\nGates (${full ? 'full' : 'quick'}, ${process.platform}):`);
for (const { gate, status, detail } of results) {
  console.log(`  ${status.padEnd(4)}  ${gate.area.padEnd(7)}  ${gate.name}  [${detail}]`);
}
const failed = results.filter((result) => result.status === 'FAIL').length;
const skipped = results.filter((result) => result.status === 'SKIP').length;
console.log(`\n${results.length - failed - skipped} passed, ${failed} failed, ${skipped} skipped.`);
process.exit(failed > 0 || (strict && skipped > 0) ? 1 : 0);
