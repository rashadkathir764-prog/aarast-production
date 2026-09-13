#!/usr/bin/env node
'use strict';

// Schema equivalence: the migration history, replayed on the managed isolated
// database, must describe exactly the split Prisma schema. A drift between
// the two is what `prisma migrate dev` would turn into an unintended
// migration and what `prisma migrate deploy` would silently leave behind.
// Runs as a database-only managed package: the isolated database is the
// shadow database and is dropped by the runner afterwards.

const { spawnSync } = require('node:child_process');
const { existsSync } = require('node:fs');
const { join, resolve } = require('node:path');
const { assertManagedSmokeEnvironment } = require('./smoke-utils');

const backendRoot = resolve(__dirname, '..', '..');
const prismaCli = join(backendRoot, 'node_modules', 'prisma', 'build', 'index.js');

function main() {
  assertManagedSmokeEnvironment(process.env);
  if (!existsSync(prismaCli)) throw new Error('Prisma CLI must be installed');
  const result = spawnSync(
    process.execPath,
    [
      prismaCli,
      'migrate',
      'diff',
      '--from-migrations',
      join(backendRoot, 'prisma', 'migrations'),
      '--to-schema-datamodel',
      join(backendRoot, 'prisma', 'schema'),
      '--shadow-database-url',
      process.env.SMOKE_DATABASE_URL,
      '--exit-code',
    ],
    {
      cwd: backendRoot,
      encoding: 'utf8',
      maxBuffer: 4 * 1024 * 1024,
      shell: false,
      timeout: 300_000,
      windowsHide: true,
    },
  );
  if (result.error) throw result.error;
  // Exit code 2 = differences found, 1 = tool error, 0 = equivalent.
  if (result.status !== 0) {
    process.stdout.write(`${result.stdout}${result.stderr}`);
    throw new Error(
      result.status === 2
        ? 'Migration history and the Prisma schema differ (see the diff above).'
        : `prisma migrate diff failed with exit code ${result.status ?? 'unknown'}.`,
    );
  }
  console.log('PASS - schema equivalence: migrations replayed on the isolated database match prisma/schema');
}

main();
