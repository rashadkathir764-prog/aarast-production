import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { test } from 'node:test';

// RA-BE-147: the backup was one dump a day, so a mistake at 14:00 lost the
// morning, and a restore could only go to a night. The database now archives
// its WAL, the host ships it and a weekly base backup to the ops bucket, and
// pitr-restore.sh brings the database back to a chosen second in a scratch
// instance. None of this needs Docker here: the shell is syntax-checked and
// run against fake `aws` and `docker`, and the compose file is read as text.
const root = resolve(import.meta.dirname, '../..');
const read = (path) => readFileSync(join(root, path), 'utf8');
const compose = read('deploy/aws/compose.yml');
const postgresImage = /image: (postgres:16-alpine@sha256:[0-9a-f]{64})/.exec(compose)[1];

test('postgres archives its WAL to a volume it can write, and waits for that volume to be ready', () => {
  const postgres = /^  postgres:\n([\s\S]*?)\n  postgres-roles:/m.exec(compose)[1];
  assert.match(postgres, /"archive_mode=on"|archive_mode=on/);
  assert.match(postgres, /archive_timeout=300/, 'at most five minutes of writes are not yet in the archive');
  const command = /archive_command=([^"\n]+)"/.exec(postgres)?.[1] ?? '';
  assert.match(command, /cp %p \/wal-archive\/%f\.partial/);
  assert.match(command, /mv \/wal-archive\/%f\.partial \/wal-archive\/%f/);
  assert.match(command, /cmp -s %p \/wal-archive\/%f/, 'a segment sent twice is a success only if it is the same one');
  assert.match(postgres, /- postgres_wal:\/wal-archive/);
  assert.match(postgres, /wal-archive-init:\s*\n\s+condition: service_completed_successfully/);
  const init = /^  wal-archive-init:\n([\s\S]*?)\n\n/m.exec(compose)?.[1] ?? '';
  assert.ok(init.includes(postgresImage), 'the same pinned image, no new one');
  assert.match(init, /chown 70:70 \/wal-archive/);
  assert.match(init, /- postgres_wal:\/wal-archive/);
  assert.match(compose, /^  postgres_wal:\n    name: aarast_postgres_wal$/m);
});

test('the host ships the WAL every few minutes and a base backup every week', () => {
  const deploy = read('deploy/aws/host/deploy.sh');
  assert.match(deploy, /\*\/5 \* \* \* \* root bash \/opt\/aarast\/current\/deploy\/aws\/host\/wal-sync\.sh \$ops_bucket/);
  assert.match(deploy, /\/etc\/cron\.d\/aarast-wal-sync/);
  assert.match(deploy, /\d+ \d+ \* \* 0 root bash \/opt\/aarast\/current\/deploy\/aws\/host\/base-backup\.sh \$ops_bucket/);
  const sync = read('deploy/aws/host/wal-sync.sh');
  assert.match(sync, /s3:\/\/\$ops_bucket\/backups\/wal\//, 'under backups/, which the host role may already write');
  assert.match(sync, /\*\.partial/, 'a half-written segment is never sent');
  assert.ok(sync.indexOf('aws s3 cp') < sync.indexOf('rm -f'), 'a file is removed only after it was sent');
  const base = read('deploy/aws/host/base-backup.sh');
  assert.match(base, /pg_basebackup/);
  assert.match(base, /-X none/, 'the WAL comes from the archive, not from the base backup');
  assert.match(base, /gzip -t/);
  assert.match(base, /s3:\/\/\$ops_bucket\/backups\/base\//);
  for (const script of ['wal-sync', 'base-backup', 'pitr-restore']) {
    assert.equal(spawnSync('bash', ['-n', join(root, `deploy/aws/host/${script}.sh`)]).status, 0, script);
  }
});

/** Runs pitr-restore.sh with a fake aws (the bucket) and docker; returns what it did. */
function pitr(target, { bases = ['20261110T030000Z', '20261117T030000Z', '20261124T030000Z'] } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'aarast-pitr-'));
  try {
    mkdirSync(join(dir, 'bin'));
    mkdirSync(join(dir, 'seed/data'), { recursive: true });
    writeFileSync(join(dir, 'seed/data/PG_VERSION'), '16\n');
    spawnSync('tar', ['-czf', join(dir, 'base.tar.gz'), '-C', join(dir, 'seed/data'), '.']);
    writeFileSync(join(dir, 'bin/aws'), `#!/bin/bash
echo "aws $*" >>"${dir}/calls"
case "$2" in
  ls) ${bases.map((b) => `echo "2026-11-17 03:00:00   1000 ${b}.tar.gz"`).join('; ') || ':'} ;;
  cp) cp "${dir}/base.tar.gz" "\${@: -2:1}" 2>/dev/null || cp "${dir}/base.tar.gz" "$4" ;;
  sync) mkdir -p "$4"; echo wal >"$4/000000010000000000000001" ;;
esac
`);
    writeFileSync(join(dir, 'bin/docker'), `#!/bin/bash
echo "docker $*" >>"${dir}/calls"
case "$1" in
  exec) case "$*" in *pg_is_in_recovery*) echo f ;; esac ;;
esac
`);
    for (const name of ['aws', 'docker']) chmodSync(join(dir, 'bin', name), 0o755);
    const run = spawnSync('bash', [join(root, 'deploy/aws/host/pitr-restore.sh'), 'ops-bucket', target], {
      encoding: 'utf8',
      env: { ...process.env, PATH: `${join(dir, 'bin')}:${process.env.PATH}`, PITR_ROOT: join(dir, 'pitr'), PITR_NO_CHOWN: '1' },
    });
    const calls = existsSync(join(dir, 'calls')) ? readFileSync(join(dir, 'calls'), 'utf8') : '';
    const data = join(dir, 'pitr', '20261117T030000Z', 'data');
    const files = existsSync(data)
      ? {
          conf: existsSync(join(data, 'postgresql.auto.conf')) ? readFileSync(join(data, 'postgresql.auto.conf'), 'utf8') : '',
          signal: existsSync(join(data, 'recovery.signal')),
        }
      : null;
    return { status: run.status, output: run.stdout + run.stderr, calls, files };
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

test('pitr-restore.sh refuses a time it cannot read, and a time before the first base backup', () => {
  assert.match(pitr('yesterday').output, /time must be UTC as 'YYYY-MM-DD HH:MM:SS'/);
  assert.notEqual(pitr('yesterday').status, 0);
  assert.notEqual(pitr('2026-02-30 10:00:00').status, 0, 'a day that does not exist');
  const early = pitr('2026-11-01 10:00:00');
  assert.notEqual(early.status, 0);
  assert.match(early.output, /no base backup at or before 2026-11-01 10:00:00/);
  assert.doesNotMatch(early.calls, /docker run/);
});

test('pitr-restore.sh recovers a scratch instance to the second asked for, from the right base backup', () => {
  const run = pitr('2026-11-20 14:25:30');
  assert.equal(run.status, 0, run.output);
  assert.match(run.output, /base backup: 20261117T030000Z/, 'the newest one before the time, not the newest one');
  assert.match(run.calls, /aws s3 cp s3:\/\/ops-bucket\/backups\/base\/20261117T030000Z\.tar\.gz/);
  assert.match(run.calls, /aws s3 sync s3:\/\/ops-bucket\/backups\/wal\//);
  const { files } = run;
  assert.ok(files, 'the base backup was unpacked');
  assert.ok(files.signal, 'recovery.signal asks Postgres to recover');
  assert.match(files.conf, /restore_command = 'cp \/wal\/%f %p'/);
  assert.match(files.conf, /recovery_target_time = '2026-11-20 14:25:30\+00'/);
  assert.match(files.conf, /recovery_target_action = 'promote'/);
  // Scratch, and not the live database: no network, its own name, the pinned image.
  assert.match(run.calls, /docker run -d --name aarast-pitr-20261117T030000Z --network none/);
  assert.ok(run.calls.includes(postgresImage));
  assert.doesNotMatch(run.calls, /docker compose|aarast-postgres-1|stop|rm -f aarast-postgres/);
  assert.match(run.output, /the live database was not touched/);
});

test('the runbook says how to point in time, with what is lost and what is not covered', () => {
  const operations = read('docs/handover/OPERATIONS.md');
  assert.match(operations, /pitr-restore\.sh/);
  assert.match(operations, /RA-BE-147/);
  assert.match(operations, /خمس دقائق/);
});
