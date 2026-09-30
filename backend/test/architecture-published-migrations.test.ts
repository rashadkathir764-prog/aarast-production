import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const { assertProvenBaseline, checkPublishedMigrations } = require('../scripts/architecture/published-migrations.cjs') as {
  assertProvenBaseline: (manifestPath: string) => void;
  checkPublishedMigrations: (migrationsRoot: string, manifestPath: string) => { count: number };
};

const backendRoot = path.resolve(__dirname, '..');
const hash = (text: string) => createHash('sha256').update(text).digest('hex');

test('the proven migration history is pinned without depending on branch or checkout path', () => {
  const manifestPath = path.join(backendRoot, 'architecture', 'published-migrations.json');
  assertProvenBaseline(manifestPath);
  const result = checkPublishedMigrations(
    path.join(backendRoot, 'prisma', 'migrations'),
    manifestPath,
  );
  assert.ok(result.count >= 76);
});

test('regenerating the manifest cannot hide an edit to one of the proven 76 migrations', () => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'aarast-published-manifest-'));
  try {
    const manifest = JSON.parse(readFileSync(
      path.join(backendRoot, 'architecture', 'published-migrations.json'), 'utf8',
    ));
    const first = Object.keys(manifest.migrations)[0];
    manifest.migrations[first] = hash('tampered migration');
    const manifestPath = path.join(root, 'published-migrations.json');
    writeFileSync(manifestPath, JSON.stringify(manifest));
    assert.throws(() => assertProvenBaseline(manifestPath), /proven migration baseline changed/u);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('a changed, removed, or unpinned migration cannot pass the history gate', () => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'aarast-published-migrations-'));
  try {
    const migrationsRoot = path.join(root, 'migrations');
    const migrationName = '20260101000000_initial';
    const migrationRoot = path.join(migrationsRoot, migrationName);
    const migrationPath = path.join(migrationRoot, 'migration.sql');
    const lockPath = path.join(migrationsRoot, 'migration_lock.toml');
    const manifestPath = path.join(root, 'published-migrations.json');
    const sql = 'CREATE TABLE "Proof" ("id" TEXT PRIMARY KEY);\n';
    const lock = 'provider = "postgresql"\n';
    mkdirSync(migrationRoot, { recursive: true });
    writeFileSync(migrationPath, sql);
    writeFileSync(lockPath, lock);
    writeFileSync(manifestPath, JSON.stringify({
      schemaVersion: 1,
      sourceRevision: '6a6ce5c4a9a4d9b48db6e1eee4d4a7567385bd1b',
      migrationLockSha256: hash(lock),
      migrations: { [migrationName]: hash(sql) },
    }));

    assert.equal(checkPublishedMigrations(migrationsRoot, manifestPath).count, 1);
    writeFileSync(migrationPath, `${sql}-- historical edit\n`);
    assert.throws(() => checkPublishedMigrations(migrationsRoot, manifestPath), /modified published migration/u);
    writeFileSync(migrationPath, sql);

    const extra = path.join(migrationsRoot, '20260102000000_new');
    mkdirSync(extra);
    writeFileSync(path.join(extra, 'migration.sql'), 'SELECT 1;\n');
    assert.throws(() => checkPublishedMigrations(migrationsRoot, manifestPath), /unpinned migration/u);
    rmSync(extra, { recursive: true });

    rmSync(migrationPath);
    assert.throws(() => checkPublishedMigrations(migrationsRoot, manifestPath), /missing published migration/u);
    writeFileSync(migrationPath, sql);
    writeFileSync(lockPath, `${lock}# changed\n`);
    assert.throws(() => checkPublishedMigrations(migrationsRoot, manifestPath), /modified migration lock/u);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Git LF and Windows CRLF checkouts of the same migration have one canonical digest', () => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'aarast-migration-eol-'));
  try {
    const migrationsRoot = path.join(root, 'migrations');
    const migrationName = '20260101000000_initial';
    const migrationRoot = path.join(migrationsRoot, migrationName);
    const manifestPath = path.join(root, 'published-migrations.json');
    const sql = 'CREATE TABLE "Proof" (\n  "id" TEXT PRIMARY KEY\n);\n';
    const lock = 'provider = "postgresql"\n';
    mkdirSync(migrationRoot, { recursive: true });
    writeFileSync(path.join(migrationRoot, 'migration.sql'), sql.replace(/\n/g, '\r\n'));
    writeFileSync(path.join(migrationsRoot, 'migration_lock.toml'), lock.replace(/\n/g, '\r\n'));
    writeFileSync(manifestPath, JSON.stringify({
      schemaVersion: 1,
      sourceRevision: '6a6ce5c4a9a4d9b48db6e1eee4d4a7567385bd1b',
      migrationLockSha256: hash(lock),
      migrations: { [migrationName]: hash(sql) },
    }));
    assert.equal(checkPublishedMigrations(migrationsRoot, manifestPath).count, 1);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
