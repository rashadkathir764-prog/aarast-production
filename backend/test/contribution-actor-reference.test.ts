import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash, createHmac } from "node:crypto";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionSection,
} from "@prisma/client";
import { contributorActorReference } from "../src/modules/collaboration/internal/contribution-history.service";
import { ContributorScopeService } from "../src/modules/collaboration/internal/contributor-scope.service";
import { validateRuntimeEnvironment } from "../src/platform/config/runtime-environment";
import { getJwtSecret } from "../src/modules/identity/internal/auth/jwt-secret";
import { contributionHistoryService } from "./support/owner-ports";

// RA-BE-176: the history named its actor by SHA-256 of the user id, with no
// secret, so anyone holding an erased account's id could find what it did.
// The reference is now an HMAC-SHA256 under a server secret. The rows written
// before stay as they are (the tenure's reference cannot change), so a living
// member is found by the tenure's live link to the account, not by recomputing
// a reference.

const TEST_SECRET = "contribution-actor-reference-test-secret-0123456789";
process.env.CONTRIBUTION_ACTOR_REF_SECRET = TEST_SECRET;

const sha256 = (value: string) => createHash("sha256").update(value).digest("hex");
const hmac = (secret: string, value: string) =>
  createHmac("sha256", secret).update(value).digest("hex");

function withEnvironment<T>(changes: Record<string, string | undefined>, run: () => T): T {
  const previous = Object.fromEntries(Object.keys(changes).map((key) => [key, process.env[key]]));
  for (const [key, value] of Object.entries(changes)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    return run();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

test("RA-BE-176: the actor reference is HMAC-SHA256 of the user id under the server secret", () => {
  const reference = contributorActorReference("user-1");
  assert.equal(reference, hmac(TEST_SECRET, "user-1"));
  assert.notEqual(reference, sha256("user-1"));
  assert.match(reference, /^[0-9a-f]{64}$/);
  const otherSecret = withEnvironment(
    { CONTRIBUTION_ACTOR_REF_SECRET: "another-secret-another-secret-another" },
    () => contributorActorReference("user-1"),
  );
  assert.notEqual(otherSecret, reference);
});

const productionEnvironment = {
  NODE_ENV: "production",
  DATABASE_URL: "postgresql://runtime.invalid/aarast",
  JWT_SECRET: "Q7mX2pL9vR4nK8tY1cF6hJ3wB5zD0sG7aE2uM9qT4rN8",
  AUTH_OTP_MODE: "disabled",
  AUTH_LOGIN_THROTTLE_PEPPER: "Y9pM4vQ7xD2kR8nT5cF1hJ6wB3zL0sG4",
  INVITE_PUBLIC_ORIGIN: "https://aarast.example.org",
  // Changed on purpose (RA-BE-176): 32 characters, the least production takes.
  CONTRIBUTION_ACTOR_REF_SECRET: "P3kW8nB1xV6cR9tL2mF5hQ7jD0sZ4gAe",
};

test("RA-BE-176: production does not start without CONTRIBUTION_ACTOR_REF_SECRET", () => {
  assert.doesNotThrow(() => validateRuntimeEnvironment(productionEnvironment, getJwtSecret));
  for (const missing of [undefined, "   "]) {
    assert.throws(
      () =>
        validateRuntimeEnvironment(
          { ...productionEnvironment, CONTRIBUTION_ACTOR_REF_SECRET: missing },
          getJwtSecret,
        ),
      /CONTRIBUTION_ACTOR_REF_SECRET is required in production/,
    );
  }
  // And a production process that somehow skipped the check refers to no one.
  assert.throws(
    () =>
      withEnvironment({ NODE_ENV: "production", CONTRIBUTION_ACTOR_REF_SECRET: undefined }, () =>
        contributorActorReference("user-1"),
      ),
    /CONTRIBUTION_ACTOR_REF_SECRET/,
  );
});

// A placeholder or a short value left in production would key every actor
// reference with a value anyone can guess, for good: the key never changes.
test("RA-BE-176: production refuses a short or placeholder CONTRIBUTION_ACTOR_REF_SECRET", () => {
  for (const weak of [
    "P3kW8nB1xV6cR9tL2mF5hQ7jD0sZ4gA",
    "replace-with-a-separate-random-contribution-history-secret",
    "replace-with-at-least-32-random-characters",
    "change-me-change-me-change-me-change-me",
    "an-example-contribution-actor-reference-secret",
  ]) {
    assert.throws(
      () =>
        validateRuntimeEnvironment(
          { ...productionEnvironment, CONTRIBUTION_ACTOR_REF_SECRET: weak },
          getJwtSecret,
        ),
      (error: Error) => {
        assert.match(error.message, /CONTRIBUTION_ACTOR_REF_SECRET must be at least 32 random characters in production/);
        assert.doesNotMatch(error.message, new RegExp(weak));
        return true;
      },
      weak,
    );
  }
  // Outside production a short value is still taken (tests, a laptop).
  assert.doesNotThrow(() =>
    validateRuntimeEnvironment(
      {
        ...productionEnvironment,
        NODE_ENV: "development",
        AUTH_OTP_MODE: "dev",
        CONTRIBUTION_ACTOR_REF_SECRET: "short",
      },
      getJwtSecret,
    ),
  );
});

type Row = Record<string, unknown>;

function matches(row: Row, where: Row): boolean {
  return Object.entries(where).every(([key, condition]) => {
    if (key === "OR") return (condition as Row[]).some((branch) => matches(row, branch));
    if (condition !== null && typeof condition === "object") {
      throw new Error(`The fake tenure table does not know the filter on "${key}"`);
    }
    return (row[key] ?? null) === condition;
  });
}

/**
 * A member who joined before the change: her open tenure carries the old
 * SHA-256 reference, which the database never lets change.
 */
function memberWrittenBefore() {
  const member = {
    id: "member-1",
    weddingPlanId: "plan-1",
    userId: "user-1",
    role: "EDITOR",
    authorityVersion: 1,
    createdAt: new Date("2026-08-01T10:00:00.000Z"),
  };
  const tenures: Row[] = [
    {
      id: "tenure-before",
      historyScopeId: "scope-1",
      actorUserId: "user-1",
      actorReference: sha256("user-1"),
      sharedMemberId: "member-1",
      endedAt: null,
    },
  ];
  const events: Row[] = [
    {
      id: "event-before",
      historyScopeId: "scope-1",
      contributorTenureId: "tenure-before",
      section: ContributionSection.TASKS,
      entityType: ContributionEntityType.TASK,
      entityId: "task-before",
      action: ContributionAction.CREATED,
      capturedAt: new Date("2026-08-02T10:00:00.000Z"),
    },
  ];
  const tenureOf = (event: Row) => tenures.find((tenure) => tenure.id === event.contributorTenureId)!;
  const eventMatches = (event: Row, where: Row) =>
    !where.contributorTenure || matches(tenureOf(event), where.contributorTenure as Row);
  const created: Row[] = [];
  const tx: any = {
    contributorHistoryScope: {
      findUnique: async () => ({ id: "scope-1" }),
      findFirst: async () => ({
        id: "scope-1",
        historyCoverageStartsAt: new Date("2026-08-01T09:00:00.000Z"),
      }),
      upsert: async () => ({ id: "scope-1" }),
    },
    contributorTenure: {
      findFirst: async ({ where }: { where: Row }) =>
        tenures.find((tenure) => matches(tenure, where)) ?? null,
      create: async ({ data }: { data: Row }) => {
        if (tenures.some((tenure) => tenure.sharedMemberId === data.sharedMemberId)) {
          throw new Error("Unique constraint failed on ContributorTenure.sharedMemberId");
        }
        const tenure = { id: `tenure-${created.length + 1}`, endedAt: null, ...data };
        created.push(tenure);
        tenures.push(tenure);
        return tenure;
      },
    },
    contributionEvent: {
      findMany: async ({ where }: { where: Row }) =>
        events.filter((event) => eventMatches(event, where)).map((event) => ({
          ...event,
          contributorTenure: { actorReference: tenureOf(event).actorReference },
        })),
      count: async ({ where }: { where: Row }) =>
        events.filter((event) => eventMatches(event, where)).length,
      createManyAndReturn: async ({ data }: { data: Row[] }) => {
        const event = { id: `event-${events.length + 1}`, capturedAt: new Date(), ...data[0] };
        events.push(event);
        return [event];
      },
    },
    weddingPlan: { findUnique: async () => ({ id: "plan-1", ownerUserId: "owner-1" }) },
    sharedMember: {
      findUnique: async ({ where }: { where: { weddingPlanId_userId: { userId: string } } }) =>
        where.weddingPlanId_userId.userId === member.userId ? member : null,
      findFirst: async () => ({ id: member.id }),
    },
  };
  tx.$transaction = async (operation: (client: unknown) => Promise<unknown>) => operation(tx);
  return { member, tenures, events, created, tx };
}

test("RA-BE-176: a member whose tenure was written before keeps it and goes on recording", async () => {
  const { member, created, events, tx } = memberWrittenBefore();
  const history = contributionHistoryService(tx);

  const tenure = await history.ensureTenureInTransaction(tx, member as never);
  assert.equal(tenure.id, "tenure-before");
  assert.equal(created.length, 0);

  await history.recordInTransaction(tx, {
    weddingPlanId: "plan-1",
    actorUserId: "user-1",
    section: ContributionSection.TASKS,
    entityType: ContributionEntityType.TASK,
    entityId: "task-after",
    action: ContributionAction.CREATED,
    snapshot: { title: "Task", status: "TODO" },
    dedupeKey: "task:task-after:created",
    provenance: ContributionProvenance.RUNTIME,
    authorityVersion: 1,
  });
  assert.equal(events[events.length - 1].contributorTenureId, "tenure-before");
});

test("RA-BE-176: what a member did before the change still counts as hers", async () => {
  const { tx } = memberWrittenBefore();
  const history = contributionHistoryService(tx);
  const scope = new ContributorScopeService(history);

  assert.deepEqual(
    await history.qualifyingEntityIds("plan-1", "user-1", [ContributionEntityType.TASK]),
    ["task-before"],
  );
  assert.deepEqual(
    await scope.qualifyingEntityIdsInTransaction(tx, "plan-1", "user-1", [ContributionEntityType.TASK]),
    ["task-before"],
  );
  assert.deepEqual(
    await scope.qualifyingEntityIdsForActorInTransaction(
      tx,
      "user-1",
      [ContributionEntityType.TASK],
      [ContributionAction.CREATED],
    ),
    ["task-before"],
  );
});

test("RA-BE-176: the owner's history of a member holds what she did before the change; her own too", async () => {
  const { tx } = memberWrittenBefore();
  const history = contributionHistoryService(tx);

  const owner = await history.list({ id: "owner-1" } as never, "plan-1", {
    contributorUserId: "user-1",
  });
  assert.deepEqual(owner.events.map((event) => event.id), ["event-before"]);
  assert.equal(owner.events[0].contributorReference, sha256("user-1"));

  const own = await history.list({ id: "user-1" } as never, "plan-1", {});
  assert.deepEqual(own.events.map((event) => event.id), ["event-before"]);
  const summary = await history.summary({ id: "user-1" } as never, "plan-1");
  assert.equal(summary.TASKS, 1);
});

test("RA-BE-176: an erased contributor's history is still found by the owner through the keyed reference", async () => {
  const { tenures, events, tx } = memberWrittenBefore();
  tenures.push({
    id: "tenure-erased",
    historyScopeId: "scope-1",
    actorUserId: null,
    actorReference: contributorActorReference("erased-user"),
    sharedMemberId: null,
    endedAt: new Date("2026-11-01T10:00:00.000Z"),
  });
  events.push({
    id: "event-erased",
    historyScopeId: "scope-1",
    contributorTenureId: "tenure-erased",
    section: ContributionSection.TASKS,
    entityType: ContributionEntityType.TASK,
    entityId: "task-erased",
    action: ContributionAction.CREATED,
    capturedAt: new Date("2026-11-01T09:00:00.000Z"),
  });
  const history = contributionHistoryService(tx);

  const page = await history.list({ id: "owner-1" } as never, "plan-1", {
    contributorUserId: "erased-user",
  });
  assert.deepEqual(page.events.map((event) => event.id), ["event-erased"]);
  assert.equal(page.events[0].contributorReference, hmac(TEST_SECRET, "erased-user"));
});
