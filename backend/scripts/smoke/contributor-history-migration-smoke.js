#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const {
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  rmSync,
} = require('node:fs');
const { basename, dirname, join, resolve } = require('node:path');
const { tmpdir } = require('node:os');
const { PrismaClient } = require('@prisma/client');
const { assertManagedSmokeEnvironment } = require('./smoke-utils');

const TARGET_MIGRATION = '20260802090000_add_contributor_history';
const RECEIPT_MIGRATION = '20260803110000_add_account_deletion_receipts';
const backendRoot = resolve(__dirname, '..', '..');
const prismaRoot = join(backendRoot, 'prisma');
const migrationsRoot = join(prismaRoot, 'migrations');
const prismaCli = join(
  backendRoot,
  'node_modules',
  'prisma',
  'build',
  'index.js',
);

const fixture = Object.freeze({
  ownerUserId: 'legacy-owner',
  contributorAUserId: 'legacy-contributor-a',
  contributorBUserId: 'legacy-contributor-b',
  contributorCUserId: 'post-migration-contributor-c',
  primaryPlanId: 'legacy-plan-primary',
  archivedPlanId: 'legacy-plan-archived',
  memberAId: 'legacy-member-a',
  memberBId: 'legacy-member-b',
  memberCId: 'post-migration-member-c',
  taskAId: 'legacy-task-assigned-a',
  taskBId: 'legacy-task-assigned-b',
  ownerTaskId: 'legacy-task-owner',
  unassignedTaskId: 'legacy-task-unassigned',
  quoteAId: 'legacy-quote-created-a',
  ownerQuoteId: 'legacy-quote-created-owner',
  inviteAId: 'legacy-invite-created-a',
  ownerInviteId: 'legacy-invite-created-owner',
  guestId: 'legacy-guest-unattributed',
  categoryId: 'legacy-budget-category',
  costId: 'legacy-cost-unattributed',
  cityId: 'legacy-city',
  providerId: 'legacy-provider',
  conversationId: 'legacy-plan-conversation',
  unsafeTaskTitle: 'مراجعة جهة ٧٧٧٧٧٧٧٧٧',
  safeTaskTitle: 'مراجعة تجهيز القاعة',
  unsafeInviteName: 'مساهم 777777777',
  privatePhone: '+967711111111',
  privateEmail: 'legacy.private@example.invalid',
  privateToken: createHash('sha256')
    .update('legacy-private-token')
    .digest('hex'),
});

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map((item) => canonicalJson(item)).join(',')}]`;
  }
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

function migrationNames() {
  const names = readdirSync(migrationsRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
  assert.ok(names.includes(TARGET_MIGRATION), 'target migration must exist');
  assert.ok(
    names.includes(RECEIPT_MIGRATION),
    'account deletion receipt migration must exist',
  );
  return names;
}

function createMigrationWorkspace() {
  const root = mkdtempSync(
    join(tmpdir(), 'aarast-contributor-history-migration-'),
  );
  const targetPrismaRoot = join(root, 'prisma');
  const targetMigrationsRoot = join(targetPrismaRoot, 'schema', 'migrations');
  mkdirSync(targetMigrationsRoot, { recursive: true });
  cpSync(join(prismaRoot, 'schema'), join(targetPrismaRoot, 'schema'), {
    recursive: true,
  });
  copyFileSync(
    join(migrationsRoot, 'migration_lock.toml'),
    join(targetMigrationsRoot, 'migration_lock.toml'),
  );

  const previousMigrations = migrationNames().filter(
    (name) => name < TARGET_MIGRATION,
  );
  for (const name of previousMigrations) {
    cpSync(join(migrationsRoot, name), join(targetMigrationsRoot, name), {
      recursive: true,
    });
  }
  return {
    root,
    prismaRoot: targetPrismaRoot,
    migrationsRoot: targetMigrationsRoot,
    schemaPath: join(targetPrismaRoot, 'schema'),
    previousMigrations,
  };
}

function addTargetMigration(workspace, migrationName = TARGET_MIGRATION) {
  const target = join(workspace.migrationsRoot, migrationName);
  assert.equal(existsSync(target), false, 'target migration must not exist in pre-state');
  cpSync(join(migrationsRoot, migrationName), target, { recursive: true });
}

function deployMigrations(schemaPath) {
  assert.ok(existsSync(prismaCli), 'Prisma CLI must be installed');
  const result = spawnSync(
    process.execPath,
    [prismaCli, 'migrate', 'deploy', '--schema', schemaPath],
    {
      cwd: tmpdir(),
      encoding: 'utf8',
      maxBuffer: 4 * 1024 * 1024,
      shell: false,
      timeout: 180_000,
      windowsHide: true,
    },
  );
  if (result.error || result.status !== 0) {
    throw new Error(
      `Prisma migration rehearsal failed with exit code ${result.status ?? 'unknown'}.`,
      { cause: result.error },
    );
  }
}

function cleanupMigrationWorkspace(workspaceRoot) {
  const resolvedRoot = resolve(workspaceRoot);
  assert.equal(
    dirname(resolvedRoot),
    resolve(tmpdir()),
    'temporary migration workspace must be a direct child of the OS temp folder',
  );
  assert.match(
    basename(resolvedRoot),
    /^aarast-contributor-history-migration-/,
  );
  rmSync(resolvedRoot, {
    recursive: true,
    force: true,
    maxRetries: 10,
    retryDelay: 200,
  });
}

async function tableExists(client, tableName) {
  const rows = await client.$queryRawUnsafe(
    `SELECT to_regclass($1) IS NOT NULL AS "exists";`,
    `public."${tableName.replace(/"/g, '""')}"`,
  );
  return rows[0]?.exists === true;
}

async function columnExists(client, tableName, columnName) {
  const rows = await client.$queryRawUnsafe(
    `
      SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = $1
          AND column_name = $2
      ) AS "exists";
    `,
    tableName,
    columnName,
  );
  return rows[0]?.exists === true;
}

async function appliedMigrations(client) {
  return client.$queryRawUnsafe(`
    SELECT migration_name AS "migrationName", finished_at AS "finishedAt",
           rolled_back_at AS "rolledBackAt"
    FROM "_prisma_migrations"
    ORDER BY migration_name;
  `);
}

async function assertPreMigrationState(client, previousMigrations) {
  const applied = await appliedMigrations(client);
  assert.deepEqual(
    applied.map((row) => row.migrationName),
    previousMigrations,
    'the rehearsal must start from every migration immediately before the target',
  );
  assert.equal(
    applied.some((row) => row.migrationName === TARGET_MIGRATION),
    false,
  );
  assert.equal(
    applied.some((row) => row.migrationName === RECEIPT_MIGRATION),
    false,
  );
  assert.equal(await tableExists(client, 'ContributorHistoryScope'), false);
  assert.equal(await tableExists(client, 'ContributorTenure'), false);
  assert.equal(await tableExists(client, 'ContributionEvent'), false);
  assert.equal(await tableExists(client, 'AccountDeletionReceipt'), false);
  assert.equal(
    await columnExists(client, 'SharedMember', 'authorityVersion'),
    false,
  );
}

async function seedLegacyFixtures(client) {
  await client.$transaction(async (tx) => {
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "User" ("id", "name", "passwordHash", "createdAt", "updatedAt")
        VALUES
          ($1, 'Legacy Owner', 'hash', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ($2, 'Legacy Contributor A', 'hash', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ($3, 'Legacy Contributor B', 'hash', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.ownerUserId,
      fixture.contributorAUserId,
      fixture.contributorBUserId,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "WeddingPlan" (
          "id", "ownerUserId", "title", "estimatedBudget", "status", "createdAt", "updatedAt"
        ) VALUES
          ($1, $3, 'Legacy Primary Plan', 10000, 'PLANNING', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ($2, $3, 'Legacy Archived Plan', NULL, 'ARCHIVED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.primaryPlanId,
      fixture.archivedPlanId,
      fixture.ownerUserId,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "SharedMember" (
          "id", "weddingPlanId", "userId", "role",
          "canViewMoney", "canEditPlan", "canManageTasks",
          "canManageGuests", "canManageProviders", "canInviteMembers",
          "canManageMoney", "receiveNotifications", "createdAt", "updatedAt"
        ) VALUES
          ($1, $3, $4, 'CONTRIBUTOR', TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE,
            CURRENT_TIMESTAMP - INTERVAL '20 days', CURRENT_TIMESTAMP),
          ($2, $3, $5, 'CONTRIBUTOR', FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE,
            CURRENT_TIMESTAMP - INTERVAL '10 days', CURRENT_TIMESTAMP);
      `,
      fixture.memberAId,
      fixture.memberBId,
      fixture.primaryPlanId,
      fixture.contributorAUserId,
      fixture.contributorBUserId,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "WeddingTask" (
          "id", "weddingPlanId", "assigneeUserId", "title", "taskCategory",
          "status", "priority", "createdAt", "updatedAt"
        ) VALUES
          ($1, $5, $6, $9, 'تنسيق', 'IN_PROGRESS', 'HIGH', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ($2, $5, $7, $10, 'تنظيم', 'DONE', 'MEDIUM', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ($3, $5, $8, 'Owner task', NULL, 'TODO', 'LOW', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ($4, $5, NULL, 'Unassigned task', NULL, 'TODO', 'LOW', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.taskAId,
      fixture.taskBId,
      fixture.ownerTaskId,
      fixture.unassignedTaskId,
      fixture.primaryPlanId,
      fixture.contributorAUserId,
      fixture.contributorBUserId,
      fixture.ownerUserId,
      fixture.unsafeTaskTitle,
      fixture.safeTaskTitle,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "City" ("id", "nameAr", "createdAt", "updatedAt")
        VALUES ($1, 'مدينة اختبار الترحيل', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.cityId,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "Provider" (
          "id", "cityId", "businessName", "phone", "createdAt", "updatedAt"
        ) VALUES ($1, $2, 'Legacy Provider', '+967700000000', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.providerId,
      fixture.cityId,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "Conversation" (
          "id", "scope", "weddingPlanId", "providerId", "createdByUserId",
          "lastActivityAt", "createdAt", "updatedAt"
        ) VALUES ($1, 'PLAN', $2, $3, $4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.conversationId,
      fixture.primaryPlanId,
      fixture.providerId,
      fixture.contributorAUserId,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "QuoteRequest" (
          "id", "userId", "weddingPlanId", "providerId", "conversationId",
          "contactName", "contactPhone", "contactNormalizedPhone", "message",
          "status", "createdAt", "updatedAt"
        ) VALUES
          ($1, $3, $5, $6, $7, 'Private A', $8, $8, 'private quote body', 'SENT',
            CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_TIMESTAMP),
          ($2, $4, $5, $6, $7, 'Private Owner', $8, $8, 'owner private body', 'VIEWED',
            CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP);
      `,
      fixture.quoteAId,
      fixture.ownerQuoteId,
      fixture.contributorAUserId,
      fixture.ownerUserId,
      fixture.primaryPlanId,
      fixture.providerId,
      fixture.conversationId,
      fixture.privatePhone,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "PlanInvite" (
          "id", "weddingPlanId", "inviterUserId", "inviteeUserId",
          "name", "phone", "normalizedPhone", "email", "tokenHash", "role",
          "canManageTasks", "canInviteMembers", "expiresAt", "acceptedAt",
          "createdAt", "updatedAt"
        ) VALUES
          ($1, $3, $4, $5, $8, $9, $9, $10, $11, 'CONTRIBUTOR', TRUE, TRUE,
            CURRENT_TIMESTAMP + INTERVAL '7 days', CURRENT_TIMESTAMP - INTERVAL '2 days',
            CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP),
          ($2, $3, $6, $5, 'Owner invitation', $9, $9, $10, $12, 'CONTRIBUTOR', TRUE, FALSE,
            CURRENT_TIMESTAMP + INTERVAL '7 days', CURRENT_TIMESTAMP - INTERVAL '1 day',
            CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP);
      `,
      fixture.inviteAId,
      fixture.ownerInviteId,
      fixture.primaryPlanId,
      fixture.contributorAUserId,
      fixture.contributorBUserId,
      fixture.ownerUserId,
      fixture.safeTaskTitle,
      fixture.unsafeInviteName,
      fixture.privatePhone,
      fixture.privateEmail,
      fixture.privateToken,
      sha256(`${fixture.privateToken}:owner`),
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "Guest" (
          "id", "weddingPlanId", "name", "normalizedName", "notes", "createdAt", "updatedAt"
        ) VALUES ($1, $2, 'Legacy Guest', 'legacy guest', 'private guest note', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.guestId,
      fixture.primaryPlanId,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "BudgetCategory" (
          "id", "weddingPlanId", "name", "normalizedName", "allocatedAmount", "createdAt", "updatedAt"
        ) VALUES ($1, $2, 'Legacy Budget', 'legacy budget', 5000, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.categoryId,
      fixture.primaryPlanId,
    );
    await tx.$executeRawUnsafe(
      `
        INSERT INTO "WeddingCost" (
          "id", "weddingPlanId", "budgetCategoryId", "title", "partyName", "partyPhone",
          "totalAmount", "paidAmount", "status", "note", "createdAt", "updatedAt"
        ) VALUES ($1, $2, $3, 'Legacy Cost', 'Private Party', $4, 1000, 0, 'OPEN',
          'private cost note', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      fixture.costId,
      fixture.primaryPlanId,
      fixture.categoryId,
      fixture.privatePhone,
    );
  }, { timeout: 30_000 });
}

async function captureLegacySourceRows(client) {
  const [tasks, quotes, invites, guests, costs] = await Promise.all([
    client.$queryRawUnsafe(`
      SELECT "id", "assigneeUserId", "title", "taskCategory", "status"::text, "priority"::text
      FROM "WeddingTask" ORDER BY "id";
    `),
    client.$queryRawUnsafe(`
      SELECT "id", "userId", "contactName", "contactPhone", "contactNormalizedPhone",
             "message", "status"::text
      FROM "QuoteRequest" ORDER BY "id";
    `),
    client.$queryRawUnsafe(`
      SELECT "id", "inviterUserId", "inviteeUserId", "name", "phone", "normalizedPhone",
             "email", "tokenHash", "acceptedAt"
      FROM "PlanInvite" ORDER BY "id";
    `),
    client.$queryRawUnsafe(`
      SELECT "id", "name", "normalizedName", "notes" FROM "Guest" ORDER BY "id";
    `),
    client.$queryRawUnsafe(`
      SELECT "id", "title", "partyName", "partyPhone", "totalAmount"::text,
             "paidAmount"::text, "note"
      FROM "WeddingCost" ORDER BY "id";
    `),
  ]);
  return { tasks, quotes, invites, guests, costs };
}

async function contributionRows(client) {
  return client.$queryRawUnsafe(`
    SELECT event."id", event."historyScopeId", event."contributorTenureId",
           event."section"::text, event."entityType"::text, event."entityId",
           event."action"::text, event."snapshot", event."snapshotHash",
           event."dedupeKey", event."eventFingerprint", event."provenance"::text,
           event."requiredPermission"::text, event."authorityVersion",
           tenure."actorUserId", tenure."actorReference"
    FROM "ContributionEvent" AS event
    JOIN "ContributorTenure" AS tenure ON tenure."id" = event."contributorTenureId"
    ORDER BY event."entityId";
  `);
}

async function assertEvidenceOnlyBackfill(client, migrationStartedAt, migrationFinishedAt) {
  const scopes = await client.$queryRawUnsafe(`
    SELECT "weddingPlanId", "status"::text, "historyCoverageStartsAt", "archivedAt"
    FROM "ContributorHistoryScope" ORDER BY "weddingPlanId";
  `);
  assert.equal(scopes.length, 2);
  const primaryScope = scopes.find((scope) => scope.weddingPlanId === fixture.primaryPlanId);
  const archivedScope = scopes.find((scope) => scope.weddingPlanId === fixture.archivedPlanId);
  assert.equal(primaryScope?.status, 'ACTIVE');
  assert.equal(primaryScope?.archivedAt, null);
  assert.equal(archivedScope?.status, 'ARCHIVED');
  assert.ok(archivedScope?.archivedAt instanceof Date);
  for (const scope of scopes) {
    assert.ok(scope.historyCoverageStartsAt >= migrationStartedAt);
    assert.ok(scope.historyCoverageStartsAt <= migrationFinishedAt);
  }

  const tenures = await client.$queryRawUnsafe(`
    SELECT "actorUserId", "actorReference", "sharedMemberId", "endedAt", "endReason"::text
    FROM "ContributorTenure" ORDER BY "actorUserId";
  `);
  assert.equal(tenures.length, 2);
  assert.deepEqual(
    tenures.map((tenure) => tenure.actorUserId),
    [fixture.contributorAUserId, fixture.contributorBUserId],
  );
  for (const tenure of tenures) {
    assert.equal(tenure.endedAt, null);
    assert.equal(tenure.endReason, null);
    assert.ok(tenure.sharedMemberId);
    assert.equal(tenure.actorReference, sha256(tenure.actorUserId));
  }

  const events = await contributionRows(client);
  assert.equal(events.length, 4, 'only direct task, quote, and inviter evidence is backfilled');
  const expected = new Map([
    [fixture.taskAId, [fixture.contributorAUserId, 'TASK', 'MANAGE_TASKS']],
    [fixture.taskBId, [fixture.contributorBUserId, 'TASK', 'MANAGE_TASKS']],
    [fixture.quoteAId, [fixture.contributorAUserId, 'QUOTE_REQUEST', 'MANAGE_PROVIDERS']],
    [fixture.inviteAId, [fixture.contributorAUserId, 'PLAN_INVITE', 'MANAGE_MEMBERS']],
  ]);
  for (const event of events) {
    const expectedEvent = expected.get(event.entityId);
    assert.ok(expectedEvent, `unexpected legacy event for ${event.entityId}`);
    assert.equal(event.actorUserId, expectedEvent[0]);
    assert.equal(event.entityType, expectedEvent[1]);
    assert.equal(event.requiredPermission, expectedEvent[2]);
    assert.equal(event.action, 'LEGACY_CAPTURED');
    assert.equal(event.provenance, 'LEGACY_EXPLICIT');
    assert.equal(event.authorityVersion, 1);
  }

  const forbiddenEntityIds = [
    fixture.ownerTaskId,
    fixture.unassignedTaskId,
    fixture.ownerQuoteId,
    fixture.ownerInviteId,
    fixture.guestId,
    fixture.categoryId,
    fixture.costId,
  ];
  for (const entityId of forbiddenEntityIds) {
    assert.equal(
      events.some((event) => event.entityId === entityId),
      false,
      `legacy row ${entityId} must remain unattributed`,
    );
  }
  const inviteEvent = events.find((event) => event.entityId === fixture.inviteAId);
  assert.equal(inviteEvent.actorUserId, fixture.contributorAUserId);
  assert.equal(
    events.some(
      (event) =>
        event.entityId === fixture.inviteAId &&
        event.actorUserId === fixture.contributorBUserId,
    ),
    false,
    'accepted membership must not be guessed as an invite contribution',
  );
  return events;
}

function assertCanonicalHashes(events) {
  const evidenceLabel = new Map([
    ['TASK', 'LEGACY_CONFIRMED_ASSIGNMENT'],
    ['QUOTE_REQUEST', 'LEGACY_CONFIRMED_CREATION'],
    ['PLAN_INVITE', 'LEGACY_CONFIRMED_INVITER'],
  ]);
  for (const event of events) {
    const canonicalSnapshot = canonicalJson(event.snapshot);
    assert.equal(event.snapshotHash, sha256(canonicalSnapshot));
    assert.equal(event.actorReference, sha256(event.actorUserId));
    assert.equal(
      event.eventFingerprint,
      sha256(
        `${event.contributorTenureId}:${event.actorReference}:` +
          `${evidenceLabel.get(event.entityType)}:${event.entityId}:` +
          canonicalSnapshot,
      ),
    );
  }
}

function normalizedDigits(value) {
  return value.replace(/[٠-٩۰-۹]/g, (digit) => {
    const code = digit.charCodeAt(0);
    return String(code >= 0x06f0 ? code - 0x06f0 : code - 0x0660);
  });
}

function assertSnapshotContainsNoSensitiveData(value, key = 'snapshot') {
  assert.doesNotMatch(
    key,
    /(phone|email|token|secret|message|note|attachment|method|address|contact|payload|header|query|body)/i,
  );
  if (typeof value === 'string') {
    const normalized = normalizedDigits(value);
    for (const pattern of [
      /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,
      /\bBearer\s+[A-Za-z0-9._~-]+/i,
      /[?&](?:token|key|secret|signature)=/i,
      /(?:^|\s)\+\d(?:[\s()-]*\d){7,14}(?:$|\s)/,
      /(?:^|[^\d])(?:967[\s().-]*)?7(?:[\s().-]*\d){8}(?!\d)/,
      /^\s*(?:\d[\s()-]*){8,15}\s*$/,
    ]) {
      assert.doesNotMatch(normalized, pattern);
    }
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item) => assertSnapshotContainsNoSensitiveData(item, key));
    return;
  }
  if (value !== null && typeof value === 'object') {
    for (const [nestedKey, nestedValue] of Object.entries(value)) {
      assertSnapshotContainsNoSensitiveData(nestedValue, nestedKey);
    }
  }
}

function assertPrivacySanitization(events) {
  for (const event of events) {
    assertSnapshotContainsNoSensitiveData(event.snapshot);
    const serialized = JSON.stringify(event.snapshot);
    for (const forbidden of [
      fixture.privatePhone,
      fixture.privateEmail,
      fixture.privateToken,
      fixture.unsafeTaskTitle,
      fixture.unsafeInviteName,
      'private quote body',
    ]) {
      assert.equal(serialized.includes(forbidden), false);
    }
  }
  const unsafeTask = events.find((event) => event.entityId === fixture.taskAId);
  assert.equal(Object.hasOwn(unsafeTask.snapshot, 'title'), false);
  const safeTask = events.find((event) => event.entityId === fixture.taskBId);
  assert.equal(safeTask.snapshot.title, fixture.safeTaskTitle);
  const invite = events.find((event) => event.entityId === fixture.inviteAId);
  assert.equal(Object.hasOwn(invite.snapshot, 'displayName'), false);
  const quote = events.find((event) => event.entityId === fixture.quoteAId);
  assert.deepEqual(Object.keys(quote.snapshot).sort(), ['requestStatus', 'status']);
}

async function rejectionFrom(operation, pattern) {
  let captured;
  try {
    await operation();
  } catch (error) {
    captured = error;
  }
  assert.ok(captured, 'database operation must be rejected');
  assert.match(captured instanceof Error ? captured.message : String(captured), pattern);
}

async function assertAppendOnlyAndConstraints(client, events) {
  const event = events.find((candidate) => candidate.entityId === fixture.taskAId);
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `UPDATE "ContributionEvent" SET "capturedAt" = CURRENT_TIMESTAMP WHERE "id" = $1;`,
      event.id,
    ),
    /ContributionEvent is append-only/,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `DELETE FROM "ContributionEvent" WHERE "id" = $1;`,
      event.id,
    ),
    /ContributionEvent is append-only/,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `
        INSERT INTO "ContributionEvent" (
          "id", "historyScopeId", "contributorTenureId", "section", "entityType",
          "entityId", "action", "snapshot", "snapshotHash", "dedupeKey",
          "eventFingerprint", "provenance", "requiredPermission", "authorityVersion"
        )
        SELECT 'invalid-section-event', "historyScopeId", "contributorTenureId",
          'GUESTS', 'TASK', 'invalid-section', 'CREATED', '{}'::jsonb,
          repeat('a', 64), 'constraint:invalid-section', repeat('b', 64),
          'RUNTIME', 'MANAGE_GUESTS', 1
        FROM "ContributionEvent" WHERE "id" = $1;
      `,
      event.id,
    ),
    /ContributionEvent_section_entity_check/,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `
        INSERT INTO "ContributionEvent" (
          "id", "historyScopeId", "contributorTenureId", "section", "entityType",
          "entityId", "action", "snapshot", "snapshotHash", "dedupeKey",
          "eventFingerprint", "provenance", "requiredPermission", "authorityVersion"
        )
        SELECT 'oversize-snapshot-event', "historyScopeId", "contributorTenureId",
          'TASKS', 'TASK', 'oversize-snapshot', 'CREATED',
          jsonb_build_object('title', repeat('x', 17000)), repeat('a', 64),
          'constraint:oversize', repeat('b', 64), 'RUNTIME', 'MANAGE_TASKS', 1
        FROM "ContributionEvent" WHERE "id" = $1;
      `,
      event.id,
    ),
    /ContributionEvent_snapshot_size_check/,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `
        INSERT INTO "ContributionEvent" (
          "id", "historyScopeId", "contributorTenureId", "section", "entityType",
          "entityId", "action", "snapshot", "snapshotHash", "dedupeKey",
          "eventFingerprint", "provenance", "requiredPermission", "authorityVersion"
        )
        SELECT 'invalid-hash-event', "historyScopeId", "contributorTenureId",
          'TASKS', 'TASK', 'invalid-hash', 'CREATED', '{}'::jsonb, 'bad',
          'constraint:invalid-hash', repeat('b', 64), 'RUNTIME', 'MANAGE_TASKS', 1
        FROM "ContributionEvent" WHERE "id" = $1;
      `,
      event.id,
    ),
    /ContributionEvent_snapshot_hash_check/,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `
        INSERT INTO "ContributionEvent" (
          "id", "historyScopeId", "contributorTenureId", "section", "entityType",
          "entityId", "action", "snapshot", "snapshotHash", "dedupeKey",
          "eventFingerprint", "provenance", "requiredPermission", "permissionPolicyVersion",
          "authorityVersion", "occurredAt", "capturedAt"
        )
        SELECT 'duplicate-dedupe-event', "historyScopeId", "contributorTenureId",
          "section", "entityType", "entityId", "action", "snapshot", "snapshotHash",
          "dedupeKey", "eventFingerprint", "provenance", "requiredPermission",
          "permissionPolicyVersion", "authorityVersion", "occurredAt", CURRENT_TIMESTAMP
        FROM "ContributionEvent" WHERE "id" = $1;
      `,
      event.id,
    ),
    /23505|contributorTenureId.*dedupeKey/s,
  );

  const contributorB = events.find(
    (candidate) => candidate.actorUserId === fixture.contributorBUserId,
  );
  const crossTenureFingerprint = sha256(
    `${contributorB.contributorTenureId}:${contributorB.actorReference}:` +
      `LEGACY_CONFIRMED_ASSIGNMENT:${event.entityId}:` +
      canonicalJson(event.snapshot),
  );
  await client.$executeRawUnsafe(
    `
      INSERT INTO "ContributionEvent" (
        "id", "historyScopeId", "contributorTenureId", "section", "entityType",
        "entityId", "action", "snapshot", "snapshotHash", "dedupeKey",
        "eventFingerprint", "provenance", "requiredPermission", "permissionPolicyVersion",
        "authorityVersion", "occurredAt", "capturedAt"
      )
      SELECT 'same-dedupe-different-tenure', "historyScopeId", $2,
        "section", "entityType", "entityId", "action", "snapshot", "snapshotHash",
        "dedupeKey", $3, "provenance", "requiredPermission",
        "permissionPolicyVersion", "authorityVersion", "occurredAt", CURRENT_TIMESTAMP
      FROM "ContributionEvent" WHERE "id" = $1;
    `,
    event.id,
    contributorB.contributorTenureId,
    crossTenureFingerprint,
  );

  await client.$executeRawUnsafe(
    `
      INSERT INTO "User" ("id", "name", "passwordHash", "createdAt", "updatedAt")
      VALUES ($1, 'Post Migration Contributor C', 'hash', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
    `,
    fixture.contributorCUserId,
  );
  await client.$executeRawUnsafe(
    `
      INSERT INTO "SharedMember" (
        "id", "weddingPlanId", "userId", "role", "createdAt", "updatedAt"
      ) VALUES ($1, $2, $3, 'CONTRIBUTOR', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
    `,
    fixture.memberCId,
    fixture.primaryPlanId,
    fixture.contributorCUserId,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `
        INSERT INTO "ContributorTenure" (
          "id", "historyScopeId", "actorUserId", "actorReference", "sharedMemberId",
          "joinedAt", "trackingStartedAt", "roleAtTrackingStart", "updatedAt"
        )
        SELECT 'duplicate-active-reference', scope."id", $1, $2, $3,
          CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CONTRIBUTOR', CURRENT_TIMESTAMP
        FROM "ContributorHistoryScope" AS scope WHERE scope."weddingPlanId" = $4;
      `,
      fixture.contributorCUserId,
      sha256(fixture.contributorAUserId),
      fixture.memberCId,
      fixture.primaryPlanId,
    ),
    /23505|historyScopeId.*actorReference/s,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `
        INSERT INTO "ContributorTenure" (
          "id", "historyScopeId", "actorUserId", "actorReference", "sharedMemberId",
          "joinedAt", "trackingStartedAt", "endedAt", "endReason",
          "roleAtTrackingStart", "updatedAt"
        )
        SELECT 'invalid-tenure-lifecycle', scope."id", $1, $2, $3,
          CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'MEMBER_LEFT',
          'CONTRIBUTOR', CURRENT_TIMESTAMP
        FROM "ContributorHistoryScope" AS scope WHERE scope."weddingPlanId" = $4;
      `,
      fixture.contributorCUserId,
      sha256(fixture.contributorCUserId),
      fixture.memberCId,
      fixture.primaryPlanId,
    ),
    /ContributorTenure_lifecycle_check/,
  );

  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `UPDATE "ContributorTenure" SET "actorReference" = repeat('f', 64) WHERE "id" = $1;`,
      contributorB.contributorTenureId,
    ),
    /ContributorTenure identity fields are immutable/,
  );
  await client.$executeRawUnsafe(
    `
      UPDATE "ContributorTenure"
      SET "endedAt" = CURRENT_TIMESTAMP,
          "endReason" = 'MEMBER_LEFT',
          "roleAtEnd" = 'CONTRIBUTOR',
          "sharedMemberId" = NULL,
          "updatedAt" = CURRENT_TIMESTAMP
      WHERE "id" = $1;
    `,
    contributorB.contributorTenureId,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `UPDATE "ContributorTenure" SET "endReason" = 'MEMBER_REMOVED' WHERE "id" = $1;`,
      contributorB.contributorTenureId,
    ),
    /ContributorTenure lifecycle transition is invalid/,
  );
  await client.$executeRawUnsafe(
    `UPDATE "ContributorTenure" SET "actorUserId" = NULL WHERE "id" = $1;`,
    contributorB.contributorTenureId,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `UPDATE "ContributorTenure" SET "actorUserId" = $2 WHERE "id" = $1;`,
      contributorB.contributorTenureId,
      fixture.contributorBUserId,
    ),
    /ContributorTenure identity fields are immutable/,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `DELETE FROM "ContributorTenure" WHERE "id" = $1;`,
      contributorB.contributorTenureId,
    ),
    /ContributorTenure is immutable and cannot be deleted/,
  );
}

async function assertSourceRowsUnchanged(client, beforeMigration) {
  assert.deepEqual(await captureLegacySourceRows(client), beforeMigration);
}

async function assertAccountDeletionReceiptMigration(client) {
  assert.equal(await tableExists(client, 'AccountDeletionReceipt'), true);

  const columns = await client.$queryRawUnsafe(`
    SELECT column_name AS "columnName"
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'AccountDeletionReceipt'
    ORDER BY ordinal_position;
  `);
  assert.deepEqual(
    columns.map((column) => column.columnName),
    ['receiptHash', 'deletedAt'],
    'the receipt table must contain no source account or request identifier',
  );

  const triggers = await client.$queryRawUnsafe(`
    SELECT trigger_name AS "triggerName"
    FROM information_schema.triggers
    WHERE event_object_schema = 'public'
      AND event_object_table = 'AccountDeletionReceipt'
    ORDER BY trigger_name;
  `);
  assert.deepEqual(
    triggers.map((trigger) => trigger.triggerName),
    [
      'AccountDeletionReceipt_immutable_delete',
      'AccountDeletionReceipt_immutable_update',
    ],
  );

  const receiptHash = 'd'.repeat(64);
  await client.$executeRawUnsafe(
    `INSERT INTO "AccountDeletionReceipt" ("receiptHash") VALUES ($1);`,
    receiptHash,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `UPDATE "AccountDeletionReceipt" SET "deletedAt" = CURRENT_TIMESTAMP WHERE "receiptHash" = $1;`,
      receiptHash,
    ),
    /Account deletion receipts are immutable/,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `DELETE FROM "AccountDeletionReceipt" WHERE "receiptHash" = $1;`,
      receiptHash,
    ),
    /Account deletion receipts are immutable/,
  );
  await rejectionFrom(
    () => client.$executeRawUnsafe(
      `INSERT INTO "AccountDeletionReceipt" ("receiptHash") VALUES ('invalid');`,
    ),
    /AccountDeletionReceipt_hash_check/,
  );
  const receipts = await client.$queryRawUnsafe(
    `SELECT "receiptHash" FROM "AccountDeletionReceipt" ORDER BY "receiptHash";`,
  );
  assert.deepEqual(receipts, [{ receiptHash }]);
}

async function assertMigrationCatalog(client, expectedCount, targetMigrations) {
  const applied = await appliedMigrations(client);
  assert.equal(applied.length, expectedCount);
  for (const migrationName of targetMigrations) {
    const target = applied.find((row) => row.migrationName === migrationName);
    assert.ok(target?.finishedAt instanceof Date, migrationName);
    assert.equal(target?.rolledBackAt, null, migrationName);
  }
}

async function main() {
  assertManagedSmokeEnvironment(process.env);
  const workspace = createMigrationWorkspace();
  let client;
  try {
    deployMigrations(workspace.schemaPath);
    client = new PrismaClient();
    await assertPreMigrationState(client, workspace.previousMigrations);
    await seedLegacyFixtures(client);
    const sourceBeforeMigration = await captureLegacySourceRows(client);
    await client.$disconnect();
    client = undefined;

    addTargetMigration(workspace);
    const migrationStartedAt = new Date();
    deployMigrations(workspace.schemaPath);
    const migrationFinishedAt = new Date();

    client = new PrismaClient();
    await assertMigrationCatalog(
      client,
      workspace.previousMigrations.length + 1,
      [TARGET_MIGRATION],
    );
    const events = await assertEvidenceOnlyBackfill(
      client,
      migrationStartedAt,
      migrationFinishedAt,
    );
    assertCanonicalHashes(events);
    assertPrivacySanitization(events);
    await assertSourceRowsUnchanged(client, sourceBeforeMigration);
    await assertAppendOnlyAndConstraints(client, events);

    addTargetMigration(workspace, RECEIPT_MIGRATION);
    deployMigrations(workspace.schemaPath);
    deployMigrations(workspace.schemaPath);
    await assertMigrationCatalog(
      client,
      workspace.previousMigrations.length + 2,
      [TARGET_MIGRATION, RECEIPT_MIGRATION],
    );
    await assertAccountDeletionReceiptMigration(client);

    console.log(
      'PASS - coordinated contributor history and account deletion receipt migrations upgrade a populated legacy database with evidence-only history, immutable records, enforced constraints, and a clean second pass.',
    );
  } finally {
    await client?.$disconnect();
    cleanupMigrationWorkspace(workspace.root);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`ERROR - ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
  });
}

module.exports = {
  RECEIPT_MIGRATION,
  TARGET_MIGRATION,
  assertAccountDeletionReceiptMigration,
  assertAppendOnlyAndConstraints,
  assertCanonicalHashes,
  assertEvidenceOnlyBackfill,
  assertPreMigrationState,
  assertPrivacySanitization,
  canonicalJson,
  seedLegacyFixtures,
};
