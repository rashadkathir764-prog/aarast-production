import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const compose = readFileSync(
  new URL('../docker-compose.yml', import.meta.url),
  'utf8',
);
const envExample = readFileSync(
  new URL('../.env.example', import.meta.url),
  'utf8',
);
const roleSql = readFileSync(
  new URL('../postgres/least-privilege.sql', import.meta.url),
  'utf8',
);
const backendDockerfile = readFileSync(
  new URL('../../../backend/Dockerfile', import.meta.url),
  'utf8',
);

function serviceBlock(name, nextName) {
  const pattern = new RegExp(
    `^  ${name}:\\n(?<body>[\\s\\S]*?)(?=^  ${nextName}:\\n)`,
    'm',
  );
  const body = compose.match(pattern)?.groups?.body;
  assert.ok(body, `missing ${name} service block`);
  return body;
}

test('production separates PostgreSQL owner, migrator, and runtime identities', () => {
  const postgres = serviceBlock('postgres', 'postgres-roles');
  const roles = serviceBlock('postgres-roles', 'redis');
  const migration = serviceBlock('migrate', 'backend');
  const backend = serviceBlock('backend', 'admin-web');

  assert.match(postgres, /POSTGRES_USER: \$\{POSTGRES_OWNER_USER:\?/);
  assert.match(postgres, /POSTGRES_PASSWORD: \$\{POSTGRES_OWNER_PASSWORD:\?/);

  assert.match(roles, /POSTGRES_OWNER_PASSWORD:/);
  assert.match(roles, /AARAST_DB_MIGRATOR_PASSWORD:/);
  assert.match(roles, /AARAST_DB_RUNTIME_PASSWORD:/);

  assert.match(
    migration,
    /DATABASE_URL: \$\{AARAST_DB_MIGRATOR_DATABASE_URL:\?/,
  );
  assert.match(
    backend,
    /DATABASE_URL: \$\{AARAST_DB_RUNTIME_DATABASE_URL:\?/,
  );
  assert.doesNotMatch(migration, /POSTGRES_OWNER_PASSWORD/);
  assert.doesNotMatch(backend, /POSTGRES_OWNER_PASSWORD/);
  assert.doesNotMatch(backend, /AARAST_DB_MIGRATOR_(?:PASSWORD|DATABASE_URL)/);
});

test('migrations complete before the runtime starts and never run in it', () => {
  const migration = serviceBlock('migrate', 'backend');
  const backend = serviceBlock('backend', 'admin-web');

  assert.match(migration, /prisma migrate deploy/);
  assert.match(migration, /prisma migrate status/);
  assert.match(migration, /assert-database-identity\.cjs/);
  assert.match(backend, /migrate:\s*\n\s*condition: service_completed_successfully/);
  assert.match(backend, /assert-database-identity\.cjs/);
  assert.match(backend, /exec node dist\/main\.js/);
  assert.doesNotMatch(backend, /prisma migrate/);
  assert.match(
    backendDockerfile,
    /COPY --from=build \/app\/scripts\/prod\/assert-database-identity\.cjs/,
  );
});

test('role bootstrap grants runtime CRUD without DDL or cluster authority', () => {
  for (const attribute of [
    'NOSUPERUSER',
    'NOCREATEDB',
    'NOCREATEROLE',
    'NOREPLICATION',
    'NOBYPASSRLS',
  ]) {
    assert.equal(roleSql.includes(attribute), true, attribute);
  }

  assert.match(
    roleSql,
    /GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public/,
  );
  assert.match(
    roleSql,
    /GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public/,
  );
  assert.match(roleSql, /REVOKE CREATE ON SCHEMA public/);
  assert.match(roleSql, /ALTER DEFAULT PRIVILEGES FOR ROLE/);
  assert.match(roleSql, /ALTER ROUTINE/);
  assert.match(roleSql, /ALTER TYPE/);
});

test('example credentials keep the three PostgreSQL identities explicit', () => {
  for (const variable of [
    'POSTGRES_OWNER_USER',
    'POSTGRES_OWNER_PASSWORD',
    'AARAST_DB_MIGRATOR_USER',
    'AARAST_DB_MIGRATOR_PASSWORD',
    'AARAST_DB_MIGRATOR_DATABASE_URL',
    'AARAST_DB_RUNTIME_USER',
    'AARAST_DB_RUNTIME_PASSWORD',
    'AARAST_DB_RUNTIME_DATABASE_URL',
  ]) {
    assert.match(envExample, new RegExp(`^${variable}=`, 'm'), variable);
  }
  assert.doesNotMatch(envExample, /^POSTGRES_USER=/m);
  assert.doesNotMatch(envExample, /^DATABASE_URL=/m);
});
