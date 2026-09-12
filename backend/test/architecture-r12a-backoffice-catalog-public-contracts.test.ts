import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

const backendRoot = path.resolve(__dirname, '..');
const scannerPath = path.join(
  backendRoot,
  'scripts',
  'architecture',
  'r12a-backoffice-catalog-public-contracts-scan.cjs',
);
const manifestPath = path.join(
  backendRoot,
  'architecture',
  'r12a-backoffice-catalog-public-contracts.json',
);
const repositoryRoot = path.resolve(backendRoot, '..');
const immutableBase = '4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1';
const readImmutable = (relative: string) =>
  execFileSync('git', ['show', `${immutableBase}:${relative}`], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  });
const readImmutableFile = (revision: string, relative: string) =>
  execFileSync('git', ['show', `${revision}:${relative}`], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  });

const expectedStages = {
  design: { dependencyRecords: 22, ownershipRecords: 385, ownershipOccurrences: 781 },
  backoffice: { dependencyRecords: 17, ownershipRecords: 385, ownershipOccurrences: 781 },
  strict: { dependencyRecords: 16, ownershipRecords: 385, ownershipOccurrences: 781 },
} as const;

test('R12A immutable entry reader is explicit, hash-bound, and fail-closed', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = scanner.validateR12aManifest(r12aManifest());
  const calls: Array<[string, string]> = [];
  const entry = scanner.readR12aImmutableEntry({
    repositoryRoot,
    manifest,
    readImmutableFile: (revision: string, relative: string) => {
      calls.push([revision, relative]);
      return readImmutableFile(revision, relative);
    },
  });

  assert.deepEqual(calls, [
    [manifest.repository.baseCommit, 'backend/.dependency-cruiser-known-violations.json'],
    [manifest.repository.baseCommit, 'backend/architecture/ownership-baseline.json'],
  ]);
  assert.equal(entry.dependency.length, 22);
  assert.equal(entry.ownership.violations.length, 385);
  assert.equal(entry.ownership.violations.reduce(
    (sum: number, item: { count: number }) => sum + item.count,
    0,
  ), 781);
  assert.equal(Object.isFrozen(entry), true);
  assert.equal(Object.isFrozen(entry.dependency), true);
  assert.equal(Object.isFrozen(entry.ownership.violations), true);

  assert.throws(() => scanner.readR12aImmutableEntry({
    repositoryRoot,
    manifest,
    readImmutableFile: 'not-a-function',
  }), /reader|function/u);
  assert.throws(() => scanner.readR12aImmutableEntry({
    repositoryRoot,
    manifest,
    readImmutableFile: () => ({ forged: true }),
  }), /string|Buffer|reader/u);
  assert.throws(() => scanner.readR12aImmutableEntry({
    repositoryRoot,
    manifest,
    readImmutableFile: () => '{not-json',
  }), /JSON|entry|immutable/u);

  const dependency = JSON.parse(readImmutable(
    'backend/.dependency-cruiser-known-violations.json',
  ));
  dependency[0].dependencyTypes = ['import'];
  assert.throws(() => scanner.readR12aImmutableEntry({
    repositoryRoot,
    manifest,
    readImmutableFile: (_revision: string, relative: string) => relative.endsWith(
      'ownership-baseline.json',
    ) ? readImmutableFile(immutableBase, relative) : `${JSON.stringify(dependency, null, 2)}\n`,
  }), /hash|dependency|entry/u);

  const ownership = JSON.parse(readImmutable('backend/architecture/ownership-baseline.json'));
  ownership.violations[0].count += 1;
  assert.throws(() => scanner.readR12aImmutableEntry({
    repositoryRoot,
    manifest,
    readImmutableFile: (_revision: string, relative: string) => relative.endsWith(
      'ownership-baseline.json',
    ) ? `${JSON.stringify(ownership, null, 2)}\n` : readImmutableFile(immutableBase, relative),
  }), /hash|ownership|occurrence|entry/u);

  let reads = 0;
  assert.throws(() => scanner.readR12aImmutableEntry({
    repositoryRoot,
    manifest,
    readImmutableFile: () => {
      reads += 1;
      throw new Error('injected-reader-failed');
    },
  }), /injected-reader-failed/u);
  assert.equal(reads, 1, 'a throwing injected reader must never fall back to Git');
});

test('R12A strict-stage contract exports the scanner and freezes the approved projection counts', () => {
  assert.equal(existsSync(scannerPath), true, 'R12A scanner must exist');
  assert.equal(existsSync(manifestPath), true, 'R12A manifest must exist');
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = scanner.validateR12aManifest(JSON.parse(readFileSync(manifestPath, 'utf8')));
  assert.deepEqual(Object.fromEntries(Object.entries(manifest.stages as Record<string, { dependencyRecords: number }>).map(([stage, value]) => [stage, {
    dependencyRecords: value.dependencyRecords,
    ownershipRecords: manifest.entry.ownershipRecords,
    ownershipOccurrences: manifest.entry.ownershipOccurrences,
  }])), expectedStages);
  assert.equal(manifest.stage, 'strict');
  assert.equal(typeof scanner.scanR12aBackofficeCatalogPublicContracts, 'function');
  assert.deepEqual(
    scanner.scanR12aBackofficeCatalogPublicContracts({ repositoryRoot: path.resolve(backendRoot, '..'), manifest }),
    { ok: true, stage: 'strict', dependencyRecords: 0, ownershipRecords: 385, ownershipOccurrences: 781, legacyPaths: [] },
  );
  for (const move of manifest.moves) {
    const live = readFileSync(path.resolve(repositoryRoot, move.to), 'utf8');
    assert.doesNotThrow(() => scanner.verifyR12aPublicExportInventory(live, move));
  }
});

test('R12A strict projection activates M1 and retires exactly six dependency records', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = scanner.validateR12aManifest(r12aManifest());
  const strict = structuredClone(manifest);
  strict.stage = 'strict';

  const result = scanner.scanR12aBackofficeCatalogPublicContracts({
    repositoryRoot,
    manifest: strict,
  });

  assert.equal(result.stage, 'strict');
  assert.equal(result.dependencyRecords, 0);
  assert.equal(result.ownershipRecords, 385);
  assert.equal(result.ownershipOccurrences, 781);
  assert.equal(strict.stages.strict.retiredDependencyIds.length, 6);
  assert.deepEqual(strict.stages.strict.activeMoveIds, ['B1', 'B2', 'B3', 'B4', 'M1']);
});

test('R12A strict stage retains its historical sibling exception only through the R12C projection', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = scanner.validateR12aManifest(r12aManifest());
  const strict = structuredClone(manifest);
  strict.stage = 'strict';
  const exceptionTexts = strict.exceptionRetirement.map((exception: { path: string }) =>
    readFileSync(path.resolve(repositoryRoot, exception.path), 'utf8'));

  for (const [index, exception] of strict.exceptionRetirement.entries()) {
    assert.equal(scanner.isExactRetiredException(exceptionTexts[index], exception), false);
  }
  const r12cManifest = JSON.parse(readFileSync(path.join(
    backendRoot,
    'architecture',
    'r12c-zero-cross-context-dependencies.json',
  ), 'utf8'));
  const r12c = require(path.join(
    backendRoot,
    'scripts',
    'architecture',
    'r12c-zero-cross-context-dependencies-scan.cjs',
  ));
  const predecessor = r12c.projectR12cWorkingTreeToPredecessor({ repositoryRoot, manifest: r12cManifest });
  for (const relative of [
    'backend/.dependency-cruiser.cjs',
    'backend/scripts/architecture/ports-scan.cjs',
    'backend/scripts/architecture/r3-context-scan.cjs',
  ]) {
    assert.throws(() => scanner.verifyR12aSiblingExceptionText(
      readFileSync(path.resolve(repositoryRoot, relative), 'utf8'),
      relative,
    ));
    assert.doesNotThrow(() => scanner.verifyR12aSiblingExceptionText(
      predecessor.readWorkingFile(relative).toString('utf8'),
      relative,
    ));
  }
});

test('R12A M1 public export and source parity reject wrong function surface and lock order', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const move = r12aManifest().moves.find((item: { id: string }) => item.id === 'M1');
  const historical = readImmutable('backend/src/marketplace/provider-review-rating.ts');
  assert.throws(
    () => scanner.verifyR12aPublicExportInventory('export function wrong() {}\n', move),
    /export inventory/u,
  );
  const moved = historical
    .replace('"../platform/database/serializable-transaction"', '"../../../platform/database/serializable-transaction"')
    .replace('"../platform/database/prisma.service"', '"../../../platform/database/prisma.service"');
  assert.doesNotThrow(() => scanner.verifyR12aSourceParity({
    historicalSource: historical,
    liveSource: moved,
    move,
  }));
  assert.throws(() => scanner.verifyR12aSourceParity({
    historicalSource: historical,
    liveSource: moved.replace('ORDER BY "id" ASC', 'ORDER BY "id" DESC'),
    move,
  }), /parity|drift/u);
});

test('R12A manifest freezes every nested contract, not only its top-level shape', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as Record<string, any>;
  const cases: Array<[string, (value: Record<string, any>) => void]> = [
    ['move import rewrite', (value) => { value.moves[0].importRewrites[0].newModule = '../../identity/public/forged'; }],
    ['consumer rewrite', (value) => { value.consumers[0].importRewrites[0].newModule = '../forged'; }],
    ['behavioral rewrite', (value) => { value.behavioralTests[0].literalRewrites[0].new = 'forged'; }],
    ['retired exception', (value) => { value.exceptionRetirement[0].identity = 'unrelated'; }],
    ['future handoff', (value) => { value.futureHandoffs[0].phase = 'R99'; }],
  ];
  for (const [label, mutate] of cases) {
    const candidate = structuredClone(manifest);
    mutate(candidate);
    assert.throws(() => scanner.validateR12aManifest(candidate), /invalid|changed|unknown|drift/u, label);
  }
});

test('R12A runtime edge prohibition is fail-closed with Windows path separators', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = scanner.validateR12aManifest(JSON.parse(readFileSync(manifestPath, 'utf8')));
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-runtime-edge-'));
  try {
    const source = path.join(fixture, 'backend', 'src', 'modules', 'backoffice', 'public');
    mkdirSync(source, { recursive: true });
    mkdirSync(path.join(fixture, 'backend', 'src', 'modules', 'identity', 'public'), { recursive: true });
    writeFileSync(path.join(fixture, 'backend', 'src', 'modules', 'identity', 'public', 'identity-session.types.ts'), 'export interface IdentitySession {}\n');
    writeFileSync(path.join(source, 'edge.ts'), "import { IdentitySession } from '../../identity/public/identity-session.types';\nexport const edge = IdentitySession;\n");
    assert.throws(
      () => scanner.checkRuntimeEdges(fixture, manifest),
      /Backoffice-public to Identity-public/u,
    );
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
});

test('R12A source and literal parity reject undeclared drift and preserve run-only bytes', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = scanner.validateR12aManifest(JSON.parse(readFileSync(manifestPath, 'utf8')));
  const move = manifest.moves.find((item: { id: string }) => item.id === 'B1');
  const historical = readImmutable('backend/src/admin/admin.guard.ts');
  const movedSource = historical
    .replace("'../modules/identity/public/identity-session.types'", "'../../identity/public/identity-session.types'")
    .replace('import { AuthenticatedUser }', 'import type { AuthenticatedUser }');
  assert.throws(() => scanner.verifyR12aSourceParity({ historicalSource: historical, liveSource: movedSource.replace('return true;', 'return false;'), move }), /parity|drift/u);
  const undeclaredImport = movedSource.replace("import {\n", "import { Forged } from './forged';\nimport {\n");
  assert.throws(() => scanner.verifyR12aSourceParity({ historicalSource: historical, liveSource: undeclaredImport, move }), /import|parity/u);
  const runOnly = manifest.behavioralTests.find((item: { mode: string }) => item.mode === 'run-only');
  const runSource = readFileSync(path.join(backendRoot, 'test', path.basename(runOnly.path)), 'utf8');
  assert.throws(() => scanner.verifyR12aLiteralParity({ historicalSource: runSource, liveSource: `${runSource} `, contract: runOnly, manifest }), /run-only|drift/u);
});

test('R12A exception retirement matches the exact rule/edge, not broad tokens', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const exception = manifest.exceptionRetirement[0];
  const source = readImmutable(exception.path);
  assert.equal(scanner.isExactRetiredException(source, exception), true);
  const retargeted = source.replace(
    '...makeContextRule(name, ownRoots, [], providerReviewRating),\n        name: \'context-identity-relocated-users-helper-cross-context\'',
    '...makeContextRule(name, ownRoots, [], providerAccessPolicy),\n        name: \'context-identity-relocated-users-helper-cross-context\'',
  );
  assert.equal(scanner.isExactRetiredException(retargeted, exception), false);
  const changedBinding = source.replace(
    "'^src/marketplace/provider-review-rating\\\\.ts$'",
    "'^src/provider-dashboard/provider-access-policy\\\\.ts$'",
  );
  assert.equal(scanner.isExactRetiredException(changedBinding, exception), false);
});

function r12aManifest(): Record<string, any> {
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as Record<string, any>;
}

function rejectManifest(mutate: (manifest: Record<string, any>) => void): void {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const candidate = r12aManifest();
  mutate(candidate);
  assert.throws(() => scanner.validateR12aManifest(candidate));
}

test('R12A rejects unknown manifest keys and skipped stage input', () => {
  rejectManifest((manifest) => { manifest.unknown = true; });
  // A backoffice manifest against the strict filesystem is an invalid skipped input state.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const candidate = r12aManifest(); candidate.stage = 'backoffice';
  assert.throws(() => scanner.scanR12aBackofficeCatalogPublicContracts({ repositoryRoot: path.resolve(backendRoot, '..'), manifest: candidate }), /successor manifest input is not the exact predecessor/u);
});

test('R12A rejects duplicate or seventh retired dependency keys', () => {
  rejectManifest((manifest) => { manifest.stages.design.retiredDependencyIds = [1, 1]; });
  rejectManifest((manifest) => { manifest.stages.design.retiredDependencyIds = [1, 2, 3, 4, 5, 6, 7]; });
});

test('R12A rejects every dependency projection count other than the approved stage counts', () => {
  for (const stage of ['design', 'backoffice', 'strict']) rejectManifest((manifest) => { manifest.stages[stage].dependencyRecords += 1; });
});

test('R12A dependency projection rejects changed metadata and duplicate entry records', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'strict';
  const entry = JSON.parse(readImmutable('backend/.dependency-cruiser-known-violations.json')) as any[];
  for (const mutate of [
    (record: any) => { record.type = 'not-a-dependency'; },
    (record: any) => { record.unresolvedTo = '../forged'; },
    (record: any) => { record.dependencyTypes = ['import', 'local']; },
    (record: any) => { record.rule.severity = 'warn'; },
    (record: any) => { record.extra = true; },
  ]) {
    const changed = structuredClone(entry); mutate(changed[0]);
    assert.throws(() => scanner.expectedR12aDependencyRecords(changed, manifest), /deep|projection/u);
  }
  const duplicate = [...entry, structuredClone(entry[0])];
  assert.throws(() => scanner.expectedR12aDependencyRecords(duplicate, manifest), /projection/u);
});

test('R12A rejects ownership count, occurrence, and second-projection drift', () => {
  rejectManifest((manifest) => { manifest.entry.ownershipRecords += 1; });
  rejectManifest((manifest) => { manifest.entry.ownershipOccurrences += 1; });
  rejectManifest((manifest) => { manifest.ownershipProjection.extra = true; });
  rejectManifest((manifest) => { manifest.ownershipProjection.unchanged.count = 2; });
});

test('R12A ownership projection changes exactly one canonical record', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const baseline = JSON.parse(readImmutable('backend/architecture/ownership-baseline.json'));
  const duplicate = structuredClone(baseline); duplicate.violations.push(structuredClone(duplicate.violations.find((item: any) => item.key === manifest.ownershipProjection.oldKey)));
  assert.throws(() => scanner.expectedR12aOwnershipBaseline(duplicate, manifest), /projection/u);
  const changed = structuredClone(baseline); changed.violations.find((item: any) => item.key === manifest.ownershipProjection.oldKey).count += 1;
  assert.throws(() => scanner.expectedR12aOwnershipBaseline(changed, manifest), /semantics|totals/u);
});

test('R12A rejects legacy/public co-existence and facade/re-export implementations', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  assert.throws(() => scanner.validateR12aMoveLayout('legacy.ts', 'public.ts', true), /move layout/u);
  assert.throws(() => scanner.validateR12aMoveLayout(null, null, false), /move layout/u);
  const move = r12aManifest().moves[0];
  const historical = readImmutable('backend/src/admin/admin.guard.ts');
  assert.throws(() => scanner.verifyR12aSourceParity({ historicalSource: historical, liveSource: 'export { AdminGuard } from "./admin.guard";\n', move }), /source|import|parity/u);
});

test('R12A public export inventory rejects the wrong export surface', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const move = r12aManifest().moves[0];
  assert.throws(() => scanner.verifyR12aPublicExportInventory('export class Wrong {}\n', move), /export inventory/u);
});

test('R12A exact allowed-edge variants reject wrong source, target, names, and stage', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = scanner.validateR12aManifest(r12aManifest());
  const edge = manifest.runtimePublicEdges[0];
  for (const variant of [
    { ...edge, source: 'backend/src/wrong.ts' },
    { ...edge, target: 'backend/src/wrong.ts' },
    { ...edge, importedNames: ['refreshProviderRating'] },
    { ...edge, stage: 'backoffice' },
  ]) {
    const candidate = structuredClone(manifest); candidate.runtimePublicEdges = [variant];
    assert.equal(scanner.isAllowedR12aRuntimePublicEdge(variant, candidate), false);
  }
});

test('R12A guard order rejects a temporary controller with reordered guards', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-guard-order-'));
  try {
    const dir = path.join(fixture, 'backend', 'src', 'admin'); mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'controller.ts'), "import { UseGuards } from '@nestjs/common';\n@UseGuards(AdminGuard, JwtSessionGuard, AdminPermissionGuard)\nexport class Controller {}\n");
    assert.throws(() => scanner.checkGuardOrder(fixture), /guard order/u);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A guard order resolves an aliased Nest UseGuards import', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-guard-alias-'));
  try {
    const dir = path.join(fixture, 'backend', 'src', 'admin'); mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'controller.ts'), [
      "import { UseGuards as Guards } from '@nestjs/common';",
      'Guards(AdminGuard, JwtSessionGuard, AdminPermissionGuard);',
      'export class Controller {}',
      '',
    ].join('\n'));
    assert.throws(() => scanner.checkGuardOrder(fixture), /guard order/u);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A guard order resolves a Nest namespace UseGuards property', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-guard-namespace-'));
  try {
    const dir = path.join(fixture, 'backend', 'src', 'admin'); mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'controller.ts'), [
      "import * as common from '@nestjs/common';",
      'common.UseGuards(AdminGuard, JwtSessionGuard, AdminPermissionGuard);',
      'export class Controller {}',
      '',
    ].join('\n'));
    assert.throws(() => scanner.checkGuardOrder(fixture), /guard order/u);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A guard order ignores local homonyms without the Nest import', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-guard-homonym-'));
  try {
    const dir = path.join(fixture, 'backend', 'src', 'admin'); mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'controller.ts'), [
      'function UseGuards(...args: unknown[]) { return args; }',
      'UseGuards(AdminGuard, JwtSessionGuard, AdminPermissionGuard);',
      'export class Controller {}',
      '',
    ].join('\n'));
    assert.doesNotThrow(() => scanner.checkGuardOrder(fixture));
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A guard order ignores a nested homonym shadowing the Nest binding', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-guard-shadow-'));
  try {
    const dir = path.join(fixture, 'backend', 'src', 'admin'); mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'controller.ts'), [
      "import { UseGuards } from '@nestjs/common';",
      'function localScope() {',
      '  const UseGuards = (...args: unknown[]) => args;',
      '  UseGuards(AdminGuard, JwtSessionGuard, AdminPermissionGuard);',
      '}',
      'export class Controller {}',
      '',
    ].join('\n'));
    assert.doesNotThrow(() => scanner.checkGuardOrder(fixture));
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A guard order ignores a nested namespace homonym shadowing Nest common', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-guard-namespace-shadow-'));
  try {
    const dir = path.join(fixture, 'backend', 'src', 'admin'); mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'controller.ts'), [
      "import * as common from '@nestjs/common';",
      'function localScope() {',
      '  const common = { UseGuards: (...args: unknown[]) => args };',
      '  common.UseGuards(AdminGuard, JwtSessionGuard, AdminPermissionGuard);',
      '}',
      'export class Controller {}',
      '',
    ].join('\n'));
    assert.doesNotThrow(() => scanner.checkGuardOrder(fixture));
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A unapproved source consumer fails against a temporary active target', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-unapproved-consumer-'));
  try {
    const dir = path.join(fixture, 'backend', 'src'); mkdirSync(dir, { recursive: true });
    const target = path.join(dir, 'modules', 'backoffice', 'public'); mkdirSync(target, { recursive: true });
    writeFileSync(path.join(target, 'admin.guard.ts'), 'export class AdminGuard {}\n');
    writeFileSync(path.join(dir, 'unapproved.ts'), "import { AdminGuard } from './modules/backoffice/public/admin.guard';\nexport const value = AdminGuard;\n");
    assert.throws(() => scanner.checkRuntimeEdges(fixture, manifest), /unapproved source consumer/u);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A runtime edges resolve JavaScript specifiers to active TypeScript targets', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-runtime-js-specifier-'));
  try {
    const dir = path.join(fixture, 'backend', 'src'); mkdirSync(dir, { recursive: true });
    const target = path.join(dir, 'modules', 'backoffice', 'public'); mkdirSync(target, { recursive: true });
    writeFileSync(path.join(target, 'admin.guard.ts'), 'export class AdminGuard {}\n');
    writeFileSync(path.join(dir, 'unapproved.ts'), "import { AdminGuard } from './modules/backoffice/public/admin.guard.js';\nexport const value = AdminGuard;\n");
    assert.throws(() => scanner.checkRuntimeEdges(fixture, manifest), /unapproved source consumer/u);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A runtime edges resolve directory index barrels to active targets', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-runtime-directory-barrel-'));
  try {
    const sourceDir = path.join(fixture, 'backend', 'src'); const publicDir = path.join(sourceDir, 'modules', 'backoffice', 'public');
    mkdirSync(publicDir, { recursive: true });
    writeFileSync(path.join(sourceDir, 'unapproved.ts'), "import { AdminGuard } from './modules/backoffice/public';\nexport const value = AdminGuard;\n");
    writeFileSync(path.join(publicDir, 'index.ts'), "export { AdminGuard } from './admin.guard';\n");
    writeFileSync(path.join(publicDir, 'admin.guard.ts'), 'export class AdminGuard {}\n');
    assert.throws(() => scanner.checkRuntimeEdges(fixture, manifest), /unapproved source consumer/u);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A runtime edges reject unresolved local module forms', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-runtime-unresolved-'));
  try {
    const dir = path.join(fixture, 'backend', 'src'); mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'unresolved.ts'), "import value from './missing-local-module';\nexport { value };\n");
    assert.throws(() => scanner.checkRuntimeEdges(fixture, manifest), /unresolved|suspicious/u);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A runtime edges follow CommonJS forwarding facades and reject ambiguous or cyclic forwarding', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const cases = [
    ['direct', 'module.exports = require(\'./modules/backoffice/public/admin.guard\');'],
    ['alias', "const contract = require('./modules/backoffice/public/admin.guard');\nmodule.exports = contract;"],
    ['exports-property', "const contract = require('./modules/backoffice/public/admin.guard');\nexports.AdminGuard = contract.AdminGuard;"],
  ];
  for (const [name, body] of cases) {
    const fixture = mkdtempSync(path.join(os.tmpdir(), `r12a-cjs-${name}-`));
    try {
      const sourceDir = path.join(fixture, 'backend', 'src'); const publicDir = path.join(sourceDir, 'modules', 'backoffice', 'public'); mkdirSync(publicDir, { recursive: true });
      writeFileSync(path.join(sourceDir, 'unapproved.ts'), `import contract from './facade';\nexport const value = contract;\n`);
      writeFileSync(path.join(sourceDir, 'facade.ts'), `${body}\n`);
      writeFileSync(path.join(publicDir, 'admin.guard.ts'), 'export class AdminGuard {}\n');
      assert.throws(() => scanner.checkRuntimeEdges(fixture, manifest), /unapproved source consumer/u, name);
    } finally { rmSync(fixture, { recursive: true, force: true }); }
  }
  const safe = mkdtempSync(path.join(os.tmpdir(), 'r12a-cjs-safe-'));
  try {
    const sourceDir = path.join(safe, 'backend', 'src'); mkdirSync(sourceDir, { recursive: true });
    writeFileSync(path.join(sourceDir, 'unapproved.ts'), "import value from './facade';\nexport { value };\n");
    writeFileSync(path.join(sourceDir, 'facade.ts'), "const local = require('./safe');\nmodule.exports = local;\n");
    writeFileSync(path.join(sourceDir, 'safe.ts'), 'module.exports = { value: true };\n');
    assert.doesNotThrow(() => scanner.checkRuntimeEdges(safe, manifest));
  } finally { rmSync(safe, { recursive: true, force: true }); }
  for (const [name, bodyA, bodyB] of [
    ['cycle', "module.exports = require('./b');\n", "module.exports = require('./a');\n"],
    ['ambiguous', "module.exports = require('./a') || require('./b');\n", 'module.exports = { value: true };\n'],
  ]) {
    const fixture = mkdtempSync(path.join(os.tmpdir(), `r12a-cjs-${name}-`));
    try {
      const sourceDir = path.join(fixture, 'backend', 'src'); mkdirSync(sourceDir, { recursive: true });
      writeFileSync(path.join(sourceDir, 'unapproved.ts'), "import value from './facade';\nexport { value };\n");
      writeFileSync(path.join(sourceDir, 'facade.ts'), bodyA); writeFileSync(path.join(sourceDir, 'a.ts'), bodyB); writeFileSync(path.join(sourceDir, 'b.ts'), bodyB);
      assert.throws(() => scanner.checkRuntimeEdges(fixture, manifest), /cyclic|ambiguous|forwarding/u, name);
    } finally { rmSync(fixture, { recursive: true, force: true }); }
  }
});

test('R12A consumer and behavioral parity reject undeclared executable/test rewrites and inactive-stage rewrites', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const consumer = manifest.consumers.find((item: any) => item.path.endsWith('admin-audit.controller.ts'));
  const historical = readImmutable('backend/src/admin/admin-audit.controller.ts');
  assert.throws(() => scanner.verifyR12aConsumerParity({ historicalSource: historical, liveSource: historical, contract: consumer, manifest }), /rewrite stage/u);
  const moved = historical
    .replaceAll('./admin.guard', '../modules/backoffice/public/admin.guard')
    .replaceAll('./admin-permission.decorator', '../modules/backoffice/public/admin-permission.decorator')
    .replaceAll('./admin-permission.guard', '../modules/backoffice/public/admin-permission.guard');
  assert.throws(() => scanner.verifyR12aConsumerParity({ historicalSource: historical, liveSource: `${moved}\n// undeclared\n`, contract: consumer, manifest }), /parity/u);
  const behavioral = manifest.behavioralTests.find((item: any) => item.mode === 'rewrite');
  const testHistorical = readImmutable(behavioral.path);
  const activeTest = behavioral.literalRewrites.reduce((source: string, rewrite: any) => source.replaceAll(rewrite.old, rewrite.new), testHistorical);
  assert.doesNotThrow(() => scanner.verifyR12aLiteralParity({ historicalSource: testHistorical, liveSource: activeTest, contract: behavioral, manifest }));
  assert.throws(() => scanner.verifyR12aLiteralParity({ historicalSource: testHistorical, liveSource: `${activeTest}\n// undeclared\n`, contract: behavioral, manifest }), /parity/u);
  const design = structuredClone(manifest); design.stage = 'design';
  assert.throws(() => scanner.verifyR12aLiteralParity({ historicalSource: testHistorical, liveSource: activeTest, contract: behavioral, manifest: design }), /rewrite stage/u);
});

test('R12A rejects unknown move IDs and active/inactive stale rewrites', () => {
  rejectManifest((manifest) => { manifest.consumers[0].importRewrites[0].moveId = 'UNKNOWN'; });
  rejectManifest((manifest) => { manifest.behavioralTests[0].literalRewrites[0].moveId = 'UNKNOWN'; });
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const contract = manifest.consumers.find((item: any) => item.path.endsWith('admin-audit.controller.ts'));
  const source = readImmutable('backend/src/admin/admin-audit.controller.ts');
  assert.throws(() => scanner.verifyR12aConsumerParity({ historicalSource: source, liveSource: source, contract, manifest }), /rewrite stage/u);
});

test('R12A compares behavioral literals exactly, including substring near-misses', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = r12aManifest(); manifest.stage = 'backoffice';
  const contract = manifest.behavioralTests.find((item: any) => item.path.endsWith('admin-mutation-authorization.test.ts'));
  const historical = readImmutable(contract.path);
  const active = historical.replaceAll('admin-mutation-gate.ts', '../modules/backoffice/public/admin-mutation-gate.ts');
  assert.doesNotThrow(() => scanner.verifyR12aLiteralParity({ historicalSource: historical, liveSource: active, contract, manifest }));
  assert.throws(() => scanner.verifyR12aLiteralParity({ historicalSource: historical, liveSource: `${active}\nconst stale = 'admin-mutation-gate.ts';\n`, contract, manifest }), /rewrite stage|parity/u);
});

test('R12A rejects path traversal and symlink/reparse fixture paths', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'r12a-paths-'));
  try {
    assert.throws(() => scanner.inspectFile(fixture, 'backend/../outside.ts'), /escapes/u);
    const dir = path.join(fixture, 'backend'); mkdirSync(dir, { recursive: true }); writeFileSync(path.join(fixture, 'outside.ts'), 'export {};\n');
    try {
      fs.symlinkSync(path.join(fixture, 'outside.ts'), path.join(dir, 'link.ts'));
      assert.throws(() => scanner.inspectFile(fixture, 'backend/link.ts'), /symlink|reparse/u);
    } catch (error) {
      if (!(error instanceof Error) || !/privilege|not supported|already exists/u.test(error.message)) throw error;
    }
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

test('R12A predecessor sibling provider-access-policy exception remains exact while live R12C removes it', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const scanner = require(scannerPath);
  const manifest = scanner.validateR12aManifest(r12aManifest());
  const r12cManifest = JSON.parse(readFileSync(path.join(backendRoot, 'architecture/r12c-zero-cross-context-dependencies.json'), 'utf8'));
  const r12c = require(path.join(backendRoot, 'scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs'));
  const projected = r12c.projectR12cWorkingTreeToPredecessor({ repositoryRoot, manifest: r12cManifest });
  const source = projected.readWorkingFile('backend/.dependency-cruiser.cjs').toString('utf8');
  assert.throws(() => scanner.verifyR12aSiblingExceptionText(
    readFileSync(path.join(backendRoot, '.dependency-cruiser.cjs'), 'utf8'),
    'backend/.dependency-cruiser.cjs',
  ));
  assert.doesNotThrow(() => scanner.verifyR12aSiblingExceptionText(source, 'backend/.dependency-cruiser.cjs'));
  const siblingRemoved = source.replace('context-identity-relocated-contexts-helper-cross-context', 'removed-context-rule');
  assert.throws(() => scanner.verifyR12aSiblingExceptionText(siblingRemoved, 'backend/.dependency-cruiser.cjs'), /sibling|provider-access-policy/u);
});

test('R12B successor handoff preserves historical 16 and selects exact live 9', () => {
  const r12a = require(path.join(
    backendRoot,
    'scripts',
    'architecture',
    'r12a-backoffice-catalog-public-contracts-scan.cjs',
  ));
  const r12aManifest = JSON.parse(readFileSync(path.join(
    backendRoot,
    'architecture',
    'r12a-backoffice-catalog-public-contracts.json',
  ), 'utf8'));
  const entry = r12a.readR12aImmutableEntry({
    repositoryRoot,
    manifest: r12aManifest,
    readImmutableFile: (revision: string, relative: string) => require('node:child_process').execFileSync(
      'git',
      ['show', `${revision}:${relative}`],
      { cwd: repositoryRoot, encoding: 'utf8' },
    ),
  });
  const historicalRoot = mkdtempSync(path.join(os.tmpdir(), 'aarast-r12a-no-r12b-'));
  try {
    assert.equal(r12a.expectedR12aSuccessorDependencyRecords({
      repositoryRoot: historicalRoot,
      r12aEntryRecords: entry.dependency,
      r12aManifest,
      readImmutableFile: () => { throw new Error('no immutable read before R12B exists'); },
    }).length, 16);
  } finally {
    rmSync(historicalRoot, { recursive: true, force: true });
  }
  assert.equal(r12a.expectedR12aSuccessorDependencyRecords({
    repositoryRoot,
    r12aEntryRecords: entry.dependency,
    r12aManifest,
    readImmutableFile: (revision: string, relative: string) => require('node:child_process').execFileSync(
      'git',
      ['show', `${revision}:${relative}`],
      { cwd: repositoryRoot, encoding: 'utf8' },
    ),
  }).length, 0);
});

function r12bSuccessorFixture() {
  const r12a = require(scannerPath);
  const manifest = r12aManifest();
  const entry = r12a.readR12aImmutableEntry({ repositoryRoot, manifest });
  const r12aBytes = readFileSync(manifestPath);
  const r12bBytes = readFileSync(path.join(
    backendRoot,
    'architecture',
    'r12b-planning-public-contracts.json',
  ));
  const writeManifests = (root: string) => {
    const architecture = path.join(root, 'backend', 'architecture');
    mkdirSync(architecture, { recursive: true });
    writeFileSync(path.join(architecture, 'r12a-backoffice-catalog-public-contracts.json'), r12aBytes);
    writeFileSync(path.join(architecture, 'r12b-planning-public-contracts.json'), r12bBytes);
  };
  const project = (root: string) => r12a.expectedR12aSuccessorDependencyRecords({
    repositoryRoot: root,
    r12aEntryRecords: entry.dependency,
    r12aManifest: manifest,
  });
  return { project, writeManifests };
}

test('R12B successor Git authority rejects parent-repository fallback', () => {
  const { project, writeManifests } = r12bSuccessorFixture();
  const nestedRoot = mkdtempSync(path.join(repositoryRoot, '.r12b-parent-fallback-'));
  try {
    writeManifests(nestedRoot);
    assert.throws(() => project(nestedRoot), /Git|authority|repository root/iu);
  } finally {
    rmSync(nestedRoot, { recursive: true, force: true });
  }
});

test('R12B successor Git authority rejects a copied linked-worktree control file', () => {
  const { project, writeManifests } = r12bSuccessorFixture();
  const copiedRoot = mkdtempSync(path.join(os.tmpdir(), 'r12b-copied-git-control-'));
  try {
    writeManifests(copiedRoot);
    writeFileSync(path.join(copiedRoot, '.git'), readFileSync(path.join(repositoryRoot, '.git')));
    assert.throws(() => project(copiedRoot), /Git|authority|repository root/iu);
  } finally {
    rmSync(copiedRoot, { recursive: true, force: true });
  }
});

test('R12B successor Git authority rejects missing, malformed, and incomplete controls', () => {
  const { project, writeManifests } = r12bSuccessorFixture();
  const roots = [
    mkdtempSync(path.join(os.tmpdir(), 'r12b-missing-git-control-')),
    mkdtempSync(path.join(os.tmpdir(), 'r12b-malformed-git-control-')),
    mkdtempSync(path.join(os.tmpdir(), 'r12b-incomplete-git-control-')),
  ];
  try {
    for (const root of roots) writeManifests(root);
    writeFileSync(path.join(roots[1], '.git'), 'gitdir: missing-worktree-control\n');
    mkdirSync(path.join(roots[2], '.git'));
    for (const root of roots) {
      assert.throws(() => project(root), /Git|authority|repository/iu, root);
    }
  } finally {
    for (const root of roots) rmSync(root, { recursive: true, force: true });
  }
});

test('R12B successor Git authority accepts the exact live linked worktree', () => {
  const { project } = r12bSuccessorFixture();
  assert.equal(project(repositoryRoot).length, 0);
});
