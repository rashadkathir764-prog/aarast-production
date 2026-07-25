import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { AuthChallengeCleanupScheduler } from "../../src/auth/auth-challenge-cleanup.scheduler";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const day = 24 * 60 * 60 * 1_000;

function tokenHash(label: string): string {
  return createHash("sha256").update(`${runId}:${label}`).digest("hex");
}

async function main(): Promise<void> {
  const now = Date.now();
  const user = await prisma.user.create({
    data: {
      name: `Auth retention ${runId}`,
      phone: null,
      passwordHash: tokenHash("password"),
    },
  });
  try {
    await prisma.refreshToken.createMany({
      data: [
        {
          userId: user.id,
          tokenHash: tokenHash("expired-old"),
          expiresAt: new Date(now - 31 * day),
        },
        {
          userId: user.id,
          tokenHash: tokenHash("expired-recent"),
          expiresAt: new Date(now - 29 * day),
        },
        {
          userId: user.id,
          tokenHash: tokenHash("revoked-old"),
          expiresAt: new Date(now + 30 * day),
          revokedAt: new Date(now - 31 * day),
        },
        {
          userId: user.id,
          tokenHash: tokenHash("revoked-recent"),
          expiresAt: new Date(now - 31 * day),
          revokedAt: new Date(now - 29 * day),
        },
        {
          userId: user.id,
          tokenHash: tokenHash("active"),
          expiresAt: new Date(now + 30 * day),
        },
      ],
    });

    const scheduler = new AuthChallengeCleanupScheduler(prisma as any);
    assert.equal(await scheduler.removeExpiredSecurityState(), 2);
    const remaining = await prisma.refreshToken.findMany({
      where: { userId: user.id },
      select: { tokenHash: true },
      orderBy: { tokenHash: "asc" },
    });
    assert.deepEqual(
      remaining.map((row) => row.tokenHash).sort(),
      [
        tokenHash("active"),
        tokenHash("expired-recent"),
        tokenHash("revoked-recent"),
      ].sort(),
    );
    console.log(
      "PASS - refresh session cleanup preserves 30 days after each token's terminal event.",
    );
  } finally {
    await prisma.user.delete({ where: { id: user.id } });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
