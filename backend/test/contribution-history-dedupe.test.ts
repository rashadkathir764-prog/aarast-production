import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionSection,
} from "@prisma/client";
import { ConflictException } from "@nestjs/common";
import {
  canonicalJson,
  hashContributionSnapshot,
} from "../src/modules/collaboration/public/contribution-snapshot.builder";
import { ContributionHistoryService } from "../src/modules/collaboration/internal/contribution-history.service";

test("canonical snapshot JSON and SHA-256 do not depend on object key order", () => {
  const left = { status: "DONE", title: "Task", priority: "HIGH" };
  const right = { priority: "HIGH", title: "Task", status: "DONE" };

  assert.equal(canonicalJson(left), canonicalJson(right));
  assert.equal(hashContributionSnapshot(left), hashContributionSnapshot(right));
  assert.match(hashContributionSnapshot(left), /^[a-f0-9]{64}$/);
});

const contributionInput = (overrides: Record<string, unknown> = {}) => ({
  weddingPlanId: "plan-1",
  actorUserId: "user-1",
  section: ContributionSection.TASKS,
  entityType: ContributionEntityType.TASK,
  entityId: "task-1",
  action: ContributionAction.CREATED,
  snapshot: { title: "Task", status: "TODO" },
  dedupeKey: "task:task-1:created",
  provenance: ContributionProvenance.RUNTIME,
  permissionPolicyVersion: 1,
  authorityVersion: 4,
  occurredAt: null,
  ...overrides,
});

test("recordInTransaction uses an append-only createManyAndReturn race-safe replay", async () => {
  let stored: any = null;
  let insertAttempts = 0;
  let reads = 0;
  const tx = {
    contributorHistoryScope: { findUnique: async () => ({ id: "scope-1" }) },
    contributorTenure: {
      findFirst: async () => ({ id: "tenure-1", actorReference: "a".repeat(64) }),
    },
    contributionEvent: {
      createManyAndReturn: async ({ data, skipDuplicates }: any) => {
        insertAttempts += 1;
        assert.equal(skipDuplicates, true);
        assert.equal(data.length, 1);
        if (stored) return [];
        stored = {
          id: "event-1",
          ...data[0],
          capturedAt: new Date("2026-08-02T10:00:00.000Z"),
        };
        return [stored];
      },
      findUnique: async ({ where }: any) => {
        reads += 1;
        assert.deepEqual(where, {
          contributorTenureId_dedupeKey: {
            contributorTenureId: "tenure-1",
            dedupeKey: "task:task-1:created",
          },
        });
        return stored;
      },
    },
  };
  const service = new ContributionHistoryService({} as any);

  const created = await service.recordInTransaction(tx as any, contributionInput() as any);
  const replayed = await service.recordInTransaction(tx as any, contributionInput() as any);

  assert.equal(replayed, created);
  assert.equal(insertAttempts, 2);
  assert.equal(reads, 1);
  assert.match(created.eventFingerprint, /^[a-f0-9]{64}$/);
  assert.equal("create" in tx.contributionEvent, false);
  assert.equal("update" in tx.contributionEvent, false);
});

test("recordInTransaction rejects a conflicting fingerprint for the same tenure dedupe key", async () => {
  let stored: any = null;
  const tx = {
    contributorHistoryScope: { findUnique: async () => ({ id: "scope-1" }) },
    contributorTenure: {
      findFirst: async () => ({ id: "tenure-1", actorReference: "a".repeat(64) }),
    },
    contributionEvent: {
      createManyAndReturn: async ({ data }: any) => {
        if (stored) return [];
        stored = { id: "event-1", ...data[0], capturedAt: new Date() };
        return [stored];
      },
      findUnique: async () => stored,
    },
  };
  const service = new ContributionHistoryService({} as any);
  await service.recordInTransaction(tx as any, contributionInput() as any);

  await assert.rejects(
    () => service.recordInTransaction(tx as any, contributionInput({
      action: ContributionAction.UPDATED,
      snapshot: { title: "Changed" },
    }) as any),
    ConflictException,
  );
});

test("the same dedupe key is independent across tenures and fingerprints bind tenure and actor reference", async () => {
  const inserted: any[] = [];
  let actor = { id: "tenure-1", actorReference: "a".repeat(64) };
  const tx = {
    contributorHistoryScope: { findUnique: async () => ({ id: "scope-1" }) },
    contributorTenure: { findFirst: async () => actor },
    contributionEvent: {
      createManyAndReturn: async ({ data }: any) => {
        const row = { id: `event-${inserted.length + 1}`, ...data[0], capturedAt: new Date() };
        inserted.push(row);
        return [row];
      },
      findUnique: async () => null,
    },
  };
  const service = new ContributionHistoryService({} as any);

  await service.recordInTransaction(tx as any, contributionInput() as any);
  actor = { id: "tenure-1", actorReference: "b".repeat(64) };
  await service.recordInTransaction(
    tx as any,
    contributionInput({ actorUserId: "user-2", dedupeKey: "actor-reference-only" }) as any,
  );
  actor = { id: "tenure-2", actorReference: "b".repeat(64) };
  await service.recordInTransaction(
    tx as any,
    contributionInput({ actorUserId: "user-2" }) as any,
  );

  assert.equal(inserted[0].contributorTenureId, inserted[1].contributorTenureId);
  assert.notEqual(inserted[0].eventFingerprint, inserted[1].eventFingerprint);
  assert.equal(inserted[0].dedupeKey, inserted[2].dedupeKey);
  assert.notEqual(inserted[1].contributorTenureId, inserted[2].contributorTenureId);
  assert.notEqual(inserted[1].eventFingerprint, inserted[2].eventFingerprint);
});
