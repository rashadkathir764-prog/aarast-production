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

test('mixed legacy/future internal edges and canonical platform-to-future edges fail', () => {
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
  write(root, 'src/platform/platform.ts', "import '../modules/tasks/public/index';\n");
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(result.status, 0);
  const output = `${result.stdout}\n${result.stderr}`;
  assert.match(output, /context-tasks-cross-context/);
  assert.match(output, /platform-no-business-contexts/);
});

test('final R1 platform root enforces the phase-neutral platform rule', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/planning/seed.ts', 'export const seed = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  write(root, 'src/auth/legacy.ts', 'export const legacy = true;\n');
  write(root, 'src/platform/final-platform.ts', "import '../auth/legacy';\n");
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(result.status, 0);
  const output = `${result.stdout}\n${result.stderr}`;
  assert.match(output, /platform-no-business-contexts/);
  assert.doesNotMatch(output, /current-platform-no-business-contexts/);
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

test('only legacy auth/catalogs and relocated SafeUser may import the exact Backoffice permission contract', () => {
  const allowedRoot = fixtureRoot();
  write(
    allowedRoot,
    'src/modules/backoffice/domain/admin-permissions.ts',
    'export const permission = true;\n',
  );
  write(
    allowedRoot,
    'src/auth/use-permission.ts',
    "import '../modules/backoffice/domain/admin-permissions';\n",
  );
  write(
    allowedRoot,
    'src/catalogs/use-permission.ts',
    "import '../modules/backoffice/domain/admin-permissions';\n",
  );
  write(
    allowedRoot,
    'src/modules/identity/public/safe-user.ts',
    "import '../../backoffice/domain/admin-permissions';\n",
  );
  const allowed = cruise(allowedRoot, ['--config', configPath, 'src']);
  assert.equal(allowed.status, 0, allowed.stderr || allowed.stdout);

  const siblingRoot = fixtureRoot();
  write(siblingRoot, 'src/modules/backoffice/domain/private.ts', 'export const value = true;\n');
  write(
    siblingRoot,
    'src/auth/use-private.ts',
    "import '../modules/backoffice/domain/private';\n",
  );
  const sibling = cruise(siblingRoot, ['--config', configPath, 'src']);
  assert.notEqual(sibling.status, 0);
  assert.match(`${sibling.stdout}\n${sibling.stderr}`, /context-identity-cross-context/);

  const unauthorizedRoot = fixtureRoot();
  write(
    unauthorizedRoot,
    'src/modules/backoffice/domain/admin-permissions.ts',
    'export const permission = true;\n',
  );
  write(
    unauthorizedRoot,
    'src/tasks/use-permission.ts',
    "import '../modules/backoffice/domain/admin-permissions';\n",
  );
  const unauthorized = cruise(unauthorizedRoot, ['--config', configPath, 'src']);
  assert.notEqual(unauthorized.status, 0);
  assert.match(`${unauthorized.stdout}\n${unauthorized.stderr}`, /context-tasks-cross-context/);

  const futureCatalogRoot = fixtureRoot();
  write(
    futureCatalogRoot,
    'src/modules/backoffice/domain/admin-permissions.ts',
    'export const permission = true;\n',
  );
  write(
    futureCatalogRoot,
    'src/modules/catalog/application/use-permission.ts',
    "import '../../backoffice/domain/admin-permissions';\n",
  );
  const futureCatalog = cruise(futureCatalogRoot, ['--config', configPath, 'src']);
  assert.notEqual(futureCatalog.status, 0);
  assert.match(`${futureCatalog.stdout}\n${futureCatalog.stderr}`, /context-catalog-cross-context/);

  const futureIdentitySiblingRoot = fixtureRoot();
  write(
    futureIdentitySiblingRoot,
    'src/modules/backoffice/domain/admin-permissions.ts',
    'export const permission = true;\n',
  );
  write(
    futureIdentitySiblingRoot,
    'src/modules/identity/public/not-safe-user.ts',
    "import '../../backoffice/domain/admin-permissions';\n",
  );
  const futureIdentitySibling = cruise(
    futureIdentitySiblingRoot,
    ['--config', configPath, 'src'],
  );
  assert.notEqual(futureIdentitySibling.status, 0);
  assert.match(
    `${futureIdentitySibling.stdout}\n${futureIdentitySibling.stderr}`,
    /context-identity-cross-context/,
  );
});

test('R5 relocated Identity internals retain only their two exact pure helper dependencies', () => {
  const allowedRoot = fixtureRoot();
  write(
    allowedRoot,
    'src/modules/identity/internal/profile/contexts.service.ts',
    "import '../../../../provider-dashboard/provider-access-policy';\n",
  );
  write(
    allowedRoot,
    'src/provider-dashboard/provider-access-policy.ts',
    'export const providerAccessPolicy = true;\n',
  );
  write(
    allowedRoot,
    'src/modules/identity/internal/profile/users.service.ts',
    "import '../../../../marketplace/provider-review-rating';\n",
  );
  write(
    allowedRoot,
    'src/marketplace/provider-review-rating.ts',
    'export const refreshProviderRating = true;\n',
  );
  const allowed = cruise(allowedRoot, ['--config', configPath, 'src']);
  assert.equal(allowed.status, 0, allowed.stderr || allowed.stdout);

  const siblingSourceRoot = fixtureRoot();
  write(
    siblingSourceRoot,
    'src/modules/identity/internal/profile/not-contexts.service.ts',
    "import '../../../../provider-dashboard/provider-access-policy';\n",
  );
  write(
    siblingSourceRoot,
    'src/provider-dashboard/provider-access-policy.ts',
    'export const providerAccessPolicy = true;\n',
  );
  const siblingSource = cruise(siblingSourceRoot, ['--config', configPath, 'src']);
  assert.notEqual(siblingSource.status, 0);
  assert.match(`${siblingSource.stdout}\n${siblingSource.stderr}`, /context-identity-cross-context/);

  const siblingTargetRoot = fixtureRoot();
  write(
    siblingTargetRoot,
    'src/modules/identity/internal/profile/contexts.service.ts',
    "import '../../../../provider-dashboard/private';\n",
  );
  write(siblingTargetRoot, 'src/provider-dashboard/private.ts', 'export const value = true;\n');
  const siblingTarget = cruise(siblingTargetRoot, ['--config', configPath, 'src']);
  assert.notEqual(siblingTarget.status, 0);
  assert.match(
    `${siblingTarget.stdout}\n${siblingTarget.stderr}`,
    /context-identity-(?:relocated-contexts-helper-)?cross-context/,
  );
});

test('application composition may import platform and business public slices only', () => {
  const allowedRoot = fixtureRoot();
  write(allowedRoot, 'src/platform/outbox/core.ts', 'export const core = true;\n');
  write(allowedRoot, 'src/modules/tasks/public/tasks-public.module.ts', 'export class TasksPublicModule {}\n');
  write(allowedRoot, 'src/application-composition/runtime.ts', [
    "import '../platform/outbox/core';",
    "import '../modules/tasks/public/tasks-public.module';",
  ].join('\n'));
  const allowed = cruise(allowedRoot, ['--config', configPath, 'src']);
  assert.equal(allowed.status, 0, allowed.stderr || allowed.stdout);

  const rejectedRoot = fixtureRoot();
  write(rejectedRoot, 'src/tasks/private.ts', 'export const value = true;\n');
  write(rejectedRoot, 'src/modules/tasks/internal/private.ts', 'export const internal = true;\n');
  write(rejectedRoot, 'src/application-composition/runtime.ts', [
    "import '../tasks/private';",
    "import '../modules/tasks/internal/private';",
  ].join('\n'));
  write(rejectedRoot, 'src/platform/bad.ts', "import '../application-composition/runtime';\n");
  write(rejectedRoot, 'src/guests/bad.ts', "import '../application-composition/runtime';\n");
  const rejected = cruise(rejectedRoot, ['--config', configPath, 'src']);
  assert.notEqual(rejected.status, 0);
  const output = `${rejected.stdout}\n${rejected.stderr}`;
  assert.match(output, /application-composition-public-only/);
  assert.match(output, /application-composition-is-root-only/);
});

test('cross-owner public slices accept type-only imports and reject runtime imports', () => {
  const root = fixtureRoot();
  write(root, 'src/modules/guests/public/types.ts', 'export interface GuestView { id: string }\n');
  write(root, 'src/modules/tasks/public/legal.ts', [
    "import type { GuestView } from '../../guests/public/types';",
    'export interface TaskView { guest: GuestView }',
  ].join('\n'));
  const legal = cruise(root, ['--config', configPath, 'src']);
  assert.equal(legal.status, 0, legal.stderr || legal.stdout);
  write(root, 'src/modules/tasks/public/runtime.ts', [
    "import { value } from '../../guests/public/value';",
    'void value;',
  ].join('\n'));
  write(root, 'src/modules/guests/public/value.ts', 'export const value = true;\n');
  const runtime = cruise(root, ['--config', configPath, 'src']);
  assert.notEqual(runtime.status, 0);
  assert.match(`${runtime.stdout}\n${runtime.stderr}`, /public-cross-owner-type-only/);
});
