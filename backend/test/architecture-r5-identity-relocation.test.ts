import assert from 'node:assert/strict';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  renameSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { afterEach, test } from 'node:test';

const backendRoot = path.resolve(__dirname, '..');
const manifestPath = path.join(
  backendRoot,
  'architecture',
  'r5-identity-relocation.json',
);
const scannerPath = path.join(
  backendRoot,
  'scripts',
  'architecture',
  'r5-identity-scan.cjs',
);
const r5Base = '9dab73acdc187a4a18d8a675713d8ded40a16d02';

const expectedMoves = [
  ['backend/src/auth/access-token-scope.ts', 'backend/src/modules/identity/public/access-token-scope.ts'],
  ['backend/src/auth/auth-challenge-cleanup.scheduler.ts', 'backend/src/modules/identity/internal/auth/auth-challenge-cleanup.scheduler.ts'],
  ['backend/src/auth/auth-error.ts', 'backend/src/modules/identity/public/auth-error.ts'],
  ['backend/src/auth/auth.controller.ts', 'backend/src/modules/identity/api/auth.controller.ts'],
  ['backend/src/auth/auth.service.ts', 'backend/src/modules/identity/internal/auth/auth.service.ts'],
  ['backend/src/auth/current-user.decorator.ts', 'backend/src/modules/identity/public/current-user.decorator.ts'],
  ['backend/src/auth/dto/admin-password-reset-confirm.dto.ts', 'backend/src/modules/identity/api/auth-dto/admin-password-reset-confirm.dto.ts'],
  ['backend/src/auth/dto/admin-password-reset-request.dto.ts', 'backend/src/modules/identity/api/auth-dto/admin-password-reset-request.dto.ts'],
  ['backend/src/auth/dto/complete-admin-login.dto.ts', 'backend/src/modules/identity/api/auth-dto/complete-admin-login.dto.ts'],
  ['backend/src/auth/dto/complete-registration.dto.ts', 'backend/src/modules/identity/api/auth-dto/complete-registration.dto.ts'],
  ['backend/src/auth/dto/login.dto.ts', 'backend/src/modules/identity/api/auth-dto/login.dto.ts'],
  ['backend/src/auth/dto/logout.dto.ts', 'backend/src/modules/identity/api/auth-dto/logout.dto.ts'],
  ['backend/src/auth/dto/max-utf8-bytes.decorator.ts', 'backend/src/modules/identity/public/max-utf8-bytes.decorator.ts'],
  ['backend/src/auth/dto/password-reset-confirm.dto.ts', 'backend/src/modules/identity/api/auth-dto/password-reset-confirm.dto.ts'],
  ['backend/src/auth/dto/password-reset-request.dto.ts', 'backend/src/modules/identity/api/auth-dto/password-reset-request.dto.ts'],
  ['backend/src/auth/dto/refresh.dto.ts', 'backend/src/modules/identity/api/auth-dto/refresh.dto.ts'],
  ['backend/src/auth/dto/register.dto.ts', 'backend/src/modules/identity/api/auth-dto/register.dto.ts'],
  ['backend/src/auth/dto/request-otp.dto.ts', 'backend/src/modules/identity/api/auth-dto/request-otp.dto.ts'],
  ['backend/src/auth/dto/verify-otp.dto.ts', 'backend/src/modules/identity/api/auth-dto/verify-otp.dto.ts'],
  ['backend/src/auth/jwt-auth.guard.ts', 'backend/src/modules/identity/public/jwt-auth.guard.ts'],
  ['backend/src/auth/jwt-payload.interface.ts', 'backend/src/modules/identity/public/jwt-payload.interface.ts'],
  ['backend/src/auth/jwt-secret.ts', 'backend/src/modules/identity/internal/auth/jwt-secret.ts'],
  ['backend/src/auth/jwt-session.guard.ts', 'backend/src/modules/identity/public/jwt-session.guard.ts'],
  ['backend/src/auth/jwt.strategy.ts', 'backend/src/modules/identity/internal/auth/jwt.strategy.ts'],
  ['backend/src/auth/login-throttle-cleanup.scheduler.ts', 'backend/src/modules/identity/internal/auth/login-throttle-cleanup.scheduler.ts'],
  ['backend/src/auth/login-throttle.service.ts', 'backend/src/modules/identity/internal/auth/login-throttle.service.ts'],
  ['backend/src/auth/otp-channel.ts', 'backend/src/modules/identity/internal/auth/otp-channel.ts'],
  ['backend/src/auth/otp-dispatch-quota-cleanup.scheduler.ts', 'backend/src/modules/identity/internal/auth/otp-dispatch-quota-cleanup.scheduler.ts'],
  ['backend/src/auth/otp-dispatch-quota.service.ts', 'backend/src/modules/identity/internal/auth/otp-dispatch-quota.service.ts'],
  ['backend/src/auth/refresh-token-policy.ts', 'backend/src/modules/identity/internal/auth/refresh-token-policy.ts'],
  ['backend/src/auth/safe-user.ts', 'backend/src/modules/identity/public/safe-user.ts'],
  ['backend/src/contexts/context-key.ts', 'backend/src/modules/identity/public/context-key.ts'],
  ['backend/src/contexts/contexts.controller.ts', 'backend/src/modules/identity/api/contexts.controller.ts'],
  ['backend/src/contexts/contexts.service.ts', 'backend/src/modules/identity/internal/profile/contexts.service.ts'],
  ['backend/src/contexts/dto/validate-context.dto.ts', 'backend/src/modules/identity/api/context-dto/validate-context.dto.ts'],
  ['backend/src/me/me.controller.ts', 'backend/src/modules/identity/api/me.controller.ts'],
  ['backend/src/users/account-deletion-status.controller.ts', 'backend/src/modules/identity/api/account-deletion-status.controller.ts'],
  ['backend/src/users/dto/account-deletion-status.dto.ts', 'backend/src/modules/identity/api/user-dto/account-deletion-status.dto.ts'],
  ['backend/src/users/dto/update-profile.dto.ts', 'backend/src/modules/identity/api/user-dto/update-profile.dto.ts'],
  ['backend/src/users/dto/update-settings.dto.ts', 'backend/src/modules/identity/api/user-dto/update-settings.dto.ts'],
  ['backend/src/users/dto/user-lookup.dto.ts', 'backend/src/modules/identity/api/user-dto/user-lookup.dto.ts'],
  ['backend/src/users/user-lifecycle-lock.ts', 'backend/src/modules/identity/public/user-lifecycle-lock.ts'],
  ['backend/src/users/users.controller.ts', 'backend/src/modules/identity/api/users.controller.ts'],
  ['backend/src/users/users.service.ts', 'backend/src/modules/identity/internal/profile/users.service.ts'],
].map(([from, to]) => ({ from, to }));

const expectedPublicRuntimeContracts = [
  {
    source: 'backend/src/auth/access-token-scope.ts',
    target: 'backend/src/modules/identity/public/access-token-scope.ts',
    declarations: ['function:resolveJwtSessionScope'],
  },
  {
    source: 'backend/src/auth/auth-error.ts',
    target: 'backend/src/modules/identity/public/auth-error.ts',
    declarations: [
      'const:AuthErrorCode',
      'const:OTP_DELIVERY_UNAVAILABLE_MESSAGE',
      'function:authError',
      'function:otpDeliveryUnavailableError',
      'type:AuthErrorCode',
    ],
  },
  {
    source: 'backend/src/auth/current-user.decorator.ts',
    target: 'backend/src/modules/identity/public/current-user.decorator.ts',
    declarations: ['const:CurrentUser'],
  },
  {
    source: 'backend/src/auth/dto/max-utf8-bytes.decorator.ts',
    target: 'backend/src/modules/identity/public/max-utf8-bytes.decorator.ts',
    declarations: ['function:MaxUtf8Bytes'],
  },
  {
    source: 'backend/src/auth/jwt-auth.guard.ts',
    target: 'backend/src/modules/identity/public/jwt-auth.guard.ts',
    declarations: ['class:JwtAuthGuard'],
  },
  {
    source: 'backend/src/auth/jwt-payload.interface.ts',
    target: 'backend/src/modules/identity/public/jwt-payload.interface.ts',
    declarations: ['interface:JwtPayload'],
  },
  {
    source: 'backend/src/auth/jwt-session.guard.ts',
    target: 'backend/src/modules/identity/public/jwt-session.guard.ts',
    declarations: ['class:JwtSessionGuard'],
  },
  {
    source: 'backend/src/auth/safe-user.ts',
    target: 'backend/src/modules/identity/public/safe-user.ts',
    declarations: [
      'function:toAuthenticatedUser',
      'function:toSafeUser',
      'interface:SafeUser',
    ],
  },
  {
    source: 'backend/src/contexts/context-key.ts',
    target: 'backend/src/modules/identity/public/context-key.ts',
    declarations: [
      'function:canonicalPlanContextKey',
      'function:canonicalProviderContextKey',
      'type:PlanContextKeyRole',
    ],
  },
  {
    source: 'backend/src/users/user-lifecycle-lock.ts',
    target: 'backend/src/modules/identity/public/user-lifecycle-lock.ts',
    declarations: [
      'function:assertActiveMutationActorForUpdateInTransaction',
      'function:assertActiveMutationActorInTransaction',
      'function:lockUserLifecycleRowsForUpdateInTransaction',
      'function:lockUserLifecycleRowsInTransaction',
      'interface:LockedUserLifecycleRow',
    ],
  },
];

type Move = { from: string; to: string };
type R5Manifest = {
  schemaVersion: number;
  baseRevision: string;
  stage: string;
  moves: Move[];
  publicRuntimeContracts: Array<{
    source: string;
    target: string;
    declarations: string[];
  }>;
  retiredRoots: string[];
  expectedBaselines: {
    dependencyRecords: number;
    ownershipRecords: number;
    ownershipOccurrences: number;
  };
  allowedChangedPaths: string[];
};

type R5Scanner = {
  validateR5Manifest(value: unknown): R5Manifest;
  scanR5Identity(options: {
    repositoryRoot: string;
    manifest: unknown;
  }): { ok: boolean };
  validateR5AuthStage(repositoryRoot: string): void;
  mapOwnershipRecordsForR5(records: Array<Record<string, unknown>>, manifest: R5Manifest):
    Array<Record<string, unknown>>;
};

test('R5 scope includes the exact dependency boundary config required by Task 2', () => {
  const manifest = loadScanner().validateR5Manifest(readManifest());
  assert.equal(manifest.allowedChangedPaths.includes('backend/.dependency-cruiser.cjs'), true);
  assert.equal(
    manifest.allowedChangedPaths.includes('backend/scripts/architecture/ownership-scan.cjs'),
    true,
  );
});

test('R5 maps ownership paths at the active stage without changing semantics', () => {
  const r5 = loadScanner();
  const manifest = r5.validateR5Manifest(readManifest());
  const original = {
    key: 'backend/src/auth/auth.service.ts|identity|collaboration|PlanInvite|findFirst|read|delegate|foreign-model',
    file: 'backend/src/auth/auth.service.ts',
    context: 'identity',
    owner: 'collaboration',
    model: 'PlanInvite',
    operation: 'findFirst',
    mode: 'read',
    source: 'delegate',
    reason: 'foreign-model',
    count: 3,
  };
  const [mapped] = r5.mapOwnershipRecordsForR5([original], manifest);
  assert.equal(mapped.file, 'backend/src/modules/identity/internal/auth/auth.service.ts');
  assert.equal(
    mapped.key,
    'backend/src/modules/identity/internal/auth/auth.service.ts|identity|collaboration|PlanInvite|findFirst|read|delegate|foreign-model',
  );
  assert.deepEqual(
    { ...mapped, file: original.file, key: original.key },
    original,
  );
});

const temporaryRoots: string[] = [];

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

function loadScanner(): R5Scanner {
  assert.equal(existsSync(scannerPath), true, 'R5 scanner must exist');
  return require(scannerPath) as R5Scanner;
}

function readManifest(): R5Manifest {
  assert.equal(existsSync(manifestPath), true, 'R5 manifest must exist');
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as R5Manifest;
}

function cloneManifest(): R5Manifest {
  return structuredClone(readManifest());
}

function writePlainFile(root: string, relativePath: string) {
  const target = path.join(root, ...relativePath.split('/'));
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, 'export {}\n', 'utf8');
}

function contractSource(declarations: readonly string[]): string {
  return `${declarations.map((declaration) => {
    const [kind, name] = declaration.split(':');
    if (kind === 'class') return `export class ${name} {}`;
    if (kind === 'const') return `export const ${name} = {};`;
    if (kind === 'function') return `export function ${name}(..._args: unknown[]): unknown { return undefined; }`;
    if (kind === 'interface') return `export interface ${name} {}`;
    return `export type ${name} = unknown;`;
  }).join('\n')}\n`;
}

test('R5 manifest pins the exact 44 one-to-one moves', () => {
  const manifest = readManifest();

  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.baseRevision, r5Base);
  assert.equal(manifest.stage, 'task-3');
  assert.deepEqual(manifest.moves, expectedMoves);
  assert.equal(manifest.moves.length, 44);
  assert.equal(new Set(manifest.moves.map((move) => move.from)).size, 44);
  assert.equal(new Set(manifest.moves.map((move) => move.to)).size, 44);
  assert.deepEqual(manifest.retiredRoots, ['auth', 'contexts', 'me', 'users']);
  assert.deepEqual(manifest.expectedBaselines, {
    dependencyRecords: 89,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  });
  assert.deepEqual(manifest.publicRuntimeContracts, expectedPublicRuntimeContracts);
});

test('R5 manifest rejects move and public-surface drift before filesystem access', () => {
  const { validateR5Manifest } = loadScanner();
  const mutations: R5Manifest[] = [];

  const duplicateTarget = cloneManifest();
  duplicateTarget.moves[1].to = duplicateTarget.moves[0].to;
  mutations.push(duplicateTarget);

  const prefixOverlap = cloneManifest();
  prefixOverlap.moves[1].from = `${prefixOverlap.moves[0].from}/nested.ts`;
  mutations.push(prefixOverlap);

  const missingMove = cloneManifest();
  missingMove.moves.pop();
  mutations.push(missingMove);

  const substitutedMove = cloneManifest();
  substitutedMove.moves[0].from = 'backend/src/auth/substituted.ts';
  mutations.push(substitutedMove);

  const absolutePath = cloneManifest();
  absolutePath.moves[0].to = path.resolve('outside.ts');
  mutations.push(absolutePath);

  const traversal = cloneManifest();
  traversal.moves[0].to = 'backend/src/modules/identity/public/../outside.ts';
  mutations.push(traversal);

  const addedPublicContract = cloneManifest();
  addedPublicContract.publicRuntimeContracts.push({
    source: 'backend/src/auth/auth.service.ts',
    target: 'backend/src/modules/identity/public/auth.service.ts',
    declarations: ['class:AuthService'],
  });
  mutations.push(addedPublicContract);

  for (const mutation of mutations) {
    assert.throws(
      () => validateR5Manifest(mutation),
      /R5 identity manifest|move|path|public runtime/i,
    );
  }
});

test('R5 inventory rejects a junction-backed legacy source root', () => {
  const scanner = loadScanner();
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r5-inventory-'));
  temporaryRoots.push(fixtureRoot);
  const manifest = readManifest();
  manifest.stage = 'inventory';
  for (const move of manifest.moves) writePlainFile(fixtureRoot, move.from);

  const authRoot = path.join(fixtureRoot, 'backend', 'src', 'auth');
  const externalAuthRoot = path.join(fixtureRoot, 'external-auth');
  renameSync(authRoot, externalAuthRoot);
  symlinkSync(externalAuthRoot, authRoot, 'junction');

  assert.throws(
    () => scanner.scanR5Identity({ repositoryRoot: fixtureRoot, manifest }),
    /reparse|symbolic|junction/i,
  );
});

test('R5 inventory rejects drifted or hollow public runtime contracts', () => {
  const scanner = loadScanner();
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r5-public-'));
  temporaryRoots.push(fixtureRoot);
  const manifest = readManifest();
  manifest.stage = 'inventory';
  for (const move of manifest.moves) writePlainFile(fixtureRoot, move.from);

  assert.throws(
    () => scanner.scanR5Identity({ repositoryRoot: fixtureRoot, manifest }),
    /public runtime.*declaration/i,
  );

  for (const contract of expectedPublicRuntimeContracts) {
    const target = path.join(fixtureRoot, ...contract.source.split('/'));
    writeFileSync(target, contractSource(contract.declarations), 'utf8');
  }
  writePlainFile(fixtureRoot, 'backend/src/outside-consumer.ts');
  writeFileSync(
    path.join(fixtureRoot, 'backend', 'tsconfig.json'),
    `${JSON.stringify({
      compilerOptions: {
        module: 'commonjs',
        moduleResolution: 'node',
        target: 'ES2022',
        skipLibCheck: true,
      },
      include: ['src/**/*.ts'],
    }, null, 2)}\n`,
    'utf8',
  );
  assert.throws(
    () => scanner.scanR5Identity({ repositoryRoot: fixtureRoot, manifest }),
    /public runtime.*consumer/i,
  );
});

test('R5 architecture command executes the live scanner from the full chain', () => {
  const packageJson = JSON.parse(readFileSync(
    path.join(backendRoot, 'package.json'),
    'utf8',
  ));
  assert.equal(
    packageJson.scripts['architecture:r5'],
    'node scripts/architecture/r5-identity-scan.cjs --check',
  );
  assert.equal(
    packageJson.scripts.architecture.endsWith(' && npm run architecture:r5'),
    true,
  );

  const result = spawnSync(
    process.execPath,
    ['scripts/architecture/r5-identity-scan.cjs', '--check'],
    { cwd: backendRoot, encoding: 'utf8' },
  );
  assert.equal(result.status, 0);
  assert.match(result.stdout, /PASS - R5 Identity relocation: stage=task-3, moves=44/u);
});

test('R5 public contracts exist only at the ten canonical target paths', () => {
  const manifest = readManifest();
  assert.equal(manifest.stage, 'task-3');
  assert.deepEqual(
    manifest.publicRuntimeContracts.map(({ source, target }) => ({ source, target })),
    expectedPublicRuntimeContracts.map(({ source, target }) => ({ source, target })),
  );
  for (const contract of expectedPublicRuntimeContracts) {
    assert.equal(existsSync(path.join(repositoryRoot(), ...contract.source.split('/'))), false);
    assert.equal(existsSync(path.join(repositoryRoot(), ...contract.target.split('/'))), true);
  }

  const identityAuthPort = readFileSync(path.join(
    backendRoot,
    'src',
    'modules',
    'identity',
    'public',
    'identity-auth.port.ts',
  ), 'utf8');
  assert.equal(
    (identityAuthPort.match(/export interface OtpDispatchContext/gu) || []).length,
    1,
  );
  const quotaSource = readFileSync(path.join(
    backendRoot,
    'src',
    'modules',
    'identity',
    'internal',
    'auth',
    'otp-dispatch-quota.service.ts',
  ), 'utf8');
  assert.equal(quotaSource.includes('export interface OtpDispatchContext'), false);
});

test('R5 auth API and internals occupy only their canonical Task 3 paths', () => {
  const manifest = readManifest();
  assert.equal(manifest.stage, 'task-3');
  const authMoves = manifest.moves.filter(
    (move) => move.to.includes('/internal/auth/') || move.to.includes('/api/auth'),
  );
  assert.equal(authMoves.length, 23);
  for (const move of authMoves) {
    assert.equal(existsSync(path.join(repositoryRoot(), ...move.from.split('/'))), false);
    assert.equal(existsSync(path.join(repositoryRoot(), ...move.to.split('/'))), true);
  }
});

test('R5 auth parity rejects provider, DTO, and error-body drift', () => {
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r5-auth-parity-'));
  temporaryRoots.push(fixtureRoot);
  const manifest = readManifest();
  const paths = [
    ...manifest.moves
      .filter((move) => move.to.includes('/internal/auth/') || move.to.includes('/api/auth'))
      .map((move) => move.to),
    'backend/src/modules/identity/identity.module.ts',
    'backend/src/modules/identity/internal/identity-auth.internal.module.ts',
    'backend/src/main.ts',
  ];
  for (const relative of paths) {
    const source = path.join(repositoryRoot(), ...relative.split('/'));
    const target = path.join(fixtureRoot, ...relative.split('/'));
    mkdirSync(path.dirname(target), { recursive: true });
    copyFileSync(source, target);
  }
  const r5 = loadScanner();
  assert.doesNotThrow(() => r5.validateR5AuthStage(fixtureRoot));

  const mutations = [
    {
      path: 'backend/src/modules/identity/internal/identity-auth.internal.module.ts',
      replace: ['useExisting: AuthService', 'useClass: AuthService'],
    },
    {
      path: 'backend/src/modules/identity/api/auth-dto/login.dto.ts',
      replace: ['@MaxLength(40)', '@MaxLength(41)'],
    },
    {
      path: 'backend/src/modules/identity/internal/auth/auth.service.ts',
      replace: ['قد يستغرق وصول الرمز لحظات', 'قد يتغير وصول الرمز'],
    },
  ];
  for (const mutation of mutations) {
    const target = path.join(fixtureRoot, ...mutation.path.split('/'));
    const original = readFileSync(target, 'utf8');
    assert.equal(original.includes(mutation.replace[0]), true, mutation.path);
    writeFileSync(target, original.replace(mutation.replace[0], mutation.replace[1]), 'utf8');
    assert.throws(() => r5.validateR5AuthStage(fixtureRoot), /auth.*drift/i);
    writeFileSync(target, original, 'utf8');
  }
});

function repositoryRoot(): string {
  return path.resolve(backendRoot, '..');
}
