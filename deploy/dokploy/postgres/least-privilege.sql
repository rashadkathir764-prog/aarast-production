\set ON_ERROR_STOP on

\getenv database_name POSTGRES_DB
\getenv owner_user POSTGRES_OWNER_USER
\getenv migrator_user AARAST_DB_MIGRATOR_USER
\getenv migrator_password AARAST_DB_MIGRATOR_PASSWORD
\getenv runtime_user AARAST_DB_RUNTIME_USER
\getenv runtime_password AARAST_DB_RUNTIME_PASSWORD

-- Role names and secret presence are validated by the one-shot container
-- before psql starts. format(%I/%L) keeps identifiers and passwords quoted.
SELECT format(
  'CREATE ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'migrator_user',
  :'migrator_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'migrator_user'
)
\gexec

SELECT format(
  'ALTER ROLE %I WITH LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'migrator_user',
  :'migrator_password'
)
\gexec

SELECT format(
  'CREATE ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'runtime_user',
  :'runtime_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'runtime_user'
)
\gexec

SELECT format(
  'ALTER ROLE %I WITH LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'runtime_user',
  :'runtime_password'
)
\gexec

-- No role membership may let the runtime become the owner or migrator.
SELECT format('REVOKE %I FROM %I', :'owner_user', :'runtime_user')
WHERE pg_has_role(:'runtime_user', :'owner_user', 'MEMBER')
\gexec
SELECT format('REVOKE %I FROM %I', :'migrator_user', :'runtime_user')
WHERE pg_has_role(:'runtime_user', :'migrator_user', 'MEMBER')
\gexec

-- The migrator owns the application database and every current object. This
-- lets it apply committed DDL without inheriting the PostgreSQL superuser.
SELECT format(
  'ALTER DATABASE %I OWNER TO %I',
  :'database_name',
  :'migrator_user'
)
\gexec

SELECT format('ALTER SCHEMA public OWNER TO %I', :'migrator_user')
\gexec

SELECT format(
  'ALTER %s %s OWNER TO %I',
  CASE relation.relkind
    WHEN 'r' THEN 'TABLE'
    WHEN 'p' THEN 'TABLE'
    WHEN 'S' THEN 'SEQUENCE'
    WHEN 'v' THEN 'VIEW'
    WHEN 'm' THEN 'MATERIALIZED VIEW'
    WHEN 'f' THEN 'FOREIGN TABLE'
  END,
  relation.oid::regclass,
  :'migrator_user'
)
FROM pg_class AS relation
JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
WHERE namespace.nspname = 'public'
  AND relation.relkind IN ('r', 'p', 'S', 'v', 'm', 'f')
\gexec

SELECT format(
  'ALTER TYPE %I.%I OWNER TO %I',
  namespace.nspname,
  type.typname,
  :'migrator_user'
)
FROM pg_type AS type
JOIN pg_namespace AS namespace ON namespace.oid = type.typnamespace
LEFT JOIN pg_class AS relation ON relation.oid = type.typrelid
WHERE namespace.nspname = 'public'
  AND type.typtype IN ('d', 'e', 'r', 'm')
  AND relation.oid IS NULL
\gexec

SELECT format(
  'ALTER ROUTINE %s OWNER TO %I',
  routine.oid::regprocedure,
  :'migrator_user'
)
FROM pg_proc AS routine
JOIN pg_namespace AS namespace ON namespace.oid = routine.pronamespace
WHERE namespace.nspname = 'public'
\gexec

-- Public receives no implicit application-schema authority.
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'database_name')
\gexec
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
SELECT format(
  'REVOKE USAGE ON TYPE %I.%I FROM PUBLIC',
  namespace.nspname,
  type.typname
)
FROM pg_type AS type
JOIN pg_namespace AS namespace ON namespace.oid = type.typnamespace
WHERE namespace.nspname = 'public'
  AND type.typtype IN ('d', 'e', 'r', 'm')
\gexec

-- Reset historical grants before assigning the exact runtime capability.
SELECT format('REVOKE ALL ON DATABASE %I FROM %I', :'database_name', :'runtime_user')
\gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database_name', :'runtime_user')
\gexec
SELECT format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO %I', :'database_name', :'migrator_user')
\gexec

SELECT format('REVOKE ALL ON SCHEMA public FROM %I', :'runtime_user')
\gexec
SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'runtime_user')
\gexec
SELECT format('REVOKE CREATE ON SCHEMA public FROM %I', :'runtime_user')
\gexec

SELECT format('REVOKE ALL ON ALL TABLES IN SCHEMA public FROM %I', :'runtime_user')
\gexec
SELECT format(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO %I',
  :'runtime_user'
)
\gexec

SELECT format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', :'runtime_user')
\gexec
SELECT format(
  'GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO %I',
  :'runtime_user'
)
\gexec

SELECT format('REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM %I', :'runtime_user')
\gexec
SELECT format(
  'REVOKE USAGE ON TYPE %I.%I FROM %I',
  namespace.nspname,
  type.typname,
  :'runtime_user'
)
FROM pg_type AS type
JOIN pg_namespace AS namespace ON namespace.oid = type.typnamespace
WHERE namespace.nspname = 'public'
  AND type.typtype IN ('d', 'e', 'r', 'm')
\gexec
SELECT format(
  'GRANT USAGE ON TYPE %I.%I TO %I',
  namespace.nspname,
  type.typname,
  :'runtime_user'
)
FROM pg_type AS type
JOIN pg_namespace AS namespace ON namespace.oid = type.typnamespace
WHERE namespace.nspname = 'public'
  AND type.typtype IN ('d', 'e', 'r', 'm')
\gexec

-- New migration-owned objects inherit the same least-privilege grants.
SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC',
  :'migrator_user'
)
\gexec
SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
  :'migrator_user',
  :'runtime_user'
)
\gexec
SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC',
  :'migrator_user'
)
\gexec
SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %I',
  :'migrator_user',
  :'runtime_user'
)
\gexec
SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC',
  :'migrator_user'
)
\gexec
SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE USAGE ON TYPES FROM PUBLIC',
  :'migrator_user'
)
\gexec
SELECT format(
  'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT USAGE ON TYPES TO %I',
  :'migrator_user',
  :'runtime_user'
)
\gexec
