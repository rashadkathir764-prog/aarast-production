import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateR9Manifest } from './check-mobile-boundaries.mjs';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..');
const manifestPath = path.join(scriptDir, 'architecture', 'r9-mobile-strict-manifest.json');
const baselinePath = path.join(scriptDir, 'architecture', 'mobile-boundaries-baseline.json');
const validatorPath = path.join(scriptDir, 'check-mobile-boundaries.mjs');
const workflowPath = path.join(repoRoot, '.github', 'workflows', 'ci.yml');
const designPath = 'docs/superpowers/specs/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-design.md';
const planPath = 'docs/superpowers/plans/2026-08-28-modular-monolith-r9-mobile-strict-boundaries.md';
const designSha256 = '45f732498afda4fd0ba7861eb0aff75c31580cc14d20c810a655f3857174c5f5';
const planSha256 = '228631ce793ecc189ea7b5d007f8e573b19ecbeea5fd9bad67a6ce1f6c737060';
const c2AllowedPathPositions = Object.freeze([
  [
    'mobile/lib/core/storage/auth_storage.dart',
    'mobile/lib/core/utils/money_formatters.dart',
    'mobile/lib/features/account_contexts/account_contexts_api.dart',
    'mobile/lib/core/utils/money_formatter.dart',
  ],
  [
    'mobile/lib/features/finance/finance_api.dart',
    'mobile/lib/features/finance/models/money_formatters.dart',
    'mobile/lib/features/finance/models/money_starter_catalog.dart',
    'mobile/lib/features/finance/models/money_formatter.dart',
  ],
  [
    'mobile/lib/features/finance/widgets/finance_write_access_block.dart',
    'mobile/lib/features/finance/widgets/money_widgets.dart',
    'mobile/lib/features/guests/guests_api.dart',
    'mobile/lib/features/finance/widgets/money_widget.dart',
  ],
  [
    'mobile/test/features/chat/chat_realtime_client_test.dart',
    'mobile/test/features/finance/money_summary_contract_test.dart',
    'mobile/test/features/marketplace/city_filter_picker_test.dart',
    'mobile/test/features/finance/money_summaries_contract_test.dart',
  ],
]);
const expectedDebt = Object.freeze({
  'task-1': { legacy: 269, root: 34 },
  'task-2': { legacy: 265, root: 34 },
  'task-3': { legacy: 265, root: 34 },
  'task-4': { legacy: 255, root: 34 },
  'task-5': { legacy: 198, root: 34 },
  'task-6': { legacy: 119, root: 34 },
  'task-7': { legacy: 59, root: 34 },
  'task-8': { legacy: 0, root: 0 },
  'task-9': { legacy: 0, root: 0 },
  'task-10': { legacy: 0, root: 0 },
  'task-11': { legacy: 0, root: 0 },
});

let scopeModule;
try {
  scopeModule = await import('./check-r9-scope.mjs');
} catch {
  scopeModule = {};
}

function manifestValue() {
  return JSON.parse(readFileSync(manifestPath, 'utf8'));
}

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

function mobileJobText(workflowText) {
  const lines = String(workflowText).split(/\r?\n/);
  const start = lines.findIndex((line) => line === '  mobile:');
  assert.notEqual(start, -1, 'missing Mobile CI job');
  const relativeEnd = lines.slice(start + 1).findIndex((line) => (
    /^  [A-Za-z0-9_-]+:\s*$/.test(line)
  ));
  const end = relativeEnd === -1 ? lines.length : start + 1 + relativeEnd;
  return lines.slice(start, end).join('\n');
}

function assertMobileBoundaryCiContract(workflowText) {
  const mobileJob = mobileJobText(workflowText);
  assert.match(
    mobileJob,
    /^  mobile:\n(?:.|\n)*?    defaults:\n      run:\n        working-directory: mobile(?:\n|$)/,
  );
  const boundaryCommands = mobileJob.split('\n').filter((line) => (
    line.includes('check-mobile-boundaries.mjs')
    && !line.includes('check-mobile-boundaries.test.mjs')
  ));
  assert.equal(boundaryCommands.length, 1, 'expected one Mobile boundary command');
  assert.match(
    boundaryCommands[0],
    /^      - run: node \.\.\/scripts\/check-mobile-boundaries\.mjs --(?:check-baseline|strict)$/,
  );
  assert.doesNotMatch(
    mobileJob,
    /node scripts\/check-mobile-boundaries\.mjs/,
  );
}

function validDependencies(overrides = {}) {
  const manifest = validateR9Manifest(manifestValue());
  return {
    manifest,
    changedPaths: [
      designPath,
      planPath,
      'scripts/architecture/r9-mobile-strict-manifest.json',
      'scripts/check-mobile-boundaries.mjs',
      'scripts/check-mobile-boundaries.test.mjs',
      'scripts/check-r9-scope.mjs',
      'scripts/check-r9-scope.test.mjs',
    ],
    baselineText: readFileSync(baselinePath, 'utf8'),
    documentTexts: new Map(manifest.documents.map((item) => [
      item.path,
      readFileSync(path.join(repoRoot, ...item.path.split('/')), 'utf8'),
    ])),
    scan: {
      errors: [],
      legacyRecords: Array.from({ length: 269 }, (_, index) => ({ index })),
      rootRecords: Array.from({ length: 34 }, (_, index) => ({ index })),
      legalRecords: [],
      strictViolations: [],
    },
    comparison: {
      ok: true,
      additions: [],
      legacyViolationCount: 269,
      rootViolationCount: 34,
    },
    ...overrides,
  };
}

function runCheck(task = 'task-1', overrides = {}) {
  assert.equal(typeof scopeModule.checkR9Scope, 'function');
  return scopeModule.checkR9Scope(
    { repoRoot, task },
    validDependencies(overrides),
  );
}

function scanWithLegalCount(count) {
  return {
    ...validDependencies().scan,
    legalRecords: Array.from({ length: count }, (_, index) => ({ index })),
  };
}

test('tracked R9 manifest freezes exact identities inventories milestones and sorted fence', () => {
  const raw = manifestValue();
  const manifest = validateR9Manifest(raw);
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.baseRevision, '833a4f1d31781b45cd0a68ecee1b969ac85f237f');
  assert.deepEqual(manifest.historicalBaseline, {
    path: 'scripts/architecture/mobile-boundaries-baseline.json',
    sourceRevision: 'feafe3db0053d6c66d5f46b56ff9a512861dfbad',
    sha256: 'f9939fa25b7e3e3b7e3563c4dce30aa9a2cb0781cdf2ed8bbf9448477644cf1f',
    recordCount: 269,
  });
  assert.equal(manifest.rootInventory.recordCount, 34);
  assert.equal(manifest.rootInventory.canonicalSha256, '1cf2239bdf339b12fa76abfa3dd90ef9bbf2dd39a0778f2af9385f2e4e28848b');
  assert.equal(manifest.rootInventory.records.length, 34);
  assert.equal(manifest.featureApis.length, 19);
  assert.equal(manifest.allowedChangedPaths.length, 151);
  assert.deepEqual(manifest.allowedChangedPaths, [...manifest.allowedChangedPaths].sort());
  assert.equal(new Set(manifest.allowedChangedPaths).size, 151);
  const apiClientPath = 'mobile/lib/core/network/api_client.dart';
  assert.equal(
    manifest.allowedChangedPaths.filter((itemPath) => itemPath === apiClientPath).length,
    1,
  );
  const apiClientIndex = manifest.allowedChangedPaths.indexOf(apiClientPath);
  assert.deepEqual(manifest.allowedChangedPaths.slice(apiClientIndex - 1, apiClientIndex + 2), [
    'mobile/lib/app.dart',
    apiClientPath,
    'mobile/lib/core/offline/offline_sync_service.dart',
  ]);
  for (const [previousPath, c2Path, nextPath] of c2AllowedPathPositions) {
    assert.equal(
      manifest.allowedChangedPaths.filter((itemPath) => itemPath === c2Path).length,
      1,
      c2Path,
    );
    const c2Index = manifest.allowedChangedPaths.indexOf(c2Path);
    assert.deepEqual(
      manifest.allowedChangedPaths.slice(c2Index - 1, c2Index + 2),
      [previousPath, c2Path, nextPath],
      c2Path,
    );
  }
  assert.deepEqual(manifest.expectedDebt, expectedDebt);
  assert.deepEqual(manifest.compositionSources, [
    'mobile/lib/app.dart',
    'mobile/lib/core/routing/app_router.dart',
    'mobile/lib/main.dart',
  ]);
  assert.equal(manifest.finalLegalRecordCount, 159);
  assert.deepEqual(manifest.documents.map(({ path: itemPath }) => itemPath), [designPath, planPath]);
  assert.equal(manifest.documents[0].sha256, designSha256);
  assert.equal(manifest.documents[1].sha256, planSha256);
  assert.equal(sha256(readFileSync(path.join(repoRoot, ...planPath.split('/')), 'utf8')), planSha256);
  assert.match(
    readFileSync(validatorPath, 'utf8'),
    new RegExp(`sha256: '${planSha256}'`),
  );
  assert.doesNotMatch(JSON.stringify(raw), /[A-Za-z]:[\\/]|(?:PASSWORD|SECRET|TOKEN)\s*=|\.\.[\\/]/i);
});

test('Mobile CI keeps its working directory and exact parent boundary path', () => {
  const workflowText = readFileSync(workflowPath, 'utf8');
  assert.doesNotThrow(() => assertMobileBoundaryCiContract(workflowText));
  assert.doesNotThrow(() => assertMobileBoundaryCiContract(
    workflowText.replace('--check-baseline', '--strict'),
  ));
  assert.throws(() => assertMobileBoundaryCiContract(
    workflowText.replace('working-directory: mobile', 'working-directory: .'),
  ));
  assert.throws(() => assertMobileBoundaryCiContract(
    workflowText.replace(
      'node ../scripts/check-mobile-boundaries.mjs',
      'node scripts/check-mobile-boundaries.mjs',
    ),
  ));
  assert.throws(() => assertMobileBoundaryCiContract(
    workflowText.replace('--check-baseline', '--write-baseline'),
  ));
});

test('manifest validation rejects wrong base hash count order duplicates and unsafe paths', () => {
  const original = manifestValue();
  const clones = [
    { ...original, baseRevision: '0'.repeat(40) },
    { ...original, historicalBaseline: { ...original.historicalBaseline, sha256: '0'.repeat(64) } },
    { ...original, rootInventory: { ...original.rootInventory, recordCount: 33 } },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths].reverse() },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths.slice(0, -1), original.allowedChangedPaths[0]] },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths.slice(0, -1), 'C:/secret.txt'].sort() },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths.slice(0, -1), '../secret.txt'].sort() },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths.slice(0, -1), 'scripts\\check-r9-scope.mjs'].sort() },
  ];
  for (const value of clones) assert.throws(() => validateR9Manifest(value));
});

test('manifest validation rejects a substituted root inventory record', () => {
  const original = manifestValue();
  const records = structuredClone(original.rootInventory.records);
  records[0].target = 'mobile/lib/features/account_contexts/providers/account_context_controllez.dart';
  assert.throws(() => validateR9Manifest({
    ...original,
    rootInventory: { ...original.rootInventory, records },
  }));
});

test('manifest validation rejects a canonical but unapproved fence substitution', () => {
  const original = manifestValue();
  const paths = [...original.allowedChangedPaths];
  paths[paths.indexOf('mobile/lib/app.dart')] = 'mobile/lib/appx.dart';
  paths.sort();
  assert.throws(() => validateR9Manifest({ ...original, allowedChangedPaths: paths }));
});

test('manifest validation rejects removing or substituting the formatter prerequisite', () => {
  const original = manifestValue();
  const apiClientPath = 'mobile/lib/core/network/api_client.dart';
  const apiClientIndex = original.allowedChangedPaths.indexOf(apiClientPath);
  assert.notEqual(apiClientIndex, -1);

  const removed = [...original.allowedChangedPaths];
  removed.splice(apiClientIndex, 1);
  assert.throws(() => validateR9Manifest({ ...original, allowedChangedPaths: removed }));

  const substituted = [...original.allowedChangedPaths];
  substituted[apiClientIndex] = 'mobile/lib/core/network/api_clientx.dart';
  substituted.sort();
  assert.throws(() => validateR9Manifest({ ...original, allowedChangedPaths: substituted }));
});

test('manifest validation rejects removing or canonically substituting every C2 formatter path', () => {
  const original = manifestValue();
  for (const [, c2Path, , nearMiss] of c2AllowedPathPositions) {
    const c2Index = original.allowedChangedPaths.indexOf(c2Path);
    assert.notEqual(c2Index, -1, c2Path);

    const removed = [...original.allowedChangedPaths];
    removed.splice(c2Index, 1);
    assert.throws(
      () => validateR9Manifest({ ...original, allowedChangedPaths: removed }),
      c2Path,
    );

    const substituted = [...original.allowedChangedPaths];
    substituted[c2Index] = nearMiss;
    substituted.sort();
    assert.throws(
      () => validateR9Manifest({ ...original, allowedChangedPaths: substituted }),
      c2Path,
    );
  }
});

test('scope rejects unknown tasks and unapproved separator case and traversal near-misses', () => {
  assert.equal(runCheck('task-12').ok, false);
  for (const changedPath of [
    'README.md',
    'scripts\\check-r9-scope.mjs',
    'Scripts/check-r9-scope.mjs',
    '../scripts/check-r9-scope.mjs',
    'C:/scripts/check-r9-scope.mjs',
  ]) {
    const result = runCheck('task-1', { changedPaths: [changedPath] });
    assert.equal(result.ok, false, changedPath);
    assert.ok(result.errors.some(({ kind }) => kind === 'unapproved-changed-path'));
  }
});

test('scope rejects a changed historical baseline and document hash mismatch', () => {
  const baselineResult = runCheck('task-1', {
    changedPaths: ['scripts/architecture/mobile-boundaries-baseline.json'],
    baselineText: '{}\n',
  });
  assert.equal(baselineResult.ok, false);
  assert.ok(baselineResult.errors.some(({ kind }) => kind === 'historical-baseline-mismatch'));

  const documents = validDependencies().documentTexts;
  documents.set(planPath, `${documents.get(planPath)}\nchanged`);
  const documentResult = runCheck('task-1', { documentTexts: documents });
  assert.equal(documentResult.ok, false);
  assert.ok(documentResult.errors.some(({ kind }) => kind === 'document-hash-mismatch'));
});

test('scope rejects every wrong milestone and accepts every exact milestone', () => {
  for (const [task, debt] of Object.entries(expectedDebt)) {
    const finalMilestone = debt.legacy === 0 && debt.root === 0;
    const exact = runCheck(task, {
      scan: scanWithLegalCount(finalMilestone ? 159 : 0),
      comparison: {
        ok: true,
        additions: [],
        legacyViolationCount: debt.legacy,
        rootViolationCount: debt.root,
      },
    });
    assert.equal(exact.ok, true, task);
    const wrong = runCheck(task, {
      comparison: {
        ok: true,
        additions: [],
        legacyViolationCount: debt.legacy + 1,
        rootViolationCount: debt.root,
      },
    });
    assert.equal(wrong.ok, false, task);
    assert.ok(wrong.errors.some(({ kind }) => kind === 'milestone-mismatch'));
  }
});

test('final zero-debt milestones require the exact frozen legal projection', () => {
  const finalComparison = {
    ok: true,
    additions: [],
    legacyViolationCount: 0,
    rootViolationCount: 0,
  };
  for (const task of ['task-8', 'task-9', 'task-10', 'task-11']) {
    for (const legalCount of [0, 158, 160]) {
      const result = runCheck(task, {
        scan: scanWithLegalCount(legalCount),
        comparison: finalComparison,
      });
      assert.equal(result.ok, false, `${task} legal=${legalCount}`);
      assert.ok(
        result.errors.some(({ kind }) => kind === 'legal-record-count-mismatch'),
        `${task} legal=${legalCount}`,
      );
    }

    assert.equal(runCheck(task, {
      scan: scanWithLegalCount(159),
      comparison: finalComparison,
    }).ok, true, task);
  }

  assert.equal(runCheck('task-7', {
    scan: scanWithLegalCount(0),
    comparison: {
      ...finalComparison,
      legacyViolationCount: 59,
      rootViolationCount: 34,
    },
  }).ok, true);
});

test('scope rejects a symlink or junction escape without disclosing its absolute target', () => {
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'aarast-r9-scope-'));
  const outside = mkdtempSync(path.join(os.tmpdir(), 'aarast-r9-outside-'));
  try {
    mkdirSync(path.join(fixture, 'mobile', 'lib', 'core'), { recursive: true });
    writeFileSync(path.join(outside, 'safe_user.dart'), '', 'utf8');
    symlinkSync(outside, path.join(fixture, 'mobile', 'lib', 'core', 'session'), process.platform === 'win32' ? 'junction' : 'dir');
    const result = scopeModule.checkR9Scope(
      { repoRoot: fixture, task: 'task-1' },
      validDependencies({ changedPaths: ['mobile/lib/core/session/safe_user.dart'] }),
    );
    assert.equal(result.ok, false);
    assert.ok(result.errors.some(({ kind }) => kind === 'changed-path-escape'));
    assert.doesNotMatch(JSON.stringify(result), new RegExp(outside.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'));
  } finally {
    rmSync(fixture, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});

test('scope receipt exposes only sanitized categories counts and repository paths', () => {
  const result = runCheck();
  assert.equal(result.ok, true);
  assert.equal(result.legacyViolationCount, 269);
  assert.equal(result.rootViolationCount, 34);
  assert.deepEqual(result.errors, []);
  assert.doesNotMatch(JSON.stringify(result), /[A-Za-z]:[\\/]|aarast-modular-monolith|(?:PASSWORD|SECRET|TOKEN)\s*=/i);
  for (const document of validDependencies().manifest.documents) {
    assert.equal(sha256(validDependencies().documentTexts.get(document.path)), document.sha256);
  }
});
