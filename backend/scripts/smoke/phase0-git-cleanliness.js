#!/usr/bin/env node
'use strict';

const { spawnSync } = require('child_process');
const { resolve } = require('path');

const repositoryRoot = resolve(__dirname, '..', '..', '..');

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

function protectedTestArtifacts() {
  const trackedFixtures = git(['ls-files', 'mobile/test', 'backend/test'])
    .split(/\r?\n/)
    .filter(Boolean)
    .filter((filePath) => /(?:^|\/)(?:fixtures?|goldens?)(?:\/|$)/i.test(filePath));
  return ['mobile/test/goldens', ...trackedFixtures];
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

module.exports = { protectedTestArtifacts };
