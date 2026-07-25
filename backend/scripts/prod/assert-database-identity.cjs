#!/usr/bin/env node
'use strict';

function fail(message) {
  process.stderr.write(`Database identity check failed: ${message}\n`);
  process.exit(1);
}

const expectedRole = process.env.AARAST_DB_EXPECTED_ROLE?.trim();
const expectedDatabase = process.env.POSTGRES_DB?.trim();
const rawUrl = process.env.DATABASE_URL?.trim();

if (!expectedRole || !expectedDatabase || !rawUrl) {
  fail('required runtime identity configuration is incomplete');
}

let databaseUrl;
try {
  databaseUrl = new URL(rawUrl);
} catch {
  fail('DATABASE_URL is not a valid PostgreSQL URL');
}

if (!['postgres:', 'postgresql:'].includes(databaseUrl.protocol)) {
  fail('DATABASE_URL does not use PostgreSQL');
}

let actualRole;
let actualDatabase;
try {
  actualRole = decodeURIComponent(databaseUrl.username);
  actualDatabase = decodeURIComponent(databaseUrl.pathname.replace(/^\/+/, ''));
} catch {
  fail('DATABASE_URL contains malformed percent encoding');
}

if (actualRole !== expectedRole) {
  fail('DATABASE_URL user does not match the assigned service role');
}
if (actualDatabase !== expectedDatabase) {
  fail('DATABASE_URL database does not match POSTGRES_DB');
}
if (databaseUrl.searchParams.get('schema') !== 'public') {
  fail('DATABASE_URL must target the public application schema');
}

process.stdout.write('Database identity check passed.\n');
