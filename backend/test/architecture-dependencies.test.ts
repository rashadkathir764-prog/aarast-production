import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const backendRoot = path.resolve(__dirname, '..');
const configPath = path.join(backendRoot, '.dependency-cruiser.cjs');
const cliPath = path.join(
  backendRoot,
  'node_modules',
  '.bin',
  process.platform === 'win32' ? 'depcruise.cmd' : 'depcruise',
);
const temporaryRoots: string[] = [];

function write(root: string, relativePath: string, content: string) {
  const target = path.join(root, relativePath);
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

function fixtureRoot() {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-depcruise-'));
  temporaryRoots.push(root);
  write(root, 'tsconfig.json', JSON.stringify({
    compilerOptions: { module: 'commonjs', target: 'ES2022' },
    include: ['src/**/*.ts'],
  }));
  return root;
}

function cruise(root: string, args: string[]) {
  return spawnSync(cliPath, args, {
    cwd: root,
    encoding: 'utf8',
    shell: process.platform === 'win32',
  });
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('known edge is ignored and a new cross-context edge fails', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/auth/known.ts', "import '../guests/public';\n");
  write(root, 'src/guests/public.ts', 'export const guest = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  const known = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.equal(known.status, 0, known.stderr || known.stdout);
  write(root, 'src/tasks/new.ts', "import '../guests/public';\n");
  const added = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(added.status, 0);
  assert.match(`${added.stdout}\n${added.stderr}`, /context-tasks-cross-context/);
});

test('a new cycle fails even when the known baseline is enabled', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/planning/seed.ts', 'export const seed = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  write(root, 'src/planning/a.ts', "import '../finance/b';\n");
  write(root, 'src/finance/b.ts', "import '../planning/a';\n");
  const added = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(added.status, 0);
  assert.match(`${added.stdout}\n${added.stderr}`, /no-circular/);
});

test('legacy code may consume only a future context public slice', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/modules/guests/public/index.ts', 'export const guestsPort = true;\n');
  write(root, 'src/tasks/allowed.ts', "import '../modules/guests/public/index';\n");
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('mixed legacy/future internal edges and platform-to-future edges fail', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/planning/seed.ts', 'export const seed = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  write(root, 'src/guests/legacy.ts', 'export const legacyGuest = true;\n');
  write(root, 'src/modules/guests/internal/secret.ts', 'export const secret = true;\n');
  write(root, 'src/modules/tasks/public/index.ts', 'export const taskPort = true;\n');
  write(root, 'src/modules/tasks/application/use.ts', "import '../../../guests/legacy';\n");
  write(root, 'src/tasks/bad.ts', "import '../modules/guests/internal/secret';\n");
  write(root, 'src/common/platform.ts', "import '../modules/tasks/public/index';\n");
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(result.status, 0);
  const output = `${result.stdout}\n${result.stderr}`;
  assert.match(output, /context-tasks-cross-context/);
  assert.match(output, /current-platform-no-business-contexts/);
});

test('mixed R1 platform roots enforce their phase-specific rules', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/planning/seed.ts', 'export const seed = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  write(root, 'src/auth/legacy.ts', 'export const legacy = true;\n');
  write(root, 'src/common/legacy-platform.ts', "import '../auth/legacy';\n");
  write(root, 'src/platform/final-platform.ts', "import '../auth/legacy';\n");
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(result.status, 0);
  const output = `${result.stdout}\n${result.stderr}`;
  assert.match(output, /current-platform-no-business-contexts/);
  assert.match(output, /platform-no-business-contexts/);
});

test('shared kernel cannot import a legacy business context', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/shared-kernel/seed.ts', 'export const seed = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  write(root, 'src/auth/legacy.ts', 'export const legacyAuth = true;\n');
  write(root, 'src/shared-kernel/bad.ts', "import '../auth/legacy';\n");
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(result.status, 0);
  assert.match(`${result.stdout}\n${result.stderr}`, /shared-kernel-is-foundational/);
});
