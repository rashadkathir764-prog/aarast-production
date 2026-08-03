import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const read = (path: string) =>
  readFileSync(join(process.cwd(), path), "utf8");

test("contribution history schema keeps only mutable plan, user, and membership links nullable", () => {
  const schema = read("prisma/schema.prisma");
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
