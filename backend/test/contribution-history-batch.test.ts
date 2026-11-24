import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
} from "@prisma/client";
import { buildContributionSnapshot } from "../src/modules/collaboration/public/contribution-snapshot.builder";
import { ContributionHistoryService } from "../src/modules/collaboration/internal/contribution-history.service";

// RA-BE-181: a member who imports guests recorded a contribution per guest,
// and each record looked up the history scope and the member's tenure again
// (about six queries for every guest). The list is recorded under one lookup
// of each; every event is still its own row.

const member = { userId: "member-1", weddingPlanId: "plan-1", authorityVersion: 3 };
const context: any = {
  plan: { id: "plan-1", ownerUserId: "owner-1" },
  isOwner: false,
  sharedMember: member,
};

function harness() {
  const log: string[] = [];
  const events: any[] = [];
  const repository = {
    ensureHistoryScope: async () => {
      log.push("ensureScope");
      return { id: "scope-1" };
    },
    findOpenTenure: async () => {
      log.push("openTenure");
      return { id: "tenure-1", actorReference: "a".repeat(64) };
    },
    getHistoryScopeId: async () => {
      log.push("scope");
      return { id: "scope-1" };
    },
    findActiveTenureId: async () => {
      log.push("tenure");
      return { id: "tenure-1", actorReference: "a".repeat(64) };
    },
    insertContributionEvent: async (_tx: unknown, input: any, scopeId: string, tenureId: string, snapshotHash: string, fingerprint: string) => {
      log.push("insert");
      const row = {
        id: `event-${events.length}`,
        historyScopeId: scopeId,
        contributorTenureId: tenureId,
        snapshotHash,
        eventFingerprint: fingerprint,
        dedupeKey: input.dedupeKey,
      };
      events.push(row);
      return [row];
    },
    findContributionByDedupeKey: async () => null,
  };
  const service: any = new (ContributionHistoryService as any)({}, {}, {}, {}, {});
  service.repository = repository;
  return { service: service as ContributionHistoryService, log, events };
}

const input = (index: number) => ({
  section: ContributionSection.GUESTS,
  entityType: ContributionEntityType.GUEST,
  entityId: `guest-${index}`,
  action: ContributionAction.CREATED,
  snapshot: buildContributionSnapshot(ContributionEntityType.GUEST, {
    displayName: `ضيف ${index}`,
    side: "OTHER",
    invitationStatus: "NOT_SENT",
    attendanceStatus: "PENDING",
  }),
  dedupeKey: `guest:guest-${index}:created`,
  requiredPermission: ContributionPermission.MANAGE_GUESTS,
});

test("a member's list is recorded under one scope and one tenure lookup", async () => {
  const { service, log, events } = harness();
  await service.recordManyForContextInTransaction(
    {} as any,
    context,
    Array.from({ length: 40 }, (_, index) => input(index)),
  );
  assert.equal(events.length, 40, "every guest is its own event");
  assert.equal(log.filter((entry) => entry === "scope").length, 1);
  assert.equal(log.filter((entry) => entry === "tenure").length, 1);
  assert.equal(log.filter((entry) => entry === "ensureScope").length, 1);
  assert.equal(log.filter((entry) => entry === "insert").length, 40);
  assert.equal(log.length, 44);
});

test("the owner records nothing, and an empty list asks nothing", async () => {
  const owner = harness();
  await owner.service.recordManyForContextInTransaction(
    {} as any,
    { ...context, isOwner: true, sharedMember: null },
    [input(0)],
  );
  assert.deepEqual(owner.log, []);
  const empty = harness();
  await empty.service.recordManyForContextInTransaction({} as any, context, []);
  assert.deepEqual(empty.log, []);
});
