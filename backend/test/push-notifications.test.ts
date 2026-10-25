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

test("push policy is limited to task and chat notification types", () => {
  assert.equal(isPushNotificationType(NotificationType.TASK_ASSIGNED), true);
  assert.equal(isPushNotificationType(NotificationType.TASK_DUE_SOON), true);
  assert.equal(isPushNotificationType(NotificationType.TASK_OVERDUE), true);
  assert.equal(
    isPushNotificationType(NotificationType.CHAT_MESSAGE_RECEIVED),
    true,
  );
  assert.equal(
    isPushNotificationType(NotificationType.QUOTE_REQUEST_SUBMITTED),
    false,
  );
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
  assert.equal(preferenceUpserts[0]?.update.pushEnabled, true);
  assert.deepEqual(disabledUsers, ["old-user"]);
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
