#!/usr/bin/env node
'use strict';

const { spawnSync } = require('child_process');
const { createHash } = require('crypto');
const { existsSync, lstatSync, readFileSync, readlinkSync } = require('fs');
const { resolve } = require('path');

const repositoryRoot = resolve(__dirname, '..', '..', '..');
const phase0PostgresSupport =
  'backend/test/support/phase0-postgres-support.js';

function git(args) {
  const result = spawnSync('git', args, {
    cwd: repositoryRoot,
    encoding: 'utf8',
    shell: false,
    windowsHide: true,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`git ${args.join(' ')} failed: ${result.stderr.trim()}`);
  }
  return result.stdout;
}

function isProtectedTestArtifactPath(filePath) {
  const normalizedPath = filePath.replace(/\\/g, '/');
  return (
    normalizedPath !== 'backend/scripts/smoke/phase0-fixtures-smoke.js' &&
    /(?:^|[\/._-])(?:fixtures?|goldens?)(?:[\/._-]|$)/i.test(normalizedPath)
  );
}

function gitFilePaths(args = [], runGit = git) {
  return runGit(['ls-files', '-z', ...args])
    .split('\0')
    .filter(Boolean);
}

function protectedTestArtifacts() {
  const trackedFixtures = gitFilePaths()
    .filter(isProtectedTestArtifactPath);
  return ['mobile/test/goldens', phase0PostgresSupport, ...trackedFixtures];
}

function protectedArtifactFilePaths() {
  const repositoryFiles = gitFilePaths([
    '--cached',
    '--others',
    '--exclude-standard',
  ]);
  return [
    ...new Set([
      phase0PostgresSupport,
      ...repositoryFiles.filter(isProtectedTestArtifactPath),
    ]),
  ].sort();
}

function artifactFingerprint(filePath) {
  const absolutePath = resolve(repositoryRoot, filePath);
  if (!existsSync(absolutePath)) return 'missing';
  const stat = lstatSync(absolutePath);
  if (stat.isSymbolicLink()) {
    return `symlink:${readlinkSync(absolutePath)}`;
  }
  if (!stat.isFile()) return `unsupported:${stat.mode}`;
  return createHash('sha256').update(readFileSync(absolutePath)).digest('hex');
}

function captureProtectedArtifactSnapshot() {
  return Object.fromEntries(
    protectedArtifactFilePaths().map((filePath) => [
      filePath,
      artifactFingerprint(filePath),
    ]),
  );
}

function changedProtectedArtifactSnapshots(before, after) {
  const paths = new Set([...Object.keys(before), ...Object.keys(after)]);
  return [...paths]
    .filter((filePath) => before[filePath] !== after[filePath])
    .sort();
}

function assertProtectedArtifactsUnchanged(before) {
  const changed = changedProtectedArtifactSnapshots(
    before,
    captureProtectedArtifactSnapshot(),
  );
  if (changed.length > 0) {
    throw new Error(
      `Phase 0 test cleanliness failed: ${changed.length} protected artifact(s) changed during the test run.`,
    );
  }
}

function main() {
  const artifacts = protectedTestArtifacts();
  const changes = git(['status', '--porcelain=v1', '--', ...artifacts]).trim();
  if (changes) {
    throw new Error(
      'Phase 0 test cleanliness failed: protected goldens or tracked fixtures changed.',
    );
  }
  console.log('PASS - Phase 0 git cleanliness: protected goldens and tracked fixtures are unchanged.');
}

if (require.main === module) main();

module.exports = {
  assertProtectedArtifactsUnchanged,
  captureProtectedArtifactSnapshot,
  changedProtectedArtifactSnapshots,
  gitFilePaths,
  isProtectedTestArtifactPath,
  protectedArtifactFilePaths,
  protectedTestArtifacts,
};
