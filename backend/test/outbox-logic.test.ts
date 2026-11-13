import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { OutboxEvent } from "@prisma/client";
import { readLivePrismaSchema } from './support/live-prisma-schema';
import { ConversationRealtimePublisher } from "../src/conversations/conversation-realtime.publisher";
import { OutboxEventTypes } from "../src/platform/outbox/outbox.constants";
import { OutboxDispatcher } from "../src/platform/outbox/outbox.dispatcher";
import { OutboxService } from "../src/platform/outbox/outbox.service";
import { OutboxCleanupScheduler } from "../src/platform/outbox/outbox-cleanup.scheduler";
import {
  OutboxWorker,
  outboxFailureCode,
  outboxRetryDelayMs,
} from "../src/platform/outbox/outbox.worker";

function event(type: string, payload: OutboxEvent["payload"]): OutboxEvent {
  const now = new Date("2026-07-10T10:00:00.000Z");
  return {
    id: "event-1",
    type,
    aggregateType: null,
    aggregateId: null,
    payload,
    status: "PROCESSING",
    attemptCount: 1,
    nextAttemptAt: now,
    lockedAt: now,
    lockedBy: "worker-1",
    processedAt: null,
    lastError: null,
    createdAt: now,
    updatedAt: now,
  };
}

const durableRealtimeEvents: Array<[string, OutboxEvent["payload"]]> = [
  [
    OutboxEventTypes.conversationMessageAvailable,
    { conversationId: "conversation-1", messageId: "message-1" },
  ],
  [
    OutboxEventTypes.conversationActivityAvailable,
    { conversationId: "conversation-1", activityKind: "EVENT" },
  ],
  [
    OutboxEventTypes.notificationCreated,
    { notificationId: "notification-1", userId: "user-1" },
  ],
  [
    OutboxEventTypes.conversationAccessRevoked,
    { userId: "user-1", conversationIds: ["conversation-1"] },
  ],
  [OutboxEventTypes.userSessionsRevoked, { userId: "user-1" }],
  [OutboxEventTypes.sessionRevoked, { sessionId: "session-1" }],
];

for (const [type, payload] of durableRealtimeEvents) {
  test(`durable ${type} dispatch fails while realtime is unattached`, async () => {
    const dispatcher = new OutboxDispatcher(
      new ConversationRealtimePublisher(),
    );
    await assert.rejects(() => dispatcher.dispatch(event(type, payload)));
  });
}

// D112 (Q-11), the owner's word: when an account's sessions are all ended
// (a new password, «اخرج من كل الأجهزة», a new number) the server lets go of
// its phones' push registrations too. The phones stayed bound, so a phone
// signed out by the server kept receiving the account's notifications
// (RA-BE-128). Only what was registered before the sessions ended goes: a
// phone that signed in again since has registered again.
test("ending an account's sessions releases its push registrations made before then", async () => {
  const released: Array<[string, string]> = [];
  const realtime = {
    dispatchUserSessionsRevoked: async () => {},
  } as unknown as ConversationRealtimePublisher;
  const push = {
    dispatchNotification: async () => {},
    releaseUserInstallations: async (userId: string, revokedAt: Date) => {
      released.push([userId, revokedAt.toISOString()]);
    },
  };
  const dispatcher = new OutboxDispatcher(realtime, push);

  await dispatcher.dispatch(
    event(OutboxEventTypes.userSessionsRevoked, { userId: "user-1" }),
  );

  assert.deepEqual(released, [["user-1", "2026-07-10T10:00:00.000Z"]]);
});

// RA-BE-133: a new password ends the other sessions and keeps the caller's;
// their phones' registrations go, the caller's own phone's stays, and the
// caller's sockets are not touched.
test("a password change's release keeps the named phone and leaves the sockets alone", async () => {
  const released: unknown[][] = [];
  const realtime = {
    dispatchUserSessionsRevoked: async () => {
      throw new Error("the caller's sockets must stay");
    },
  } as unknown as ConversationRealtimePublisher;
  const push = {
    dispatchNotification: async () => {},
    releaseUserInstallations: async (...args: unknown[]) => {
      released.push(args);
    },
  };
  const dispatcher = new OutboxDispatcher(realtime, push);

  await dispatcher.dispatch(
    event(OutboxEventTypes.pushInstallationsReleased, {
      userId: "user-1",
      keepInstallationFid: "this-phone-fid-1",
    }),
  );
  await dispatcher.dispatch(
    event(OutboxEventTypes.pushInstallationsReleased, { userId: "user-1" }),
  );

  const at = new Date("2026-07-10T10:00:00.000Z");
  assert.deepEqual(released, [
    ["user-1", at, "this-phone-fid-1"],
    ["user-1", at, undefined],
  ]);
  await assert.rejects(
    () =>
      dispatcher.dispatch(
        event(OutboxEventTypes.pushInstallationsReleased, {
          userId: "user-1",
          keepInstallationFid: " ",
        }),
      ),
    /InvalidOutboxPayload/,
  );
  // Without the push sink the release stays queued to be tried again.
  await assert.rejects(
    () =>
      new OutboxDispatcher(realtime).dispatch(
        event(OutboxEventTypes.pushInstallationsReleased, { userId: "user-1" }),
      ),
    /PushDeliveryUnavailable/,
  );
});

test("without a push sink, ending sessions still reaches the sockets", async () => {
  const calls: string[] = [];
  const realtime = {
    dispatchUserSessionsRevoked: async (id: string) => {
      calls.push(id);
    },
  } as unknown as ConversationRealtimePublisher;

  await new OutboxDispatcher(realtime).dispatch(
    event(OutboxEventTypes.userSessionsRevoked, { userId: "user-1" }),
  );

  assert.deepEqual(calls, ["user-1"]);
});

test("unattached realtime delivery remains retryable instead of processed", async () => {
  let updateData: Record<string, unknown> | undefined;
  const prisma = {
    outboxEvent: {
      updateMany: async ({ data }: { data: Record<string, unknown> }) => {
        updateData = data;
        return { count: 1 };
      },
    },
  };
  const worker = new OutboxWorker(
    prisma as never,
    new OutboxDispatcher(new ConversationRealtimePublisher()),
  );

  await (
    worker as unknown as {
      process: (outboxEvent: OutboxEvent) => Promise<void>;
    }
  ).process(
    event(OutboxEventTypes.sessionRevoked, {
      sessionId: "session-1",
    }),
  );

  assert.equal(updateData?.status, "PENDING");
  assert.equal(updateData?.processedAt, undefined);
  assert.ok(updateData?.nextAttemptAt instanceof Date);
  assert.equal(updateData?.lastError, "RealtimeServerUnavailableError");
});

test("outbox enqueue writes the supplied transaction client", async () => {
  let data: unknown;
  const client = {
    outboxEvent: {
      create: async (input: unknown) => {
        data = input;
        return {};
      },
    },
  };
  await new OutboxService().enqueue(client as never, {
    type: OutboxEventTypes.notificationCreated,
    aggregateType: "notification",
    aggregateId: "notification-1",
    payload: { notificationId: "notification-1", userId: "user-1" },
  });
  assert.match(JSON.stringify(data), /notification-1/);
});

test("push delivery is dispatched independently from realtime delivery", async () => {
  const calls: string[] = [];
  const dispatcher = new OutboxDispatcher(new ConversationRealtimePublisher(), {
    dispatchNotification: async (notificationId: string) => {
      calls.push(notificationId);
    },
  } as never);

  await dispatcher.dispatch(
    event(OutboxEventTypes.pushNotificationRequested, {
      notificationId: "notification-1",
    }),
  );

  assert.deepEqual(calls, ["notification-1"]);
});

test("missing push delivery remains retryable", async () => {
  const dispatcher = new OutboxDispatcher(new ConversationRealtimePublisher());

  await assert.rejects(
    () =>
      dispatcher.dispatch(
        event(OutboxEventTypes.pushNotificationRequested, {
          notificationId: "notification-1",
        }),
      ),
    (error: unknown) => {
      assert.equal((error as Error).name, "PushDeliveryUnavailable");
      return true;
    },
  );
});

test("dispatcher publishes durable chat and notification availability", async () => {
  const calls: Array<[string, string, unknown]> = [];
  const realtime = {
    dispatchMessageAvailable: async (id: string, payload: unknown) => {
      calls.push(["message", id, payload]);
    },
    dispatchActivityAvailable: async (
      id: string,
      payload: unknown,
      includeLifecycleEvent: boolean,
    ) => {
      calls.push(["activity", id, { payload, includeLifecycleEvent }]);
    },
    dispatchNotificationAvailable: async (id: string, payload: unknown) => {
      calls.push(["notification", id, payload]);
    },
    dispatchConversationAccessRevoked: async (id: string, payload: unknown) => {
      calls.push(["conversation-revoked", id, payload]);
    },
    dispatchUserSessionsRevoked: async (id: string) => {
      calls.push(["user-revoked", id, null]);
    },
    dispatchSessionRevoked: async (id: string) => {
      calls.push(["session-revoked", id, null]);
    },
  } as unknown as ConversationRealtimePublisher;
  const dispatcher = new OutboxDispatcher(realtime);

  await dispatcher.dispatch(
    event(OutboxEventTypes.conversationMessageAvailable, {
      conversationId: "conversation-1",
      messageId: "message-1",
    }),
  );
  await dispatcher.dispatch(
    event(OutboxEventTypes.conversationActivityAvailable, {
      conversationId: "conversation-1",
      activityKind: "EVENT",
      eventId: "event-1",
    }),
  );
  await dispatcher.dispatch(
    event(OutboxEventTypes.conversationAccessRevoked, {
      userId: "user-1",
      conversationIds: ["conversation-2", "conversation-1"],
    }),
  );
  await dispatcher.dispatch(
    event(OutboxEventTypes.userSessionsRevoked, {
      userId: "user-1",
    }),
  );
  await dispatcher.dispatch(
    event(OutboxEventTypes.sessionRevoked, {
      sessionId: "session-1",
    }),
  );
  await dispatcher.dispatch(
    event(OutboxEventTypes.notificationCreated, {
      notificationId: "notification-1",
      userId: "user-1",
    }),
  );

  assert.deepEqual(calls, [
    [
      "message",
      "conversation-1",
      { conversationId: "conversation-1", messageId: "message-1" },
    ],
    [
      "activity",
      "conversation-1",
      {
        payload: {
          conversationId: "conversation-1",
          activityKind: "EVENT",
          eventId: "event-1",
        },
        includeLifecycleEvent: true,
      },
    ],
    ["conversation-revoked", "user-1", ["conversation-1", "conversation-2"]],
    ["user-revoked", "user-1", null],
    ["session-revoked", "session-1", null],
    ["notification", "user-1", { notificationId: "notification-1" }],
  ]);
});

test("strict realtime dispatch surfaces adapter failures", async () => {
  const adapterFailure = new Error("adapter unavailable");
  adapterFailure.name = "AdapterUnavailableError";
  const realtime = new ConversationRealtimePublisher();
  realtime.attach({
    in: () => ({
      fetchSockets: async () => {
        throw adapterFailure;
      },
    }),
  } as never);
  const dispatcher = new OutboxDispatcher(realtime);

  await assert.rejects(
    () =>
      dispatcher.dispatch(
        event(OutboxEventTypes.userSessionsRevoked, {
          userId: "user-1",
        }),
      ),
    adapterFailure,
  );
});

test("strict revocation uses fetched sockets for leave and disconnect", async () => {
  const actions: string[] = [];
  const socket = {
    id: "socket-1",
    emit: (name: string, payload: { conversationId: string }) => {
      actions.push(`emit:${name}:${payload.conversationId}`);
    },
    leave: (room: string) => {
      actions.push(`leave:${room}`);
    },
    disconnect: (close: boolean) => {
      actions.push(`disconnect:${close}`);
    },
  };
  const realtime = new ConversationRealtimePublisher();
  realtime.attach({
    in: (room: string) => ({
      fetchSockets: async () => {
        actions.push(`fetch:${room}`);
        return [socket];
      },
    }),
  } as never);
  const dispatcher = new OutboxDispatcher(realtime);

  await dispatcher.dispatch(
    event(OutboxEventTypes.conversationAccessRevoked, {
      userId: "user-1",
      conversationIds: ["conversation-1"],
    }),
  );
  await dispatcher.dispatch(
    event(OutboxEventTypes.sessionRevoked, {
      sessionId: "session-1",
    }),
  );

  assert.deepEqual(actions, [
    "fetch:user:user-1",
    "emit:conversation:permission-revoked:conversation-1",
    "leave:conversation:conversation-1",
    "fetch:session:session-1",
    "disconnect:true",
  ]);
});

test("strict conversation revocation awaits a rejected socket leave", async () => {
  const leaveFailure = new Error("remote leave failed");
  leaveFailure.name = "RemoteLeaveError";
  const realtime = new ConversationRealtimePublisher();
  realtime.attach({
    in: () => ({
      fetchSockets: async () => [
        {
          id: "socket-1",
          emit: () => undefined,
          leave: async () => {
            throw leaveFailure;
          },
        },
      ],
    }),
  } as never);
  const dispatcher = new OutboxDispatcher(realtime);

  await assert.rejects(
    () =>
      dispatcher.dispatch(
        event(OutboxEventTypes.conversationAccessRevoked, {
          userId: "user-1",
          conversationIds: ["conversation-1"],
        }),
      ),
    leaveFailure,
  );
});

test("strict session revocation awaits a rejected socket disconnect", async () => {
  const disconnectFailure = new Error("remote disconnect failed");
  disconnectFailure.name = "RemoteDisconnectError";
  const realtime = new ConversationRealtimePublisher();
  realtime.attach({
    in: () => ({
      fetchSockets: async () => [
        {
          id: "socket-1",
          disconnect: async () => {
            throw disconnectFailure;
          },
        },
      ],
    }),
  } as never);
  const dispatcher = new OutboxDispatcher(realtime);

  await assert.rejects(
    () =>
      dispatcher.dispatch(
        event(OutboxEventTypes.sessionRevoked, {
          sessionId: "session-1",
        }),
      ),
    disconnectFailure,
  );
});

test("immediate realtime methods remain best-effort while unattached", () => {
  const realtime = new ConversationRealtimePublisher();

  assert.doesNotThrow(() => {
    realtime.message("conversation-1", {});
    realtime.read("conversation-1", {});
    realtime.event("conversation-1", {});
    realtime.activityAvailable("conversation-1", {});
    realtime.revokeConversationAccess("user-1", ["conversation-1"]);
    realtime.messageAvailable("conversation-1", {});
    realtime.notificationAvailable("user-1", {});
    realtime.disconnectUser("user-1");
    realtime.disconnectSession("session-1");
  });
});

test("outbox retry is bounded and failure storage is redacted", () => {
  assert.equal(outboxRetryDelayMs(1), 1_000);
  assert.equal(outboxRetryDelayMs(4), 8_000);
  assert.equal(outboxRetryDelayMs(100), 128_000);
  const secret = new Error("postgres://user:secret@db/private");
  assert.equal(outboxFailureCode(secret), "Error");
  assert.equal(outboxFailureCode(secret).includes("secret"), false);
});

test("outbox uses transactional inserts and cross-replica skip-locked claims", () => {
  const worker = readFileSync(
    join(process.cwd(), "src/platform/outbox/outbox.worker.ts"),
    "utf8",
  );
  const notifications = readFileSync(
    join(process.cwd(), "src/notifications/notifications.service.ts"),
    "utf8",
  );
  const conversations = readFileSync(
    join(process.cwd(), "src/conversations/conversations.service.ts"),
    "utf8",
  );
  const schema = readLivePrismaSchema();

  assert.match(worker, /FOR UPDATE SKIP LOCKED/);
  assert.match(worker, /status: terminal \? 'FAILED' : 'PENDING'/);
  assert.match(notifications, /\$transaction/);
  assert.match(notifications, /notificationCreated/);
  assert.match(conversations, /conversationMessageAvailable/);
  assert.match(schema, /model OutboxEvent/);
});

test("outbox cleanup removes only old processed delivery receipts", async () => {
  let where: unknown;
  const scheduler = new OutboxCleanupScheduler({
    $transaction: async (operation: (client: unknown) => unknown) =>
      operation({
        $queryRaw: async () => [{ locked: true }],
        outboxEvent: {
          deleteMany: async (args: { where: unknown }) => {
            where = args.where;
            return { count: 3 };
          },
        },
      }),
  } as never);

  assert.equal(await scheduler.removeProcessedReceipts(), 3);
  assert.deepEqual((where as { status: string }).status, "PROCESSED");
  assert.ok(
    (where as { processedAt: { lt: unknown } }).processedAt.lt instanceof Date,
  );
  assert.equal(JSON.stringify(where).includes("FAILED"), false);
});
