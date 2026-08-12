import "reflect-metadata";

import assert from "node:assert/strict";
import { Prisma, PrismaClient } from "@prisma/client";
import { reconcileAmbiguousIdempotencyKey } from "../../src/platform/idempotency/idempotency-reconciliation";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const method = "POST";
const path = "/api/v1/wedding-plans/:weddingPlanId/costs";
const expiredAt = new Date(Date.now() - 60_000);

async function createTombstone(label: string) {
  return prisma.idempotencyKey.create({
    data: {
      userId: `${runId}:${label}`,
      key: `${runId}:${label}`,
      method,
      path,
      requestHash: label.repeat(64).slice(0, 64),
      response: Prisma.DbNull,
      completedAt: null,
      expiresAt: expiredAt,
    },
  });
}

async function main(): Promise<void> {
  const ownedIds: string[] = [];
  try {
    const released = await createTombstone("a");
    ownedIds.push(released.id);
    const releaseResult = await reconcileAmbiguousIdempotencyKey(
      prisma as any,
      {
        id: released.id,
        expectedMethod: method,
        expectedPath: path,
        resolution: { outcome: "NO_COMMIT" },
      },
    );
    assert.equal(releaseResult.state, "RELEASED_FOR_RETRY");
    assert.equal(
      await prisma.idempotencyKey.count({ where: { id: released.id } }),
      0,
    );

    const completed = await createTombstone("b");
    ownedIds.push(completed.id);
    const completionResult = await reconcileAmbiguousIdempotencyKey(
      prisma as any,
      {
        id: completed.id,
        expectedMethod: method,
        expectedPath: path,
        resolution: {
          outcome: "COMMITTED",
          response: {
            body: { id: "verified-domain-record", created: true },
            statusCode: 201,
            headers: { location: "/api/v1/costs/verified-domain-record" },
          },
        },
      },
    );
    assert.equal(completionResult.state, "COMPLETED_FOR_REPLAY");

    const replay = await prisma.idempotencyKey.findUniqueOrThrow({
      where: { id: completed.id },
    });
    assert.ok(replay.completedAt);
    assert.ok(replay.expiresAt.getTime() > Date.now());
    assert.deepEqual(replay.response, {
      __aarastIdempotencyResponseV1: true,
      body: { id: "verified-domain-record", created: true },
      statusCode: 201,
      headers: { location: "/api/v1/costs/verified-domain-record" },
    });

    console.log(
      "PASS - expired ambiguous idempotency tombstones reconcile safely.",
    );
  } finally {
    if (ownedIds.length > 0) {
      await prisma.idempotencyKey.deleteMany({
        where: { id: { in: ownedIds } },
      });
    }
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
