import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  compareR9MobileDebt,
  scanR9MobileBoundaries,
  validateR9Manifest,
} from './check-mobile-boundaries.mjs';

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function canonicalRepositoryPath(value) {
  if (
    typeof value !== 'string'
    || value.length === 0
    || value.length > 512
    || value.includes('\\')
    || /[\u0000-\u001F\u007F-\u009F:=?*"<>|%]/.test(value)
    || path.posix.isAbsolute(value)
    || path.win32.isAbsolute(value)
    || path.posix.normalize(value) !== value
  ) return false;
  return value.split('/').every((segment) => (
    segment !== ''
    && segment !== '.'
    && segment !== '..'
    && /^[A-Za-z0-9_.@+$'{}-]+$/.test(segment)
  ));
}

function isInside(root, target) {
  const relative = path.relative(root, target);
  return relative === '' || (
    relative !== '..'
    && !relative.startsWith(`..${path.sep}`)
    && !path.isAbsolute(relative)
  );
}

function resolveExistingPath(target) {
  let current = target;
  const suffix = [];
  while (!fs.existsSync(current)) {
    const parent = path.dirname(current);
    if (parent === current) throw new Error('path does not exist');
    suffix.unshift(path.basename(current));
    current = parent;
  }
  return path.join(fs.realpathSync.native(current), ...suffix);
}

function runGit(repoRoot, args) {
  const result = spawnSync('git', ['-C', repoRoot, ...args], {
    encoding: 'utf8',
    windowsHide: true,
    maxBuffer: 4 * 1024 * 1024,
  });
  if (result.status !== 0 || result.error) throw new Error('git scope query failed');
  return result.stdout;
}

function gitChangedPaths(repoRoot, baseRevision) {
  runGit(repoRoot, ['cat-file', '-e', `${baseRevision}^{commit}`]);
  const tracked = runGit(repoRoot, [
    'diff', '--name-only', '--diff-filter=ACDMRTUXB', '-z', baseRevision, '--',
  ]).split('\0').filter(Boolean);
  const untracked = runGit(repoRoot, [
    'ls-files', '--others', '--exclude-standard', '-z', '--',
  ]).split('\0').filter(Boolean);
  return [...new Set([...tracked, ...untracked])].sort();
}

function defaultInputs(repoRoot, contract) {
  const readText = (repositoryPath) => fs.readFileSync(
    path.join(repoRoot, ...repositoryPath.split('/')),
    'utf8',
  );
  const baselineText = readText(contract.historicalBaseline.path);
  const mobileLib = path.join(repoRoot, 'mobile', 'lib');
  const scan = scanR9MobileBoundaries({ mobileLib, manifest: contract });
  return {
    changedPaths: gitChangedPaths(repoRoot, contract.baseRevision),
    baselineText,
    documentTexts: new Map(contract.documents.map((item) => [
      item.path,
      readText(item.path),
    ])),
    scan,
    comparison: compareR9MobileDebt({
      scan,
      baseline: JSON.parse(baselineText),
      manifest: contract,
    }),
  };
}

export function checkR9Scope({ repoRoot, task }, injected = {}) {
  const errors = [];
  let contract;
  try {
    const manifestValue = injected.manifest ?? JSON.parse(fs.readFileSync(
      path.join(repoRoot, 'scripts', 'architecture', 'r9-mobile-strict-manifest.json'),
      'utf8',
    ));
    contract = validateR9Manifest(manifestValue);
  } catch {
    return {
      ok: false,
      task: typeof task === 'string' ? task : '<invalid>',
      legacyViolationCount: 0,
      rootViolationCount: 0,
      changedPaths: [],
      errors: [{ kind: 'manifest-invalid' }],
    };
  }

  const expected = contract.expectedDebt[task];
  if (!expected) errors.push({ kind: 'unknown-task' });

  let inputs;
  try {
    inputs = Object.keys(injected).length > 0
      ? {
        ...injected,
        changedPaths: injected.changedPaths || [],
        documentTexts: injected.documentTexts || new Map(),
      }
      : defaultInputs(path.resolve(repoRoot), contract);
  } catch {
    return {
      ok: false,
      task: expected ? task : '<invalid>',
      legacyViolationCount: 0,
      rootViolationCount: 0,
      changedPaths: [],
      errors: [...errors, { kind: 'scope-input-failure' }],
    };
  }

  const allowed = new Set(contract.allowedChangedPaths);
  const safeChangedPaths = [];
  let realRepoRoot;
  try {
    realRepoRoot = fs.realpathSync.native(path.resolve(repoRoot));
  } catch {
    errors.push({ kind: 'repository-root-invalid' });
  }
  for (const changedPath of inputs.changedPaths) {
    if (!canonicalRepositoryPath(changedPath) || !allowed.has(changedPath)) {
      errors.push({ kind: 'unapproved-changed-path' });
      continue;
    }
    safeChangedPaths.push(changedPath);
    if (realRepoRoot) {
      try {
        const resolved = resolveExistingPath(path.join(
          path.resolve(repoRoot),
          ...changedPath.split('/'),
        ));
        if (!isInside(realRepoRoot, resolved)) {
          errors.push({ kind: 'changed-path-escape', path: changedPath });
        }
      } catch {
        errors.push({ kind: 'changed-path-resolution-failure', path: changedPath });
      }
    }
  }

  try {
    const baseline = JSON.parse(inputs.baselineText);
    if (
      sha256(inputs.baselineText) !== contract.historicalBaseline.sha256
      || baseline.sourceRevision !== contract.historicalBaseline.sourceRevision
      || !Array.isArray(baseline.records)
      || baseline.records.length !== contract.historicalBaseline.recordCount
    ) errors.push({ kind: 'historical-baseline-mismatch' });
  } catch {
    errors.push({ kind: 'historical-baseline-mismatch' });
  }

  for (const document of contract.documents) {
    const text = inputs.documentTexts.get(document.path);
    if (typeof text !== 'string' || sha256(text) !== document.sha256) {
      errors.push({ kind: 'document-hash-mismatch', path: document.path });
    }
  }

  const scan = inputs.scan || {
    errors: [], legacyRecords: [], rootRecords: [], legalRecords: [], strictViolations: [],
  };
  const comparison = inputs.comparison || compareR9MobileDebt({
    scan,
    baseline: JSON.parse(inputs.baselineText),
    manifest: contract,
  });
  if (scan.errors.length > 0) errors.push({ kind: 'mobile-boundary-structural-error' });
  if (!comparison.ok || comparison.additions.length > 0) {
    errors.push({ kind: 'mobile-boundary-debt-addition' });
  }
  if (
    expected
    && (
      comparison.legacyViolationCount !== expected.legacy
      || comparison.rootViolationCount !== expected.root
    )
  ) errors.push({ kind: 'milestone-mismatch' });
  if (
    expected?.legacy === 0
    && expected.root === 0
    && (
      !Array.isArray(scan.legalRecords)
      || scan.legalRecords.length !== contract.finalLegalRecordCount
    )
  ) errors.push({ kind: 'legal-record-count-mismatch' });

  const uniqueErrors = [];
  const errorKeys = new Set();
  for (const error of errors) {
    const key = `${error.kind}|${error.path || ''}`;
    if (!errorKeys.has(key)) {
      errorKeys.add(key);
      uniqueErrors.push(error);
    }
  }
  uniqueErrors.sort((left, right) => (
    `${left.kind}|${left.path || ''}`.localeCompare(`${right.kind}|${right.path || ''}`, 'en')
  ));
  return {
    ok: uniqueErrors.length === 0,
    task: expected ? task : '<invalid>',
    legacyViolationCount: comparison.legacyViolationCount,
    rootViolationCount: comparison.rootViolationCount,
    changedPaths: [...new Set(safeChangedPaths)].sort(),
    errors: uniqueErrors,
  };
}

function runCli(argv) {
  if (argv.length !== 2 || argv[0] !== '--check') {
    process.stderr.write('usage: check-r9-scope.mjs --check task-N\n');
    return 2;
  }
  const scriptFile = fileURLToPath(import.meta.url);
  const repoRoot = path.resolve(path.dirname(scriptFile), '..');
  const result = checkR9Scope({ repoRoot, task: argv[1] });
  if (result.ok) {
    process.stdout.write(
      `R9 scope check passed (${result.task}: legacy=${result.legacyViolationCount}, root=${result.rootViolationCount})\n`,
    );
    return 0;
  }
  process.stderr.write(`R9 scope check failed (${result.errors.length} categories)\n`);
  for (const error of result.errors) {
    process.stderr.write(`${error.kind}${error.path ? `: ${error.path}` : ''}\n`);
  }
  return 1;
}

const invokedDirectly = process.argv[1]
  && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) process.exitCode = runCli(process.argv.slice(2));
