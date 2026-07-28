import "reflect-metadata";

import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { NotFoundException } from "@nestjs/common";
import {
  MediaUploadStatus,
  PrismaClient,
  UserStatus,
} from "@prisma/client";
import { MediaUploadTicketService } from "../../src/media/media-upload-ticket.service";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const tickets = new MediaUploadTicketService(prisma as never);

function deferred(): {
  promise: Promise<void>;
  resolve: () => void;
} {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

async function waitForBlockedClaim(operation: Promise<unknown>): Promise<void> {
  const state = await Promise.race([
    operation.then(
      () => "settled",
      () => "settled",
    ),
    new Promise<"blocked">((resolve) =>
      setTimeout(() => resolve("blocked"), 75),
    ),
  ]);
  assert.equal(
    state,
    "blocked",
    "verification claim must wait for the User lifecycle lock",
  );
}

async function main(): Promise<void> {
  const user = await prisma.user.create({
    data: {
      name: `Media lifecycle ${runId}`,
      phone: null,
      passwordHash: `media-lifecycle-${runId}`,
    },
  });
  const key = `chat-image/${user.id}/${randomUUID()}.webp`;
  const disabled = deferred();
  const commitRequested = deferred();
  let disableCommitted = false;
  let disableTransaction: Promise<void> | null = null;

  try {
    await tickets.reserveUpload({
      key,
      userId: user.id,
      purpose: "chat-image",
      contentType: "image/webp",
      declaredByteSize: 1_024,
    });
    disableTransaction = prisma.$transaction(
      async (tx) => {
        await tx.user.update({
          where: { id: user.id },
          data: { status: UserStatus.DISABLED },
        });
        disabled.resolve();
        await commitRequested.promise;
      },
      { timeout: 20_000 },
    );
    await disabled.promise;

    const claim = tickets.claimForVerification(
      key,
      user.id,
      "chat-image",
    );
    try {
      await waitForBlockedClaim(claim);
      commitRequested.resolve();
      await disableTransaction;
      disableCommitted = true;
      await assert.rejects(claim, NotFoundException);
    } finally {
      if (!disableCommitted) {
        commitRequested.resolve();
        await disableTransaction;
        disableCommitted = true;
      }
    }

    const ticket = await prisma.mediaUploadTicket.findUniqueOrThrow({
      where: { key },
      select: { status: true },
    });
    assert.equal(
      ticket.status,
      MediaUploadStatus.PENDING,
      "a disabled account must not transition its ticket to VERIFYING",
    );
    console.log(
      "PASS - media verification waits for User lifecycle and rejects after disable.",
    );
  } finally {
    commitRequested.resolve();
    await disableTransaction?.catch(() => undefined);
    await prisma.mediaUploadTicket.deleteMany({ where: { key } });
    await prisma.user.deleteMany({ where: { id: user.id } });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
