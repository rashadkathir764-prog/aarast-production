import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(
  new URL('./verify-backup-restore.sh', import.meta.url),
  'utf8',
);
const dockerfile = readFileSync(
  new URL('../../../backend/Dockerfile', import.meta.url),
  'utf8',
);
const adminDockerfile = readFileSync(
  new URL('../../../admin-web/Dockerfile', import.meta.url),
  'utf8',
);
const publicSiteDockerfile = readFileSync(
  new URL('../../public-site/Dockerfile', import.meta.url),
  'utf8',
);
const runtimeCompose = readFileSync(
  new URL('../docker-compose.yml', import.meta.url),
  'utf8',
);
const buildCompose = readFileSync(
  new URL('../docker-compose.build.yml', import.meta.url),
  'utf8',
);
const environmentExample = readFileSync(
  new URL('../.env.example', import.meta.url),
  'utf8',
);
const postgres16AlpineDigest =
  'postgres@sha256:16bc17c64a573ef34162af9298258d1aec548232985b33ed7b1eac33ba35c229';

test('restore verifier pins PostgreSQL and requires an immutable backend', () => {
  assert.equal(source.includes(postgres16AlpineDigest), true);
  assert.match(source, /sha256:\*\|\*@sha256:\*\) ;;/);
  assert.match(source, /candidate backend image must be immutable/);
  assert.match(source, /AARAST_VERIFY_BACKUP_SHA256/);
  assert.match(source, /AARAST_VERIFY_GIT_REVISION/);
  assert.match(source, /docker image inspect/);
  assert.match(source, /org\.opencontainers\.image\.revision/);
  assert.match(source, /ACTUAL_REVISION.*EXPECTED_REVISION/s);
  assert.doesNotMatch(source, /development-unversioned/);
  assert.match(source, /docker network create --internal "\$NETWORK"/);
});

test('backend image distinguishes local builds and labels release revisions', () => {
  assert.match(
    dockerfile,
    /ARG AARAST_GIT_REVISION=development-unversioned/,
  );
  assert.doesNotMatch(dockerfile, /ARG AARAST_GIT_REVISION=unknown/);
  assert.match(
    dockerfile,
    /AARAST_GIT_REVISION" != "development-unversioned"/,
  );
  assert.match(dockerfile, /\$\{#AARAST_GIT_REVISION\}.*-ne 40/);
  assert.match(dockerfile, /\*\[!0-9a-f\]\*/);
  assert.match(
    dockerfile,
    /LABEL org\.opencontainers\.image\.revision="\$\{AARAST_GIT_REVISION\}"/,
  );
});

test('production runtime uses only prebuilt content-addressed application images', () => {
  assert.equal(
    (runtimeCompose.match(/image: \$\{AARAST_BACKEND_IMAGE_ID:\?/g) ?? [])
      .length,
    2,
  );
  assert.match(runtimeCompose, /image: \$\{AARAST_ADMIN_WEB_IMAGE_ID:\?/);
  assert.match(runtimeCompose, /image: \$\{AARAST_PUBLIC_SITE_IMAGE_ID:\?/);
  assert.equal((runtimeCompose.match(/pull_policy: never/g) ?? []).length, 4);
  assert.doesNotMatch(runtimeCompose, /aarast-(?:backend|admin-web|public-site):prod/);

  const migrateBlock = runtimeCompose.match(
    /  migrate:\n(?<body>[\s\S]*?)\n  backend:/,
  )?.groups?.body;
  const backendBlock = runtimeCompose.match(
    /  backend:\n(?<body>[\s\S]*?)\n  admin-web:/,
  )?.groups?.body;
  const adminBlock = runtimeCompose.match(
    /  admin-web:\n(?<body>[\s\S]*?)\n  public-site:/,
  )?.groups?.body;
  const publicSiteBlock = runtimeCompose.match(
    /  public-site:\n(?<body>[\s\S]*?)\nvolumes:/,
  )?.groups?.body;
  assert.ok(migrateBlock);
  assert.ok(backendBlock);
  assert.ok(adminBlock);
  assert.ok(publicSiteBlock);
  assert.doesNotMatch(migrateBlock, /\n    build:/);
  assert.doesNotMatch(backendBlock, /\n    build:/);
  assert.doesNotMatch(adminBlock, /\n    build:/);
  assert.doesNotMatch(publicSiteBlock, /\n    build:/);
  assert.match(publicSiteBlock, /"8095:80"/);
});

test('release build compose stamps all application images with one Git revision', () => {
  assert.equal(
    (buildCompose.match(/AARAST_GIT_REVISION: \$\{AARAST_GIT_REVISION:\?/g) ?? [])
      .length,
    3,
  );
  assert.match(buildCompose, /aarast-backend:candidate-\$\{AARAST_GIT_REVISION:\?/);
  assert.match(buildCompose, /aarast-admin-web:candidate-\$\{AARAST_GIT_REVISION:\?/);
  assert.match(buildCompose, /aarast-public-site:candidate-\$\{AARAST_GIT_REVISION:\?/);
  assert.match(
    adminDockerfile,
    /ARG AARAST_GIT_REVISION=development-unversioned/,
  );
  assert.match(
    adminDockerfile,
    /LABEL org\.opencontainers\.image\.revision="\$\{AARAST_GIT_REVISION\}"/,
  );
  assert.match(
    publicSiteDockerfile,
    /ARG AARAST_GIT_REVISION=development-unversioned/,
  );
  assert.match(
    publicSiteDockerfile,
    /LABEL org\.opencontainers\.image\.revision="\$\{AARAST_GIT_REVISION\}"/,
  );
});

test('production CORS trusts only the browser client that calls the API', () => {
  const corsLine = environmentExample
    .split(/\r?\n/)
    .find((line) => line.startsWith('CORS_ORIGINS='));

  assert.equal(
    corsLine,
    'CORS_ORIGINS=https://aarast-admin.shadowgardn.com',
  );
});

test('restore verifier supports current backup formats and migration rehearsal', () => {
  assert.match(source, /pg_restore --list/);
  assert.match(source, /--exit-on-error --no-owner --no-privileges/);
  assert.match(source, /gzip -dc/);
  assert.match(source, /OWNER TO/);
  assert.match(source, /\(TO\|FROM\)/);
  assert.match(source, /ALTER DEFAULT PRIVILEGES FOR ROLE/);
  assert.match(source, /SET \(ROLE\|SESSION AUTHORIZATION\)/);
  assert.match(source, /PUBLIC\|CURRENT_USER\|SESSION_USER\|CURRENT_ROLE/);
  assert.equal((source.match(/run_candidate_migrations/g) ?? []).length, 3);
  assert.match(source, /prisma migrate deploy/);
  assert.match(source, /prisma migrate status/);
});

test('restore verifier enforces the canonical money schema', () => {
  for (const required of [
    'WeddingCost',
    'CostPayment',
    'PaymentSchedule',
    'canManageMoney',
    'canViewMoney',
  ]) {
    assert.equal(source.includes(required), true, required);
  }
  for (const removed of [
    'Expense',
    'FinancialCommitment',
    'FinancialPaymentRecord',
    'FinancialInstallment',
  ]) {
    assert.match(source, new RegExp(`to_regclass\\([^\\n]+${removed}[^\\n]+IS NULL`));
  }
});

test('restore verifier enforces the coordinated contributor cutover schema', () => {
  for (const required of [
    'ContributorHistoryScope',
    'ContributorTenure',
    'ContributionEvent',
    'AccountDeletionReceipt',
    'authorityVersion',
    'ContributorTenure_immutable_identity',
    'ContributionEvent_append_only',
    'AccountDeletionReceipt_immutable_update',
    'AccountDeletionReceipt_immutable_delete',
    '20260802090000_add_contributor_history',
    '20260803110000_add_account_deletion_receipts',
    '20260811180000_backfill_missing_contributor_history_scopes',
    'canonical_contribution_json',
    'safe_legacy_contribution_text',
  ]) {
    assert.equal(source.includes(required), true, required);
  }
  assert.doesNotMatch(
    source,
    /count\(\*\) FROM "ContributorHistoryScope"\)\s*=\s*\(SELECT count\(\*\) FROM "WeddingPlan"/,
  );
  assert.match(
    source,
    /FROM "WeddingPlan" AS plan[\s\S]*LEFT JOIN "ContributorHistoryScope" AS scope[\s\S]*WHERE scope\."id" IS NULL/,
  );
  assert.match(
    source,
    /FROM "SharedMember" AS member[\s\S]*LEFT JOIN "ContributorTenure" AS tenure[\s\S]*tenure\."sharedMemberId" = member\."id"[\s\S]*tenure\."actorReference" = encode\(digest/,
  );
});
