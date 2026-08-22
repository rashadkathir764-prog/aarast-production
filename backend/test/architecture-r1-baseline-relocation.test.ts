import assert from 'node:assert/strict';
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
  mkdirSync,
  linkSync,
  renameSync,
  symlinkSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';

type JsonObject = Record<string, unknown>;

const {
  runCli,
  verifyRelocation,
} = require('../scripts/architecture/r1-baseline-relocation.cjs') as {
  runCli: (dependencies: Record<string, unknown>) => number;
  verifyRelocation: (input: Record<string, unknown>) => JsonObject;
};

const baseRevision = '94b677b7b8e2219e0db2cbc553fa3d26b4876456';
const sourceRevision = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';
const backendRoot = path.resolve(__dirname, '..');
const fixtureRoots: string[] = [];
const approvedMap = require('../architecture/r1-relocation-map.json') as JsonObject;

function ignoredBackendFixture(prefix: string): string {
  const parent = path.join(backendRoot, 'dist', 'test-fixtures');
  mkdirSync(parent, { recursive: true });
  const root = mkdtempSync(path.join(parent, prefix));
  fixtureRoots.push(root);
  return root;
}

function relativeSpecifier(from: string, to: string): string {
  const withoutExtension = to.replace(/\.(?:[cm]?[jt]sx?)$/, '');
  const relative = path.posix.relative(path.posix.dirname(from), withoutExtension);
  return relative.startsWith('.') ? relative : `./${relative}`;
}

function dependency(
  from: string,
  to: string,
  rule = 'current-platform-no-business-contexts',
) {
  return {
    type: 'dependency',
    from,
    to,
    unresolvedTo: relativeSpecifier(from, to),
    dependencyTypes: ['local', 'import'],
    rule: { severity: 'error', name: rule },
  };
}

function ownership(file: string, count = 2, model = 'User') {
  const record = {
    file,
    context: 'platform',
    owner: 'identity',
    model,
    operation: 'findUnique',
    mode: 'read',
    source: 'delegate',
    reason: 'foreign-model',
    count,
  };
  return {
    key: [
      record.file,
      record.context,
      record.owner,
      record.model,
      record.operation,
      record.mode,
      record.source,
      record.reason,
    ].join('|'),
    ...record,
  };
}

function ownershipBaseline(records: unknown[]) {
  return { schemaVersion: 1, sourceRevision, violations: records };
}

function relocationMap(overrides: Partial<JsonObject> = {}) {
  return {
    ...structuredClone(approvedMap),
    ...overrides,
  };
}

function makeFixture(options: {
  baseDependencies?: unknown;
  candidateDependencies?: unknown;
  baseOwnership?: unknown;
  candidateOwnership?: unknown;
  map?: unknown;
} = {}) {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r1-relocation-'));
  fixtureRoots.push(root);
  const architecture = path.join(root, 'architecture');
  mkdirSync(architecture, { recursive: true });
  const dependencyCandidate = path.join(root, 'dependency-candidate.json');
  const ownershipCandidate = path.join(root, 'ownership-candidate.json');
  const mapFile = path.join(architecture, 'r1-relocation-map.json');
  const report = path.join(root, 'report.json');
  const baseDependencies = options.baseDependencies ?? [
    dependency(
      'src/admin/admin-audit.controller.ts',
      'src/auth/jwt-session.guard.ts',
      'context-backoffice-cross-context',
    ),
    dependency('src/common/config/runtime-environment.ts', 'src/auth/jwt-session.guard.ts'),
  ];
  const candidateDependencies = options.candidateDependencies ?? [
    dependency(
      'src/platform/config/runtime-environment.ts',
      'src/auth/jwt-session.guard.ts',
      'platform-no-business-contexts',
    ),
  ];
  const baseOwnership = options.baseOwnership ?? ownershipBaseline([
    ownership('backend/src/common/config/runtime-environment.ts', 2),
  ]);
  const candidateOwnership = options.candidateOwnership ?? ownershipBaseline([
    ownership('backend/src/platform/config/runtime-environment.ts', 1),
  ]);
  writeFileSync(dependencyCandidate, `${JSON.stringify(candidateDependencies, null, 2)}\n`);
  writeFileSync(ownershipCandidate, `${JSON.stringify(candidateOwnership, null, 2)}\n`);
  writeFileSync(mapFile, `${JSON.stringify(options.map ?? relocationMap(), null, 2)}\n`);
  return {
    root,
    dependencyCandidate,
    ownershipCandidate,
    mapFile,
    report,
    baseDependencies,
    baseOwnership,
  };
}

function captureCli(fixture: ReturnType<typeof makeFixture>, overrides: JsonObject = {}) {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const args = [
    '--verify',
    '--base-ref', baseRevision,
    '--dependency-candidate', fixture.dependencyCandidate,
    '--ownership-candidate', fixture.ownershipCandidate,
    '--map', 'architecture/r1-relocation-map.json',
    '--report', fixture.report,
  ];
  const dependencies: JsonObject = {
    argv: args,
    cwd: fixture.root,
    readBaseJson: (_revision: string, repositoryPath: string) => (
      repositoryPath === 'backend/.dependency-cruiser-known-violations.json'
        ? fixture.baseDependencies
        : fixture.baseOwnership
    ),
    stdout: (message: string) => stdout.push(message),
    stderr: (message: string) => stderr.push(message),
    ...overrides,
  };
  return {
    exitCode: runCli(dependencies),
    stdout,
    stderr,
  };
}

function replaceAtomically(target: string, value: unknown) {
  const replacement = `${target}.${process.pid}.replacement`;
  writeFileSync(replacement, `${JSON.stringify(value, null, 2)}\n`);
  renameSync(replacement, target);
}

afterEach(() => {
  for (const root of fixtureRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('exact dependency and ownership relocations pass with deterministic sanitized totals', () => {
  const fixture = makeFixture();
  const result = captureCli(fixture);
  assert.equal(result.exitCode, 0);
  assert.deepEqual(result.stderr, []);
  assert.deepEqual(result.stdout, ['R1 baseline relocation verified']);

  const reportText = readFileSync(fixture.report, 'utf8');
  const report = JSON.parse(reportText);
  assert.deepEqual(Object.keys(report), ['baseRevision', 'candidateHashes', 'totals']);
  assert.equal(report.baseRevision, baseRevision);
  assert.deepEqual(Object.keys(report.candidateHashes), ['dependency', 'ownership']);
  assert.match(report.candidateHashes.dependency, /^[a-f0-9]{64}$/);
  assert.match(report.candidateHashes.ownership, /^[a-f0-9]{64}$/);
  assert.deepEqual(report.totals, {
    dependency: { mapped: 1, removed: 1, decreased: 0 },
    ownership: { mapped: 1, removed: 0, decreased: 1 },
  });
  assert.doesNotMatch(reportText, /runtime-environment|jwt-session|User|TOKEN|absolute/i);
});

test('unchanged records, removals, and ownership count decreases pass', () => {
  const unchangedDependency = dependency(
    'src/admin/admin-audit.controller.ts',
    'src/auth/jwt-session.guard.ts',
    'context-backoffice-cross-context',
  );
  const unchangedOwnership = ownership('backend/src/auth/auth.service.ts', 3);
  const fixture = makeFixture({
    baseDependencies: [unchangedDependency, dependency(
      'src/common/config/runtime-environment.ts',
      'src/auth/jwt-session.guard.ts',
    )],
    candidateDependencies: [unchangedDependency],
    baseOwnership: ownershipBaseline([
      unchangedOwnership,
      ownership('backend/src/common/config/runtime-environment.ts', 2),
    ]),
    candidateOwnership: ownershipBaseline([{ ...unchangedOwnership, count: 2 }]),
  });
  const result = captureCli(fixture);
  assert.equal(result.exitCode, 0);
  const report = JSON.parse(readFileSync(fixture.report, 'utf8'));
  assert.deepEqual(report.totals, {
    dependency: { mapped: 0, removed: 1, decreased: 0 },
    ownership: { mapped: 0, removed: 1, decreased: 1 },
  });
});

test('canonical repository filenames may describe secret handling without containing a secret value', () => {
  const legitimate = dependency(
    'src/auth/jwt.strategy.ts',
    'src/auth/jwt-secret.ts',
    'context-identity-cross-context',
  );
  const fixture = makeFixture({
    baseDependencies: [legitimate],
    candidateDependencies: [legitimate],
    baseOwnership: ownershipBaseline([]),
    candidateOwnership: ownershipBaseline([]),
  });
  assert.equal(captureCli(fixture).exitCode, 0);
});

test('canonical domain identifiers may name secret-handling models without containing a secret value', () => {
  const legitimate = ownership('backend/src/auth/refresh-token.repository.ts', 2, 'RefreshToken');
  const fixture = makeFixture({
    baseDependencies: [],
    candidateDependencies: [],
    baseOwnership: ownershipBaseline([legitimate]),
    candidateOwnership: ownershipBaseline([legitimate]),
  });
  assert.equal(captureCli(fixture).exitCode, 0);
});

test('dependency records use dependency-cruiser canonical rule-from-to ordering', () => {
  const records = [
    dependency('src/z-last/source.ts', 'src/auth/target.ts', 'context-alpha-cross-context'),
    dependency('src/a-first/source.ts', 'src/auth/target.ts', 'context-beta-cross-context'),
  ];
  const fixture = makeFixture({
    baseDependencies: records,
    candidateDependencies: records,
    baseOwnership: ownershipBaseline([]),
    candidateOwnership: ownershipBaseline([]),
  });
  assert.equal(captureCli(fixture).exitCode, 0);
});

test('declared source prefixes may converge on one canonical destination directory', () => {
  const filterDependency = dependency('src/common/filters/a.ts', 'src/auth/target.ts');
  const httpDependency = dependency('src/common/http/b.ts', 'src/auth/target.ts');
  const filterOwnership = ownership('backend/src/common/filters/a.ts');
  const httpOwnership = ownership('backend/src/common/http/b.ts');
  const fixture = makeFixture({
    baseDependencies: [filterDependency, httpDependency],
    candidateDependencies: [
      dependency('src/platform/http/a.ts', 'src/auth/target.ts', 'platform-no-business-contexts'),
      dependency('src/platform/http/b.ts', 'src/auth/target.ts', 'platform-no-business-contexts'),
    ],
    baseOwnership: ownershipBaseline([filterOwnership, httpOwnership]),
    candidateOwnership: ownershipBaseline([
      ownership('backend/src/platform/http/a.ts'),
      ownership('backend/src/platform/http/b.ts'),
    ]),
  });
  assert.equal(captureCli(fixture).exitCode, 0);
});

test('future relocation prefixes may remain unchanged when another edge endpoint moves now', () => {
  const current = dependency(
    'src/common/config/runtime-environment.ts',
    'src/auth/openwa-otp-config.ts',
    'current-platform-no-business-contexts',
  );
  const staged = dependency(
    'src/platform/config/runtime-environment.ts',
    'src/auth/openwa-otp-config.ts',
    'platform-no-business-contexts',
  );
  const futureOwnership = ownership('backend/src/common/idempotency/idempotency.service.ts');
  const fixture = makeFixture({
    baseDependencies: [current],
    candidateDependencies: [staged],
    baseOwnership: ownershipBaseline([futureOwnership]),
    candidateOwnership: ownershipBaseline([futureOwnership]),
  });
  const result = captureCli(fixture);
  assert.equal(result.exitCode, 0);
  const report = JSON.parse(readFileSync(fixture.report, 'utf8'));
  assert.deepEqual(report.totals, {
    dependency: { mapped: 1, removed: 0, decreased: 0 },
    ownership: { mapped: 0, removed: 0, decreased: 0 },
  });
});

test('dependency comparison rejects metadata changes and unresolved imports that do not resolve to the target', () => {
  const base = dependency(
    'src/admin/admin-audit.controller.ts',
    'src/auth/jwt-session.guard.ts',
    'context-backoffice-cross-context',
  );
  const invalidCandidates = [
    [{ ...base, dependencyTypes: ['local', 'type-only'] }],
    [{ ...base, unresolvedTo: '../auth/different-target' }],
    [{ ...base, unresolvedTo: '../../../outside-src' }],
  ];
  for (const candidateDependencies of invalidCandidates) {
    const fixture = makeFixture({
      baseDependencies: [base],
      candidateDependencies,
      baseOwnership: ownershipBaseline([]),
      candidateOwnership: ownershipBaseline([]),
    });
    writeFileSync(fixture.report, 'sentinel\n');
    const result = captureCli(fixture);
    assert.equal(result.exitCode, 2);
    assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');
  }
});

test('dependency resolver accepts canonical relative extension and index semantics', () => {
  const extension = dependency('src/admin/source.ts', 'src/auth/target.ts', 'context-backoffice-cross-context');
  extension.unresolvedTo = '../auth/target.ts';
  const index = dependency('src/admin/source.ts', 'src/auth/index.ts', 'context-backoffice-cross-context');
  index.unresolvedTo = '../auth';
  const emittedExtension = dependency(
    'src/admin/source.ts',
    'src/auth/target.ts',
    'context-backoffice-cross-context',
  );
  emittedExtension.unresolvedTo = '../auth/target.js';
  for (const legitimate of [extension, index, emittedExtension]) {
    const fixture = makeFixture({
      baseDependencies: [legitimate],
      candidateDependencies: [legitimate],
      baseOwnership: ownershipBaseline([]),
      candidateOwnership: ownershipBaseline([]),
    });
    assert.equal(captureCli(fixture).exitCode, 0);
  }
});

test('authorization vocabulary is pinned to the exact approved R1 relocation map', () => {
  const base = dependency('src/common/config/x.ts', 'src/auth/target.ts');
  const inventedRename = relocationMap({
    dependencyRuleRenames: [{
      from: 'current-platform-no-business-contexts',
      to: 'invented-platform-rule',
    }],
  });
  const inventedPrefix = relocationMap({
    dependencyPrefixes: [
      ...(approvedMap.dependencyPrefixes as unknown[]),
      { from: 'src/invented/', to: 'src/platform/invented/' },
    ],
  });
  const inventedOwnership = relocationMap({
    ownershipFilePrefixes: [
      ...(approvedMap.ownershipFilePrefixes as unknown[]),
      { from: 'backend/src/auth/', to: 'backend/src/platform/auth/' },
    ],
  });
  const fixtures = [
    makeFixture({
      baseDependencies: [base],
      candidateDependencies: [dependency('src/platform/config/x.ts', 'src/auth/target.ts', 'invented-platform-rule')],
      baseOwnership: ownershipBaseline([]), candidateOwnership: ownershipBaseline([]), map: inventedRename,
    }),
    makeFixture({
      baseDependencies: [dependency('src/invented/x.ts', 'src/auth/target.ts')],
      candidateDependencies: [dependency('src/platform/invented/x.ts', 'src/auth/target.ts', 'platform-no-business-contexts')],
      baseOwnership: ownershipBaseline([]), candidateOwnership: ownershipBaseline([]), map: inventedPrefix,
    }),
    makeFixture({
      baseDependencies: [], candidateDependencies: [],
      baseOwnership: ownershipBaseline([ownership('backend/src/auth/x.ts')]),
      candidateOwnership: ownershipBaseline([ownership('backend/src/platform/auth/x.ts')]), map: inventedOwnership,
    }),
  ];
  for (const fixture of fixtures) assert.equal(captureCli(fixture).exitCode, 2);
});

test('overlapping relocation source prefixes fail even when no record uses them', () => {
  const map = relocationMap({
    dependencyPrefixes: [
      ...(approvedMap.dependencyPrefixes as unknown[]),
      { from: 'src/common/', to: 'src/platform/common/' },
    ],
  });
  const fixture = makeFixture({
    baseDependencies: [], candidateDependencies: [],
    baseOwnership: ownershipBaseline([]), candidateOwnership: ownershipBaseline([]), map,
  });
  assert.equal(captureCli(fixture).exitCode, 2);
});

test('many-to-one dependency and ownership record collisions fail atomically', () => {
  const dependencyTarget = 'src/auth/target.ts';
  const dependencyFixture = makeFixture({
    baseDependencies: [
      dependency('src/common/filters/same.ts', dependencyTarget),
      dependency('src/common/http/same.ts', dependencyTarget),
    ],
    candidateDependencies: [dependency('src/platform/http/same.ts', dependencyTarget, 'platform-no-business-contexts')],
    baseOwnership: ownershipBaseline([]), candidateOwnership: ownershipBaseline([]),
  });
  const ownershipFixture = makeFixture({
    baseDependencies: [], candidateDependencies: [],
    baseOwnership: ownershipBaseline([
      ownership('backend/src/common/filters/same.ts'),
      ownership('backend/src/common/http/same.ts'),
    ]),
    candidateOwnership: ownershipBaseline([ownership('backend/src/platform/http/same.ts')]),
  });
  for (const fixture of [dependencyFixture, ownershipFixture]) {
    writeFileSync(fixture.report, 'sentinel\n');
    assert.equal(captureCli(fixture).exitCode, 2);
    assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');
  }
});

test('the exact immutable R1 base revision is required by direct and CLI verification', () => {
  const fixture = makeFixture();
  writeFileSync(fixture.report, 'sentinel\n');
  assert.throws(() => verifyRelocation({
    baseRevision: '0'.repeat(40),
    baseDependencies: fixture.baseDependencies,
    candidateDependencies: JSON.parse(readFileSync(fixture.dependencyCandidate, 'utf8')),
    baseOwnership: fixture.baseOwnership,
    candidateOwnership: JSON.parse(readFileSync(fixture.ownershipCandidate, 'utf8')),
    map: relocationMap(),
    candidateHashes: { dependency: '0'.repeat(64), ownership: '1'.repeat(64) },
  }));
  const argv = [
    '--verify', '--base-ref', '0'.repeat(40),
    '--dependency-candidate', fixture.dependencyCandidate,
    '--ownership-candidate', fixture.ownershipCandidate,
    '--map', 'architecture/r1-relocation-map.json',
    '--report', fixture.report,
  ];
  const result = captureCli(fixture, { argv });
  assert.equal(result.exitCode, 2);
  assert.deepEqual(result.stderr, ['ERROR - R1 baseline relocation verification failed']);
  assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');
});

test('candidate and report paths reject junction escapes and hardlink aliases atomically', () => {
  const fixture = makeFixture();
  const outside = ignoredBackendFixture('r1-relocation-outside-');
  const junction = path.join(fixture.root, 'junction');
  symlinkSync(outside, junction, 'junction');
  const escapedCandidate = path.join(junction, 'dependency.json');
  writeFileSync(path.join(outside, 'dependency.json'), readFileSync(fixture.dependencyCandidate));
  writeFileSync(fixture.report, 'sentinel\n');
  const escaped = captureCli(fixture, {
    argv: [
      '--verify', '--base-ref', baseRevision,
      '--dependency-candidate', escapedCandidate,
      '--ownership-candidate', fixture.ownershipCandidate,
      '--map', 'architecture/r1-relocation-map.json',
      '--report', fixture.report,
    ],
  });
  assert.equal(escaped.exitCode, 2);
  assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');

  rmSync(fixture.report, { force: true });
  linkSync(fixture.dependencyCandidate, fixture.report);
  const original = readFileSync(fixture.dependencyCandidate);
  const aliased = captureCli(fixture);
  assert.equal(aliased.exitCode, 2);
  assert.deepEqual(readFileSync(fixture.dependencyCandidate), original);
});

function assertAtomicCandidateReplacementRejected(candidateKind: 'dependency' | 'ownership') {
  const fixture = makeFixture();
  writeFileSync(fixture.report, 'sentinel\n');
  const target = candidateKind === 'dependency'
    ? fixture.dependencyCandidate
    : fixture.ownershipCandidate;
  const replacement = candidateKind === 'dependency' ? [] : ownershipBaseline([]);
  let replaced = false;
  const result = captureCli(fixture, {
    readBaseJson: (_revision: string, repositoryPath: string) => {
      if (!replaced) {
        replaceAtomically(target, replacement);
        replaced = true;
      }
      return repositoryPath === 'backend/.dependency-cruiser-known-violations.json'
        ? fixture.baseDependencies
        : fixture.baseOwnership;
    },
  });
  assert.equal(replaced, true);
  assert.equal(result.exitCode, 2);
  assert.deepEqual(result.stdout, []);
  assert.deepEqual(result.stderr, ['ERROR - R1 baseline relocation verification failed']);
  assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');
  assert.deepEqual(JSON.parse(readFileSync(target, 'utf8')), replacement);
}

test('candidate snapshots reject dependency atomic replacement before report write', () => {
  assertAtomicCandidateReplacementRejected('dependency');
});

test('candidate snapshots reject ownership atomic replacement before report write', () => {
  assertAtomicCandidateReplacementRejected('ownership');
});

test('candidate snapshot revalidation preserves an unchanged control', () => {
  const fixture = makeFixture();
  let baseReads = 0;
  const result = captureCli(fixture, {
    readBaseJson: (_revision: string, repositoryPath: string) => {
      baseReads += 1;
      return repositoryPath === 'backend/.dependency-cruiser-known-violations.json'
        ? fixture.baseDependencies
        : fixture.baseOwnership;
    },
  });
  assert.equal(baseReads, 2);
  assert.equal(result.exitCode, 0);
  assert.deepEqual(result.stderr, []);
  assert.equal(existsSync(fixture.report), true);
});

test('new dependency targets, undeclared rule changes, cycles, and unmatched additions fail atomically', () => {
  const invalidCandidates = [
    [dependency(
      'src/platform/config/runtime-environment.ts',
      'src/media/media-storage.service.ts',
      'platform-no-business-contexts',
    )],
    [dependency(
      'src/platform/config/runtime-environment.ts',
      'src/auth/jwt-session.guard.ts',
      'renamed-without-declaration',
    )],
    [{ type: 'cycle', from: 'src/a.ts', to: 'src/b.ts', rule: { severity: 'error', name: 'no-cycles' } }],
    [dependency(
      'src/platform/new-source.ts',
      'src/auth/jwt-session.guard.ts',
      'platform-no-business-contexts',
    )],
  ];
  for (const candidateDependencies of invalidCandidates) {
    const fixture = makeFixture({ candidateDependencies });
    writeFileSync(fixture.report, 'sentinel\n');
    const result = captureCli(fixture);
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['ERROR - R1 baseline relocation verification failed']);
    assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');
  }
});

test('ownership semantic changes, additions, and count increases fail atomically', () => {
  const relocated = ownership('backend/src/platform/config/runtime-environment.ts', 2);
  const invalidCandidates = [
    ownershipBaseline([{ ...relocated, model: 'WeddingPlan' }]),
    ownershipBaseline([ownership('backend/src/platform/new-source.ts', 1)]),
    ownershipBaseline([ownership('backend/src/platform/config/runtime-environment.ts', 3)]),
  ];
  for (const candidateOwnership of invalidCandidates) {
    const fixture = makeFixture({ candidateOwnership });
    writeFileSync(fixture.report, 'sentinel\n');
    const result = captureCli(fixture);
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['ERROR - R1 baseline relocation verification failed']);
    assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');
  }
});

test('malformed, duplicate, absolute, traversal, secret-bearing, sparse, accessor, and oversized data fails', () => {
  const sparse: unknown[] = [];
  sparse.length = 1;
  const accessor = {} as JsonObject;
  Object.defineProperty(accessor, 'schemaVersion', {
    enumerable: true,
    get() { throw new Error('TOKEN=accessor-secret'); },
  });
  const invalidInputs: Array<Partial<JsonObject>> = [
    { map: { ...relocationMap(), extra: true } },
    { map: relocationMap({ dependencyPrefixes: [
      { from: 'src/common/config/', to: 'src/platform/config/' },
      { from: 'src/common/config/', to: 'src/platform/other/' },
    ] }) },
    { candidateDependencies: [dependency('C:/private/source.ts', 'src/auth/x.ts')] },
    { candidateDependencies: [dependency('src/../private/source.ts', 'src/auth/x.ts')] },
    { candidateDependencies: [dependency('src/TOKEN=secret.ts', 'src/auth/x.ts')] },
    { candidateDependencies: sparse },
    { candidateDependencies: Array.from({ length: 10_001 }, (_, index) => dependency(
      `src/common/config/file-${index}.ts`,
      'src/auth/x.ts',
    )) },
  ];
  for (const invalid of invalidInputs) {
    const fixture = makeFixture(invalid as never);
    writeFileSync(fixture.report, 'sentinel\n');
    const result = captureCli(fixture);
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stderr, ['ERROR - R1 baseline relocation verification failed']);
    assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');
  }
});

test('direct verification rejects accessor and sparse values without invoking accessors', () => {
  let invoked = false;
  const accessor = {} as JsonObject;
  Object.defineProperty(accessor, 'schemaVersion', {
    enumerable: true,
    get() {
      invoked = true;
      return 1;
    },
  });
  const sparse: unknown[] = [];
  sparse.length = 1;
  assert.throws(() => verifyRelocation({
    baseRevision,
    baseDependencies: [],
    candidateDependencies: sparse,
    baseOwnership: ownershipBaseline([]),
    candidateOwnership: ownershipBaseline([]),
    map: relocationMap(),
    candidateHashes: { dependency: '0'.repeat(64), ownership: '1'.repeat(64) },
  }));
  assert.throws(() => verifyRelocation({
    baseRevision,
    baseDependencies: [],
    candidateDependencies: [],
    baseOwnership: ownershipBaseline([]),
    candidateOwnership: ownershipBaseline([]),
    map: accessor,
    candidateHashes: { dependency: '0'.repeat(64), ownership: '1'.repeat(64) },
  }));
  assert.equal(invoked, false);
});

test('invalid CLI arguments, relative candidate/report paths, and write failures return sanitized exit 2', () => {
  const fixture = makeFixture();
  const cases = [
    { argv: ['--verify'] },
    { argv: [
      '--verify', '--base-ref', baseRevision,
      '--dependency-candidate', 'relative.json',
      '--ownership-candidate', fixture.ownershipCandidate,
      '--map', 'architecture/r1-relocation-map.json',
      '--report', fixture.report,
    ] },
    { argv: [
      '--verify', '--base-ref', baseRevision,
      '--dependency-candidate', fixture.dependencyCandidate,
      '--ownership-candidate', fixture.ownershipCandidate,
      '--map', 'architecture/r1-relocation-map.json',
      '--report', 'relative.json',
    ] },
    { argv: [
      '--verify', '--base-ref', baseRevision,
      '--dependency-candidate', path.join(__dirname, 'dependency-candidate.json'),
      '--ownership-candidate', fixture.ownershipCandidate,
      '--map', 'architecture/r1-relocation-map.json',
      '--report', fixture.report,
    ] },
  ];
  for (const override of cases) {
    const result = captureCli(fixture, override);
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stderr, ['ERROR - R1 baseline relocation verification failed']);
  }

  writeFileSync(fixture.report, 'sentinel\n');
  const writeFailure = captureCli(fixture, {
    writeReport: () => { throw new Error('TOKEN=write-secret C:/private/report.json'); },
  });
  assert.equal(writeFailure.exitCode, 2);
  assert.deepEqual(writeFailure.stderr, ['ERROR - R1 baseline relocation verification failed']);
  assert.equal(readFileSync(fixture.report, 'utf8'), 'sentinel\n');
  assert.equal(existsSync(`${fixture.report}.tmp`), false);
});
