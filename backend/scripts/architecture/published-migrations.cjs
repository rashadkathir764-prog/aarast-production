#!/usr/bin/env node
'use strict';

const { createHash } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const PROVEN_REVISION = '6a6ce5c4a9a4d9b48db6e1eee4d4a7567385bd1b';
const LAST_PROVEN_MIGRATION = '20260811180000_backfill_missing_contributor_history_scopes';
const PROVEN_MIGRATION_COUNT = 76;
const PROVEN_DIGEST = 'cca53e470c17408f54a8f2e4bc397156bd1cd1de5066552e42212d9c51fa8d3e';

function assertProvenBaseline(manifestPath) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const entries = Object.entries(manifest.migrations || {})
    .filter(([name]) => name <= LAST_PROVEN_MIGRATION)
    .sort(([a], [b]) => a.localeCompare(b));
  const canonical = JSON.stringify({ lock: manifest.migrationLockSha256, entries });
  const actual = createHash('sha256').update(canonical).digest('hex');
  if (
    manifest.sourceRevision !== PROVEN_REVISION
    || entries.length !== PROVEN_MIGRATION_COUNT
    || actual !== PROVEN_DIGEST
  ) {
    throw new Error('proven migration baseline changed');
  }
}

function digest(file) {
  // Git's text=auto materializes CRLF in Windows worktrees and LF in CI.
  // Compare the canonical text bytes stored in Git, not platform checkout EOLs.
  const canonical = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
  return createHash('sha256').update(canonical).digest('hex');
}

function checkPublishedMigrations(migrationsRoot, manifestPath) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (
    manifest?.schemaVersion !== 1
    || !/^[0-9a-f]{40}$/.test(manifest.sourceRevision)
    || !/^[0-9a-f]{64}$/.test(manifest.migrationLockSha256)
    || !manifest.migrations
    || typeof manifest.migrations !== 'object'
    || Array.isArray(manifest.migrations)
  ) {
    throw new Error('invalid published migration manifest');
  }

  const pinned = Object.keys(manifest.migrations);
  if (pinned.length === 0) throw new Error('published migration manifest is empty');
  for (const name of pinned) {
    if (!/^\d{14}_[a-z0-9_]+$/.test(name) || !/^[0-9a-f]{64}$/.test(manifest.migrations[name])) {
      throw new Error(`invalid published migration record: ${name}`);
    }
    const folder = path.join(migrationsRoot, name);
    const file = path.join(folder, 'migration.sql');
    if (!fs.existsSync(folder) || !fs.statSync(folder).isDirectory() || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      throw new Error(`missing published migration: ${name}`);
    }
    if (digest(file) !== manifest.migrations[name]) {
      throw new Error(`modified published migration: ${name}`);
    }
  }

  for (const entry of fs.readdirSync(migrationsRoot, { withFileTypes: true })) {
    if (entry.isDirectory() && !Object.hasOwn(manifest.migrations, entry.name)) {
      throw new Error(`unpinned migration: ${entry.name}`);
    }
  }

  const lock = path.join(migrationsRoot, 'migration_lock.toml');
  if (!fs.existsSync(lock) || !fs.statSync(lock).isFile() || digest(lock) !== manifest.migrationLockSha256) {
    throw new Error('modified migration lock');
  }
  return { count: pinned.length };
}

if (require.main === module) {
  if (process.argv.length !== 3 || process.argv[2] !== '--check') {
    console.error('usage: published-migrations.cjs --check');
    process.exitCode = 2;
  } else {
    try {
      const backendRoot = path.resolve(__dirname, '..', '..');
      const manifestPath = path.join(backendRoot, 'architecture', 'published-migrations.json');
      assertProvenBaseline(manifestPath);
      const result = checkPublishedMigrations(
        path.join(backendRoot, 'prisma', 'migrations'),
        manifestPath,
      );
      console.log(`PASS - published migrations: pinned=${result.count}, modified=0, missing=0, unpinned=0`);
    } catch (error) {
      console.error(`FAIL - published migrations: ${error.message}`);
      process.exitCode = 1;
    }
  }
}

module.exports = { assertProvenBaseline, checkPublishedMigrations };
