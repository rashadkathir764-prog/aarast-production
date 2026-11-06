// Windows PowerShell 5.1 reads a .ps1 without a BOM as ANSI, so Arabic text
// inside a deploy script breaks its parser (go-live, 2026-11-06). Every
// deploy script therefore starts with the UTF-8 BOM.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path, out);
    else if (name.endsWith('.ps1')) out.push(path);
  }
  return out;
}

test('every deploy PowerShell script starts with the UTF-8 BOM', () => {
  const missing = walk('deploy').filter((path) => {
    const head = readFileSync(path).subarray(0, 3);
    return !(head[0] === 0xef && head[1] === 0xbb && head[2] === 0xbf);
  });
  assert.deepEqual(missing, []);
});
