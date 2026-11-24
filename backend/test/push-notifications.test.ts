import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { NotificationType, PushPlatform, UserStatus } from "@prisma/client";
import { PushDeliveryService } from "../src/modules/notifications/infrastructure/push-delivery.service";
import { PushInstallationsService } from "../src/modules/notifications/infrastructure/push-installations.service";
import { validateRuntimeEnvironment } from "../src/platform/config/runtime-environment";
import {
  isPushNotificationType,
  pushNotificationCopy,
} from "../src/push/push-notification.policy";
import { getJwtSecret } from "../src/modules/identity/internal/auth/jwt-secret";

test("push policy is limited to the notification types that wait on a person", () => {
  assert.equal(isPushNotificationType(NotificationType.TASK_ASSIGNED), true);
  assert.equal(isPushNotificationType(NotificationType.TASK_DUE_SOON), true);
  assert.equal(isPushNotificationType(NotificationType.TASK_OVERDUE), true);
  assert.equal(
    isPushNotificationType(NotificationType.CHAT_MESSAGE_RECEIVED),
    true,
  );
  // RA-BE-186 (Q-48 أ), on purpose: this test used to pin that a new
  // request never reaches a phone, which left the provider with no word of
  // a request that expires in 7 days. The type is written for both sides:
  // the customer's acknowledgement stays in the inbox, the provider's
  // «وصلك طلب جديد» pushes (`provider-push.test.ts` holds the whole rule).
  assert.equal(
    isPushNotificationType(NotificationType.QUOTE_REQUEST_SUBMITTED, {
      recipientAudience: "CUSTOMER",
    }),
    false,
  );
  assert.equal(
    isPushNotificationType(NotificationType.QUOTE_REQUEST_SUBMITTED, {
      recipientAudience: "PROVIDER",
    }),
    true,
  );
  // Reviews stay in the inbox.
  assert.equal(isPushNotificationType(NotificationType.REVIEW_RECEIVED), false);
});

// A price offer and each booking step wait on the other side's decision, so
// they reach the phone; the copy stays generic (V1 checklist 4.6).
test("an offer and a booking step are pushed with generic copy", () => {
  for (const type of [
    NotificationType.QUOTE_OFFER_RECEIVED,
    NotificationType.BOOKING_UPDATED,
  ]) {
    assert.equal(isPushNotificationType(type), true);
    const copy = pushNotificationCopy(type);
    // B5: it points to the app without an imperative in either gender.
    assert.equal(copy.body.includes("في اعّرست"), true);
  }
});

test("runtime fails closed when push is enabled without a Firebase project", () => {
  const environment = {
    NODE_ENV: "development",
    DATABASE_URL: "postgresql://local/test",
    JWT_SECRET: "a".repeat(64),
    AUTH_OTP_MODE: "disabled",
    PUSH_NOTIFICATIONS_ENABLED: "true",
  };

  assert.throws(
    () => validateRuntimeEnvironment(environment, getJwtSecret),
    /FIREBASE_PROJECT_ID/,
  );
  assert.doesNotThrow(() =>
    validateRuntimeEnvironment({
      ...environment,
      FIREBASE_PROJECT_ID: "aarast-project",
    }, getJwtSecret),
  );
});

test("push copy remains generic and does not expose notification body data", () => {
  const copy = pushNotificationCopy(NotificationType.TASK_ASSIGNED);

  assert.equal(copy.title.includes("قاعة"), false);
  assert.equal(copy.body.includes("قاعة"), false);
  assert.equal(copy.body.includes("في اعّرست"), true);
});

test("disabled push delivery performs no database or Firebase work", async () => {
  let databaseReads = 0;
  const service = new PushDeliveryService(
    {
      notification: {
        findUnique: async () => {
          databaseReads += 1;
        },
      },
    } as never,
    {
      enabled: false,
      sendEachForMulticast: async () => {
        throw new Error("must not send");
      },
    } as never,
  );

  await service.dispatchNotification("notification-1");

  assert.equal(databaseReads, 0);
});

test("registering a shared-device FID atomically moves it to the current account", async () => {
  const upserts: any[] = [];
  const preferenceUpserts: any[] = [];
  const disabledUsers: string[] = [];
  const rawResponses = [
    [{ id: "installation-1", userId: "old-user" }],
    [
      { id: "current-user", status: UserStatus.ACTIVE },
      { id: "old-user", status: UserStatus.ACTIVE },
    ],
  ];
  const transaction = {
    $queryRaw: async () => rawResponses.shift() ?? [],
    pushInstallation: {
      upsert: async (input: any) => {
        upserts.push(input);
      },
      count: async () => 0,
    },
    notificationPreference: {
      upsert: async (input: any) => {
        preferenceUpserts.push(input);
      },
      updateMany: async ({ where }: any) => {
        disabledUsers.push(where.userId);
      },
    },
  };
  const service = new PushInstallationsService({
    $transaction: async (operation: (tx: any) => Promise<unknown>) =>
      operation(transaction),
  } as never);

  await service.register(
    { id: "current-user" } as any,
    "fid_shared_device",
    PushPlatform.ANDROID,
  );

  assert.equal(upserts[0]?.update.userId, "current-user");
  assert.equal(upserts[0]?.update.enabled, true);
  // RA-MO-358: no session on the identity leaves it unbound, not undefined.
  assert.equal(upserts[0]?.update.sessionId, null);
  assert.equal(preferenceUpserts[0]?.update.pushEnabled, true);
  assert.deepEqual(disabledUsers, ["old-user"]);
});

// RA-MO-358: the registration remembers the session it was made under, so
// ending that session can let it go.
test("a registration is stored with the session it was made under", async () => {
  const upserts: any[] = [];
  const rawResponses = [[], [{ id: "current-user", status: UserStatus.ACTIVE }]];
  const transaction = {
    $queryRaw: async () => rawResponses.shift() ?? [],
    pushInstallation: {
      upsert: async (input: any) => {
        upserts.push(input);
      },
      count: async () => 0,
    },
    notificationPreference: { upsert: async () => undefined },
  };
  const service = new PushInstallationsService({
    $transaction: async (operation: (tx: any) => Promise<unknown>) =>
      operation(transaction),
  } as never);

  await service.register(
    { id: "current-user", sessionId: "session-9" } as any,
    "fid_shared_device",
    PushPlatform.ANDROID,
  );

  assert.equal(upserts[0]?.create.sessionId, "session-9");
  assert.equal(upserts[0]?.update.sessionId, "session-9");
});

test("delivery removes permanent invalid installations and retries transient failures", async () => {
  let deletedInstallations: any[] = [];
  const disabledUsers: string[] = [];
  let sent: any;
  const transaction = {
    pushInstallation: {
      deleteMany: async ({ where }: any) => {
        deletedInstallations = where.OR;
      },
      count: async () => 1,
    },
    notificationPreference: {
      updateMany: async ({ where }: any) => {
        disabledUsers.push(where.userId);
      },
    },
  };
  const service = new PushDeliveryService(
    {
      $transaction: async (operation: (tx: any) => Promise<unknown>) =>
        operation(transaction),
      // The push preference and the installations are notifications' own
      // rows keyed by the recipient (they used to be reached through the
      // user include).
      notification: {
        findUnique: async () => ({
          id: "notification-1",
          userId: "user-1",
          weddingPlanId: "plan-1",
          type: NotificationType.CHAT_MESSAGE_RECEIVED,
          priority: "NORMAL",
          title: "private title",
          body: "private body",
          entityType: "conversation",
          entityId: "conversation-1",
          routeTarget: "/private/route",
          data: {},
          readAt: null,
          archivedAt: null,
          dedupeKey: "dedupe",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      },
      notificationPreference: {
        findUnique: async () => ({ pushEnabled: true }),
      },
      pushInstallation: {
        findMany: async ({ where }: any) => {
          assert.deepEqual(where, { userId: "user-1", enabled: true });
          return [
            {
              id: "installation-permanent",
              fid: "fid-permanent",
              updatedAt: new Date("2026-07-29T00:00:00.000Z"),
            },
            {
              id: "installation-transient",
              fid: "fid-transient",
              updatedAt: new Date("2026-07-29T00:00:00.000Z"),
            },
          ];
        },
      },
    } as never,
    {
      enabled: true,
      sendEachForMulticast: async (message: any) => {
        sent = message;
        return {
          successCount: 0,
          failureCount: 2,
          responses: [
            {
              success: false,
              error: {
                code: "messaging/installation-id-not-registered",
              },
            },
            {
              success: false,
              error: { code: "messaging/internal-error" },
            },
          ],
        };
      },
    } as never,
  );

  await assert.rejects(
    () => service.dispatchNotification("notification-1"),
    (error: unknown) => {
      assert.equal((error as Error).name, "PushDeliveryRetryRequired");
      return true;
    },
  );

  assert.deepEqual(
    deletedInstallations.map((installation) => installation.id),
    ["installation-permanent"],
  );
  assert.equal(deletedInstallations[0]?.userId, "user-1");
  assert.deepEqual(disabledUsers, []);
  assert.equal(sent.notification.title.includes("private"), false);
  assert.equal(sent.notification.body.includes("private"), false);
  assert.equal(sent.data.notificationId, "notification-1");
  assert.equal(sent.data.weddingPlanId, undefined);
  assert.equal(sent.data.routeTarget, undefined);
  assert.equal(sent.android.notification.channelId, "aarast_updates");
  assert.equal(sent.android.priority, "high");
  assert.equal(sent.android.notification.priority, "high");
  assert.equal(sent.android.notification.defaultSound, true);
  assert.equal(sent.android.notification.visibility, "private");
  assert.equal(sent.android.notification.icon, "ic_stat_aarast");
  assert.equal(sent.android.notification.color, "#4C7180");
});

test("delivery disables push when every registered installation is permanently invalid", async () => {
  const disabledUsers: string[] = [];
  const transaction = {
    pushInstallation: {
      deleteMany: async () => ({ count: 1 }),
      count: async () => 0,
    },
    notificationPreference: {
      updateMany: async ({ where, data }: any) => {
        assert.equal(data.pushEnabled, false);
        disabledUsers.push(where.userId);
      },
    },
  };
  const service = new PushDeliveryService(
    {
      $transaction: async (operation: (tx: any) => Promise<unknown>) =>
        operation(transaction),
      notification: {
        findUnique: async () => ({
          id: "notification-2",
          userId: "user-2",
          type: NotificationType.TASK_ASSIGNED,
        }),
      },
      notificationPreference: {
        findUnique: async () => ({ pushEnabled: true }),
      },
      pushInstallation: {
        findMany: async () => [
          {
            id: "installation-only",
            fid: "fid-only",
            updatedAt: new Date("2026-07-29T00:00:00.000Z"),
          },
        ],
      },
    } as never,
    {
      enabled: true,
      sendEachForMulticast: async () => ({
        successCount: 0,
        failureCount: 1,
        responses: [
          {
            success: false,
            error: {
              code: "messaging/installation-id-not-registered",
            },
          },
        ],
      }),
    } as never,
  );

  await service.dispatchNotification("notification-2");

  assert.deepEqual(disabledUsers, ["user-2"]);
});

// D112 (Q-11), RA-BE-128: ending an account's sessions lets go of the push
// registrations it made before then, and only those.
test("ended sessions release the registrations made before them; one made since stays", async () => {
  const revokedAt = new Date("2026-11-12T10:00:00.000Z");
  const deletes: unknown[] = [];
  const disabledUsers: string[] = [];
  let enabledLeft = 1;
  const transaction = {
    pushInstallation: {
      deleteMany: async ({ where }: any) => {
        deletes.push(where);
        return { count: 2 };
      },
      count: async ({ where }: any) => {
        assert.deepEqual(where, { userId: "user-3", enabled: true });
        return enabledLeft;
      },
    },
    notificationPreference: {
      updateMany: async ({ where, data }: any) => {
        assert.equal(data.pushEnabled, false);
        disabledUsers.push(where.userId);
      },
    },
  };
  const service = new PushDeliveryService(
    {
      $transaction: async (operation: (tx: any) => Promise<unknown>) =>
        operation(transaction),
    } as never,
    // Releasing registrations is the server's own record; it does not wait
    // on Firebase being set up.
    { enabled: false } as never,
  );

  // A phone signed in again since: its registration is newer and stays, so
  // the account's push stays on.
  await service.releaseUserInstallations("user-3", revokedAt);
  assert.deepEqual(deletes, [
    { userId: "user-3", lastSeenAt: { lt: revokedAt } },
  ]);
  assert.deepEqual(disabledUsers, []);

  // No phone left: push is off until one registers again.
  enabledLeft = 0;
  await service.releaseUserInstallations("user-3", revokedAt);
  assert.deepEqual(disabledUsers, ["user-3"]);

  // RA-BE-133: a new password keeps the phone that set it.
  deletes.length = 0;
  await service.releaseUserInstallations("user-3", revokedAt, "this-phone-fid-1");
  assert.deepEqual(deletes, [
    {
      userId: "user-3",
      lastSeenAt: { lt: revokedAt },
      fid: { not: "this-phone-fid-1" },
    },
  ]);
});

// RA-MO-358: a session that ended (a sign-out on another phone, a refresh
// token used twice) lets go of the registration made under it, whatever its
// age; the account's push goes off only when no phone is left.
test("an ended session releases its own phone's registration", async () => {
  const deletes: unknown[] = [];
  const disabledUsers: string[] = [];
  let enabledLeft = 1;
  const transaction = {
    pushInstallation: {
      findMany: async ({ where }: any) => {
        assert.deepEqual(where, { sessionId: "session-1" });
        return [{ userId: "user-3" }];
      },
      deleteMany: async ({ where }: any) => {
        deletes.push(where);
        return { count: 1 };
      },
      count: async ({ where }: any) => {
        assert.deepEqual(where, { userId: "user-3", enabled: true });
        return enabledLeft;
      },
    },
    notificationPreference: {
      updateMany: async ({ where, data }: any) => {
        assert.equal(data.pushEnabled, false);
        disabledUsers.push(where.userId);
      },
    },
  };
  const service = new PushDeliveryService(
    {
      $transaction: async (operation: (tx: any) => Promise<unknown>) =>
        operation(transaction),
    } as never,
    { enabled: false } as never,
  );

  await service.releaseSessionInstallations("session-1");
  assert.deepEqual(deletes, [{ sessionId: "session-1" }]);
  assert.deepEqual(disabledUsers, []);

  enabledLeft = 0;
  await service.releaseSessionInstallations("session-1");
  assert.deepEqual(disabledUsers, ["user-3"]);
});

test("a session with no registration releases nothing", async () => {
  const transaction = {
    pushInstallation: {
      findMany: async () => [],
      deleteMany: async () => {
        throw new Error("nothing to delete");
      },
    },
  };
  const service = new PushDeliveryService(
    {
      $transaction: async (operation: (tx: any) => Promise<unknown>) =>
        operation(transaction),
    } as never,
    { enabled: false } as never,
  );
  await service.releaseSessionInstallations("session-none");
});

test("a refreshed session carries its registration to its next id", async () => {
  const moves: any[] = [];
  const service = new PushDeliveryService(
    {
      pushInstallation: {
        updateMany: async (input: any) => {
          moves.push(input);
          return { count: 1 };
        },
      },
    } as never,
    { enabled: false } as never,
  );

  await service.moveSessionInstallations("session-1", "session-2");

  assert.deepEqual(moves, [
    { where: { sessionId: "session-1" }, data: { sessionId: "session-2" } },
  ]);
});

// RA-BE-99: the lock screen says what the notice says: a late task is late,
// not coming, and the wedding day is the day, not near.
test("an overdue task and the wedding day have their own lock-screen words", () => {
  const overdue = pushNotificationCopy(NotificationType.TASK_OVERDUE);
  assert.equal(overdue.title, "مهمة متأخرة");
  assert.doesNotMatch(overdue.body, /قريب/u);
  assert.equal(pushNotificationCopy(NotificationType.TASK_DUE_SOON).title, "تذكير بمهمة");

  const day = pushNotificationCopy(NotificationType.WEDDING_COUNTDOWN, { daysUntil: 0 });
  assert.equal(day.title, "اليوم يوم العرس");
  assert.equal(
    pushNotificationCopy(NotificationType.WEDDING_COUNTDOWN, { daysUntil: 3 }).title,
    "العرس يقرب",
  );
  // Never a name or an amount on the lock screen.
  for (const copy of [overdue, day]) assert.doesNotMatch(copy.body, /\d/u);
});
