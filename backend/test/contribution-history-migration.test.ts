import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import {
  ContributionScopeStatus,
  UserStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import { WeddingPlansService } from "../src/wedding-plans/wedding-plans.service";
import { collaborationHistory, collaborationPermissions, planningOwnerPorts } from "./support/owner-ports";
import { readLivePrismaSchema } from './support/live-prisma-schema';

const read = (path: string) =>
  readFileSync(join(process.cwd(), path), "utf8");

test("contribution history schema keeps only mutable plan, user, and membership links nullable", () => {
  const schema = readLivePrismaSchema();
  const scope =
    schema.match(/model ContributorHistoryScope \{[\s\S]*?\n\}/)?.[0] ?? "";
  const tenure =
    schema.match(/model ContributorTenure \{[\s\S]*?\n\}/)?.[0] ?? "";
  const event =
    schema.match(/model ContributionEvent \{[\s\S]*?\n\}/)?.[0] ?? "";
  const member = schema.match(/model SharedMember \{[\s\S]*?\n\}/)?.[0] ?? "";

  assert.match(scope, /weddingPlanId\s+String\?\s+@unique/);
  assert.match(scope, /onDelete: SetNull/);
  assert.match(tenure, /actorUserId\s+String\?/);
  assert.match(tenure, /actorReference\s+String\s+@db\.Char\(64\)/);
  assert.match(tenure, /sharedMemberId\s+String\?\s+@unique/);
  assert.match(tenure, /actorUser\s+User\?[^\n]*onDelete: SetNull/);
  assert.match(tenure, /sharedMember\s+SharedMember\?[^\n]*onDelete: SetNull/);
  assert.match(event, /historyScopeId\s+String\s/);
  assert.match(event, /contributorTenureId\s+String\s/);
  assert.match(event, /@@unique\(\[contributorTenureId, dedupeKey\]\)/);
  assert.doesNotMatch(event, /@@unique\(\[historyScopeId, dedupeKey\]\)/);
  assert.doesNotMatch(event, /weddingPlan\s+WeddingPlan|actorUser\s+User|sharedMember\s+SharedMember/);
  assert.match(member, /authorityVersion\s+Int\s+@default\(1\)/);
  assert.match(member, /contributorTenure\s+ContributorTenure\?/);
});

test("migration enforces append-only valid events and one active tenure", () => {
  const migration = read(
    "prisma/migrations/20260802090000_add_contributor_history/migration.sql",
  );

  assert.match(migration, /^BEGIN;\s*$/m);
  assert.match(migration, /COMMIT;\s*$/);
  assert.doesNotMatch(migration, /CREATE OR REPLACE FUNCTION/);
  for (const required of [
    "ContributorHistoryScope_lifecycle_check",
    "ContributorTenure_lifecycle_check",
    "ContributorTenure_actor_reference_check",
    "ContributorTenure_one_active_reference_per_scope",
    "ContributionEvent_contributorTenureId_dedupeKey_key",
    "ContributionEvent_snapshot_object_check",
    "ContributionEvent_snapshot_size_check",
    "ContributionEvent_snapshot_hash_check",
    "ContributionEvent_section_entity_check",
    "ContributionEvent_entity_identity_check",
    "ContributionEvent_revocation_shape_check",
    "ContributionEvent_action_provenance_entity_check",
    "ContributionEvent_permission_section_check",
    "ContributionEvent_contributorTenureId_section_entityType_action_entityId_idx",
    "ContributionEvent_append_only",
    "BEFORE UPDATE OR DELETE ON \"ContributionEvent\"",
    "ContributionEvent is append-only",
    "enforce_contributor_tenure_immutability",
    "ContributorTenure_immutable_identity",
    "BEFORE UPDATE OR DELETE ON \"ContributorTenure\"",
    "ContributorTenure identity fields are immutable",
    "ContributorTenure lifecycle transition is invalid",
  ]) {
    assert.equal(migration.includes(required), true, required);
  }
  assert.match(migration, /LOCK TABLE[\s\S]*"PlanInvite"/);
  assert.match(migration, /digest\(member\."userId", 'sha256'\)/);
  assert.match(migration, /canonical_contribution_json/);
  assert.match(migration, /safe_legacy_contribution_text/);
});

test("legacy backfill attributes only direct assignment, creation, and inviter evidence", () => {
  const migration = read(
    "prisma/migrations/20260802090000_add_contributor_history/migration.sql",
  );

  assert.match(
    migration,
    /FROM \"WeddingTask\"[\s\S]*JOIN \"ContributorTenure\"[\s\S]*\"assigneeUserId\"/,
  );
  assert.match(migration, /LEGACY_CONFIRMED_ASSIGNMENT/);
  assert.match(
    migration,
    /FROM \"QuoteRequest\"[\s\S]*JOIN \"ContributorTenure\"[\s\S]*\"userId\"/,
  );
  assert.match(migration, /LEGACY_CONFIRMED_CREATION/);
  assert.match(
    migration,
    /FROM "PlanInvite" AS invite[\s\S]*"inviterUserId"[\s\S]*LEGACY_CONFIRMED_INVITER/,
  );
  assert.doesNotMatch(migration, /accepted_member_history/);
  assert.doesNotMatch(migration, /LEGACY_CONFIRMED_ACCEPTED_MEMBER/);
  assert.doesNotMatch(migration, /legacy:accepted-member/);
  const inviteBackfill = migration.slice(
    migration.indexOf("WITH invite_history AS"),
    migration.indexOf('CREATE FUNCTION "reject_contribution_event_mutation"'),
  );
  assert.doesNotMatch(inviteBackfill, /'phone'|'email'|'tokenHash'/);
  assert.match(migration, /LEGACY_EXPLICIT/);
  assert.match(migration, /legacy_scope_count_mismatch/);
  assert.match(migration, /legacy_current_tenure_count_mismatch/);
  assert.doesNotMatch(
    migration,
    /FROM \"(?:Guest|GuestGroup|WeddingCost|CostPayment|PaymentSchedule|BudgetCategory)\"/,
  );
});

test("every runtime WeddingPlan creation adds its history scope in the same transaction", () => {
  const service = read("src/wedding-plans/wedding-plans.service.ts");
  const createdPlanVariables = [
    ...service.matchAll(
      /const\s+(\w+)\s*=\s*await\s+createWeddingPlan\(tx,\s*\{/g,
    ),
  ].map((match) => match[1]);
  // The history scope is collaboration's row: planning opens it through the
  // collaboration history port on the same transaction, and the owner's
  // implementation creates it ACTIVE from the plan's creation instant.
  const scopedPlanVariables = [
    ...service.matchAll(
      /await\s+this\.contributionHistory\.createHistoryScopeInTransaction\(\s*tx,\s*(\w+),?\s*\);/g,
    ),
  ].map((match) => match[1]);

  assert.equal(createdPlanVariables.length, 3);
  assert.deepEqual(scopedPlanVariables.sort(), createdPlanVariables.sort());
  assert.doesNotMatch(service, /this\.prisma\.weddingPlan\.create\s*\(/);
  assert.match(
    read('src/modules/planning/infrastructure/wedding-plan.repository.ts'),
    /createWeddingPlan\([\s\S]*tx\.weddingPlan\.create\(/,
  );
  assert.doesNotMatch(service, /contributorHistoryScope/);
  const history = read(
    "src/modules/collaboration/internal/contribution-history.service.ts",
  );
  assert.match(
    history,
    /createHistoryScopeInTransaction\([\s\S]*tx:\s*Prisma\.TransactionClient[\s\S]*this\.repository\.createHistoryScope\(tx, plan\)/,
  );
  assert.match(
    read('src/modules/collaboration/infrastructure/contribution-history.repository.ts'),
    /createHistoryScope\([\s\S]*tx\.contributorHistoryScope\.create\([\s\S]*weddingPlanId:\s*plan\.id[\s\S]*status:\s*ContributionScopeStatus\.ACTIVE[\s\S]*historyCoverageStartsAt:\s*plan\.createdAt/,
  );
});

test("create persists plan, ACTIVE history scope, and active selection in one transaction", async () => {
  const operations: string[] = [];
  const createdAt = new Date("2026-08-11T15:00:00.000Z");
  const plan = {
    id: "plan-created",
    ownerUserId: "owner-created",
    title: "Created plan",
    city: null,
    location: null,
    weddingDate: null,
    priorities: [],
    estimatedBudget: null,
    currency: "YER",
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    importMigrationId: null,
    status: WeddingPlanStatus.PLANNING,
    createdAt,
    updatedAt: createdAt,
  };
  let scopeMutation: Record<string, unknown> | undefined;
  const tx = {
    $queryRaw: async () => {
      operations.push("actor:lock");
      return [{ id: plan.ownerUserId, status: UserStatus.ACTIVE }];
    },
    weddingPlan: {
      create: async () => {
        operations.push("plan:create");
        return plan;
      },
    },
    contributorHistoryScope: {
      create: async (mutation: Record<string, unknown>) => {
        operations.push("scope:create");
        scopeMutation = mutation;
        return {};
      },
    },
    user: {
      update: async () => {
        operations.push("user:update");
        return {};
      },
    },
  };
  const service = new WeddingPlansService(
    {
      $transaction: async (work: (client: typeof tx) => Promise<unknown>) => {
        operations.push("transaction:start");
        const result = await work(tx);
        operations.push("transaction:end");
        return result;
      },
    } as any,
    collaborationPermissions({}) as any,
    collaborationHistory({}) as any,
    ...planningOwnerPorts,
  );

  await service.create(
    { id: plan.ownerUserId } as any,
    { title: plan.title },
  );

  assert.deepEqual(operations, [
    "transaction:start",
    "actor:lock",
    "plan:create",
    "scope:create",
    "user:update",
    "transaction:end",
  ]);
  assert.deepEqual(scopeMutation, {
    data: {
      weddingPlanId: plan.id,
      status: ContributionScopeStatus.ACTIVE,
      historyCoverageStartsAt: plan.createdAt,
    },
  });
});

test("repair migration backfills only missing scopes without inventing historical coverage", () => {
  const migration = read(
    "prisma/migrations/20260811180000_backfill_missing_contributor_history_scopes/migration.sql",
  );

  assert.match(migration, /^BEGIN;\s*$/m);
  assert.match(migration, /COMMIT;\s*$/);
  assert.match(
    migration,
    /LOCK TABLE "WeddingPlan", "SharedMember", "ContributorHistoryScope", "ContributorTenure"[\s\S]*IN SHARE ROW EXCLUSIVE MODE/,
  );
  assert.match(migration, /CURRENT_TIMESTAMP AS "backfilledAt"/);
  assert.match(
    migration,
    /WHEN plan\."status" = 'ARCHIVED' THEN 'ARCHIVED'::"ContributionScopeStatus"/,
  );
  assert.match(
    migration,
    /WHEN plan\."status" = 'ARCHIVED' THEN plan\."updatedAt"/,
  );
  assert.match(
    migration,
    /LEFT JOIN "ContributorHistoryScope" AS scope[\s\S]*WHERE scope\."id" IS NULL/,
  );
  assert.match(migration, /ON CONFLICT \("weddingPlanId"\) DO NOTHING/);
  assert.match(migration, /contributor_history_scope_backfill_incomplete/);
  assert.match(migration, /INSERT INTO "ContributorTenure"/);
  assert.match(
    migration,
    /encode\(digest\(member\."userId", 'sha256'\), 'hex'\)/,
  );
  assert.match(
    migration,
    /member\."createdAt"[\s\S]*CURRENT_TIMESTAMP[\s\S]*member\."role"/,
  );
  assert.match(migration, /ON CONFLICT \("sharedMemberId"\) DO NOTHING/);
  assert.match(migration, /contributor_history_scope_status_mismatch/);
  assert.match(migration, /contributor_current_tenure_backfill_incomplete/);
  assert.doesNotMatch(
    migration,
    /"historyCoverageStartsAt"[\s\S]{0,300}plan\."createdAt"/,
  );
});

test("seed creates or repairs the demo plan scope without rewriting coverage", () => {
  // The local demo seed is the only seed (D47); every demo plan is written by
  // seedPlanCore, in one transaction with its contributor history scope.
  const planSeed = read("prisma/demo-seed/plan.ts");
  const core = planSeed.slice(
    planSeed.indexOf("export async function seedPlanCore"),
    planSeed.indexOf("async function seedItem"),
  );
  const planWrite = core.slice(
    core.indexOf("await prisma.$transaction("),
    core.indexOf("await tx.user.update"),
  );

  assert.match(planWrite, /^await prisma\.\$transaction\(\s*async \(tx\) =>/);
  assert.match(planWrite, /await tx\.weddingPlan\.upsert\(/);
  assert.match(planWrite, /await tx\.contributorHistoryScope\.upsert\(/);
  assert.match(
    planWrite,
    /create:\s*\{[\s\S]*weddingPlanId:\s*id,[\s\S]*status:\s*ContributionScopeStatus\.ACTIVE[\s\S]*historyCoverageStartsAt:/,
  );
  const scopeUpsert = planWrite.slice(
    planWrite.indexOf("await tx.contributorHistoryScope.upsert"),
  );
  assert.doesNotMatch(scopeUpsert, /update:[\s\S]*historyCoverageStartsAt/);
});

test("restore verification allows detached history while requiring every live plan scope and tenure", () => {
  const verify = read("../deploy/dokploy/scripts/verify-backup-restore.sh");

  assert.doesNotMatch(
    verify,
    /count\(\*\) FROM "ContributorHistoryScope"\)\s*=\s*\(SELECT count\(\*\) FROM "WeddingPlan"/,
  );
  assert.match(
    verify,
    /FROM "WeddingPlan" AS plan[\s\S]*LEFT JOIN "ContributorHistoryScope" AS scope[\s\S]*WHERE scope\."id" IS NULL/,
  );
  assert.match(
    verify,
    /plan\."status" = '[^\n]*PLANNING[^\n]*scope\."status" <> '[^\n]*ACTIVE/,
  );
  assert.match(
    verify,
    /FROM "SharedMember" AS member[\s\S]*LEFT JOIN "ContributorTenure" AS tenure[\s\S]*tenure\."sharedMemberId" = member\."id"[\s\S]*WHERE tenure\."id" IS NULL/,
  );
  assert.match(
    verify,
    /20260811180000_backfill_missing_contributor_history_scopes/,
  );
  assert.match(
    verify,
    /tenure\."actorReference" = encode\(digest\(member\."userId", '[^\n]*sha256[^\n]*'\), '[^\n]*hex/,
  );
});
