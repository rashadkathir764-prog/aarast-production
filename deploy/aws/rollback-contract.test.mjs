import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { test } from 'node:test';

// RA-BE-146: rollback.sh used to say «the migrations only add» and put the old
// code on a database the newer release had already changed, whatever the
// change was. It now reads what the database has that the target release does
// not know, says so, and refuses when any of it takes something away.
// No Docker: a fake `docker` serves the two images' migration files.
const root = resolve(import.meta.dirname, '../..');
const lib = join(root, 'deploy/aws/host/release-lib.sh');
const rollback = readFileSync(join(root, 'deploy/aws/host/rollback.sh'), 'utf8');
const migrations = join(root, 'backend/prisma/migrations');

const adds = `ALTER TABLE "User" ADD COLUMN "nickname" TEXT;\nCREATE TABLE "Note" ("id" TEXT NOT NULL, CONSTRAINT "Note_pkey" PRIMARY KEY ("id"));\nCREATE INDEX "Note_id_idx" ON "Note"("id");\n`;

// The host has python3. A Windows checkout's python3 can be the Store's
// placeholder, so there the fake bin and the direct run use the real python.
const python = process.platform === 'win32' ? 'python' : 'python3';
// An image tag holds a colon, which a Windows folder name cannot: the fake
// docker keeps each image under its tag with the colon written as «_».
const imageDir = (image) => image.replace(/:/g, '_');

function check({ target, current, applied }) {
  const dir = mkdtempSync(join(tmpdir(), 'aarast-rollback-'));
  try {
    mkdirSync(join(dir, 'bin'));
    if (process.platform === 'win32') {
      // Windows python ends its lines with CRLF; the host's python3 does not.
      writeFileSync(join(dir, 'bin', 'python3'), '#!/bin/bash\npython "$@" | tr -d \'\\r\'\nexit "${PIPESTATUS[0]}"\n');
      chmodSync(join(dir, 'bin', 'python3'), 0o755);
    }
    for (const [image, files] of Object.entries({ 'aarast-backend:old': target, 'aarast-backend:new': current })) {
      for (const [name, sql] of Object.entries(files)) {
        const path = join(dir, 'images', imageDir(image), 'prisma/migrations', name, 'migration.sql');
        mkdirSync(dirname(path), { recursive: true });
        writeFileSync(path, sql);
      }
      mkdirSync(join(dir, 'images', imageDir(image), 'prisma/migrations'), { recursive: true });
    }
    writeFileSync(join(dir, 'bin', 'docker'), `#!/bin/bash
# docker run --rm --entrypoint <cmd> <image> <args...>
[ "$1" = run ] || exit 2
cd "${dir}/images/\${5//:/_}" 2>/dev/null || { echo "no image $5" >&2; exit 125; }
exec "$4" "\${@:6}"
`);
    chmodSync(join(dir, 'bin', 'docker'), 0o755);
    const run = spawnSync('bash', ['-c', `. "${lib}"; release_rollback_check aarast-backend:new aarast-backend:old "$APPLIED"`], {
      encoding: 'utf8',
      env: { ...process.env, PATH: `${join(dir, 'bin')}:${process.env.PATH}`, APPLIED: applied.join('\n') },
    });
    return { status: run.status, output: run.stdout + run.stderr };
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

test('nothing the target does not know: the rollback is only code', () => {
  const run = check({ target: { m1: adds, m2: adds }, current: { m1: adds, m2: adds }, applied: ['m1', 'm2'] });
  assert.equal(run.status, 0, run.output);
  assert.match(run.output, /no migration the target release does not know/);
});

test('migrations the target does not know that only add are named, and allowed', () => {
  const run = check({ target: { m1: adds }, current: { m1: adds, m2: adds, m3: adds }, applied: ['m1', 'm2', 'm3'] });
  assert.equal(run.status, 0, run.output);
  assert.match(run.output, /2 migrations the target release does not know: m2 m3/);
  assert.match(run.output, /only add/);
});

for (const [name, sql, why] of [
  ['drops a column', 'ALTER TABLE "User" DROP COLUMN "legacy";', /drops a column/],
  ['adds an enum value', `ALTER TYPE "Purpose" ADD VALUE 'NEW_ONE';`, /enum value/],
  ['sets NOT NULL', 'ALTER TABLE "User" ALTER COLUMN "name" SET NOT NULL;', /NOT NULL/],
  ['adds a NOT NULL column with no default', 'ALTER TABLE "User" ADD COLUMN "x" TEXT NOT NULL;', /no default/],
  ['renames', 'ALTER TABLE "User" RENAME COLUMN "a" TO "b";', /renames/],
  ['drops a table (even under a comment)', '-- cleanup\nDROP TABLE "Old";', /drops a table/],
]) {
  test(`refuses a rollback over a migration that ${name}`, () => {
    const run = check({ target: { m1: adds }, current: { m1: adds, m2: adds, m3: sql }, applied: ['m1', 'm2', 'm3'] });
    assert.notEqual(run.status, 0);
    assert.match(run.output, new RegExp(`m3: .*${why.source}`));
    assert.doesNotMatch(run.output, /m2: /, 'a migration that only adds is not blamed');
    assert.match(run.output, /roll forward|restore/i, 'it says what to do instead');
  });
}

test('a column added with a default, or nullable, is an addition', () => {
  const run = check({ target: {}, current: { m1: 'ALTER TABLE "T" ADD COLUMN "a" INTEGER NOT NULL DEFAULT 0, ADD COLUMN "b" TEXT;' }, applied: ['m1'] });
  assert.equal(run.status, 0, run.output);
});

test('a migration the current image cannot show is not guessed at', () => {
  const run = check({ target: {}, current: { m1: adds }, applied: ['m1', 'm9'] });
  assert.notEqual(run.status, 0);
  assert.match(run.output, /m9.*cannot be read/);
});

test('the real migrations of this repository are classified, not waved through', () => {
  const passwordless = '20261102120000_passwordless_app_sign_up';
  const sql = readFileSync(join(migrations, passwordless, 'migration.sql'), 'utf8');
  const run = spawnSync(python, [join(root, 'deploy/aws/host/migration-breaks-older-code.py'),
    `${passwordless}=${join(migrations, passwordless, 'migration.sql')}`], { encoding: 'utf8' });
  assert.ok(sql.length > 0);
  assert.equal(run.status, 1, 'the one-way migration OPERATIONS.md names is refused: ' + run.stdout);
});

test('rollback.sh no longer claims the migrations only add, and checks before it starts anything', () => {
  assert.doesNotMatch(rollback, /migrations only add|only add, so/i);
  assert.match(rollback, /release_rollback_check /);
  assert.ok(rollback.indexOf('release_rollback_check') < rollback.indexOf('release_backup_before'));
  assert.ok(rollback.indexOf('release_rollback_check') < rollback.indexOf('dc up -d'));
  assert.match(rollback, /_prisma_migrations/);
  assert.match(rollback, /rolled_back_at IS NULL/);
});

test('release_rollback_check exists in the shared library and is valid bash', () => {
  assert.equal(spawnSync('bash', ['-n', lib]).status, 0);
  assert.match(readFileSync(lib, 'utf8'), /^release_rollback_check\(\)/m);
});
