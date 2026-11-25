import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { NotificationType, OutboxEvent, PushDeliveryState } from "@prisma/client";
import { PushDeliveryService } from "../src/modules/notifications/infrastructure/push-delivery.service";
import { NotificationsController } from "../src/notifications/notifications.controller";
import { NotificationRemindersScheduler } from "../src/notifications/notification-reminders.scheduler";
import { noticeForRecipient } from "../src/notifications/notifications.service";
import { OutboxEventTypes } from "../src/platform/outbox/outbox.constants";
import { OutboxDispatcher } from "../src/platform/outbox/outbox.dispatcher";
import { OutboxWorker } from "../src/platform/outbox/outbox.worker";
import { validateRuntimeEnvironment } from "../src/platform/config/runtime-environment";
import { publicReadiness, ReadinessService } from "../src/platform/health/readiness.service";
import {
  bypassesQuietHours,
  isPushNotificationType,
  pushAndroidChannelId,
  pushNotBefore,
  pushNotificationCopy,
  pushPlanRight,
} from "../src/push/push-notification.policy";
import { getJwtSecret } from "../src/modules/identity/internal/auth/jwt-secret";
import { notificationsService } from "./support/owner-ports";
import { OutboxService } from "../src/platform/outbox/outbox.service";

// ── The push's honest state on its notice ─────────────────────────────

type Member = {
  canViewMoney?: boolean;
  canManageTasks?: boolean;
  canManageProviders?: boolean;
};

function notice(overrides: Record<string, unknown> = {}) {
  return {
    id: "notification-1",
    userId: "user-1",
    weddingPlanId: "plan-1",
    type: NotificationType.TASK_DUE_SOON,
    priority: "NORMAL",
    title: "private title",
    body: "private body",
    entityType: "task",
    entityId: "task-1",
    routeTarget: "/private",
    data: {},
    readAt: null,
    archivedAt: null,
    dedupeKey: "dedupe",
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

function harness(options: {
  notification?: Record<string, unknown>;
  enabled?: boolean;
  pushEnabled?: boolean;
  installations?: Array<{ id: string; fid: string }>;
  send?: (message: any) => Promise<any>;
  owner?: string;
  member?: Member | null;
  deletionPending?: boolean;
}) {
  const states: Array<Record<string, unknown>> = [];
  let sends = 0;
  const installations = (options.installations ?? []).map((item) => ({
    ...item,
    updatedAt: new Date("2026-11-01T00:00:00.000Z"),
  }));
  const prisma = {
    notification: {
      findUnique: async () => notice(options.notification),
      updateMany: async ({ where, data }: any) => {
        states.push({ where, ...data });
        return { count: 1 };
      },
    },
    notificationPreference: {
      findUnique: async () => ({ pushEnabled: options.pushEnabled ?? true }),
      updateMany: async () => ({ count: 1 }),
    },
    pushInstallation: {
      findMany: async () => installations,
      deleteMany: async () => ({ count: 1 }),
      count: async () => 0,
    },
    $transaction: async (operation: (tx: any) => Promise<unknown>) => operation(prisma),
  };
  const member = options.member === undefined ? null : options.member;
  const service = new PushDeliveryService(
    prisma as never,
    {
      enabled: options.enabled ?? true,
      sendEachForMulticast: async (message: any) => {
        sends += 1;
        if (options.send) return options.send(message);
        return {
          responses: message.fids.map(() => ({ success: true })),
        };
      },
    } as never,
    {
      getMembership: async () => member,
      canViewMoney: (context: any) => context.sharedMember?.canViewMoney === true,
      canManageTasks: (context: any) => context.sharedMember?.canManageTasks === true,
      canManageProviders: (context: any) => context.sharedMember?.canManageProviders === true,
    } as never,
    {
      getPlan: async (_client: unknown, id: string) => ({
        id,
        ownerUserId: options.owner ?? "user-1",
        deletionRequestedAt: options.deletionPending ? new Date() : null,
      }),
    } as never,
  );
  return { service, states, sends: () => sends };
}

const lastState = (states: Array<Record<string, unknown>>) => states[states.length - 1];

test("a server without Firebase records DISABLED instead of finishing as if sent", async () => {
  const { service, states, sends } = harness({ enabled: false });
  await service.dispatchNotification("notification-1");
  assert.equal(lastState(states)?.pushState, PushDeliveryState.DISABLED);
  assert.equal(sends(), 0);
});

test("each silent outcome records its own state: read first, push off, no phone", async () => {
  const read = harness({ notification: { readAt: new Date() } });
  await read.service.dispatchNotification("notification-1");
  assert.equal(lastState(read.states)?.pushState, PushDeliveryState.SKIPPED_READ);

  const off = harness({ pushEnabled: false });
  await off.service.dispatchNotification("notification-1");
  assert.equal(lastState(off.states)?.pushState, PushDeliveryState.PREFERENCE_OFF);

  const none = harness({ installations: [] });
  await none.service.dispatchNotification("notification-1");
  assert.equal(lastState(none.states)?.pushState, PushDeliveryState.NO_DEVICE);
  for (const run of [read, off, none]) assert.equal(run.sends(), 0);
});

test("Firebase's acceptance is recorded as ACCEPTED with the count of phones, never as delivered", async () => {
  const { service, states } = harness({
    installations: [
      { id: "installation-1", fid: "fid-1" },
      { id: "installation-2", fid: "fid-2" },
    ],
  });
  await service.dispatchNotification("notification-1");
  const state = lastState(states)!;
  assert.equal(state.pushState, PushDeliveryState.ACCEPTED);
  assert.equal(state.pushAcceptedDevices, 2);
  assert.equal(state.pushLastError, null);
  assert.equal(Object.values(PushDeliveryState).includes("DELIVERED" as never), false);
});

test("some phones accepted and one to retry is PARTIAL and retried; none accepted is RETRYING", async () => {
  const partial = harness({
    installations: [
      { id: "installation-1", fid: "fid-1" },
      { id: "installation-2", fid: "fid-2" },
    ],
    send: async () => ({
      responses: [
        { success: true },
        { success: false, error: { code: "messaging/internal-error" } },
      ],
    }),
  });
  await assert.rejects(
    () => partial.service.dispatchNotification("notification-1"),
    (error: any) => {
      assert.equal(error.name, "PushDeliveryRetryRequired");
      assert.deepEqual(error.deliveredInstallationIds, ["installation-1"]);
      return true;
    },
  );
  assert.equal(lastState(partial.states)?.pushState, PushDeliveryState.PARTIAL);
  assert.equal(lastState(partial.states)?.pushAcceptedDevices, 1);
  assert.equal(lastState(partial.states)?.pushLastError, "messaging/internal-error");

  const none = harness({
    installations: [{ id: "installation-1", fid: "fid-1" }],
    send: async () => {
      throw Object.assign(new Error("unavailable"), { code: "messaging/server-unavailable" });
    },
  });
  await assert.rejects(() => none.service.dispatchNotification("notification-1"));
  assert.equal(lastState(none.states)?.pushState, PushDeliveryState.RETRYING);
});

test("a refusal of the server's Firebase configuration fails at once with its code, not retried", async () => {
  for (const code of [
    "messaging/mismatched-credential",
    "messaging/sender-id-mismatch",
    "messaging/third-party-auth-error",
    "messaging/invalid-argument",
  ]) {
    const perPhone = harness({
      installations: [{ id: "installation-1", fid: "fid-1" }],
      send: async () => ({ responses: [{ success: false, error: { code } }] }),
    });
    // Resolves: the outbox marks the event done, nothing is retried.
    await perPhone.service.dispatchNotification("notification-1");
    assert.equal(lastState(perPhone.states)?.pushState, PushDeliveryState.FAILED, code);
    assert.equal(lastState(perPhone.states)?.pushLastError, code);

    const thrown = harness({
      installations: [{ id: "installation-1", fid: "fid-1" }],
      send: async () => {
        throw Object.assign(new Error("refused"), { code });
      },
    });
    await thrown.service.dispatchNotification("notification-1");
    assert.equal(lastState(thrown.states)?.pushState, PushDeliveryState.FAILED, code);
  }
});

test("a phone that is gone leaves NO_DEVICE with its code when it was the only one", async () => {
  const { service, states } = harness({
    installations: [{ id: "installation-1", fid: "fid-1" }],
    send: async () => ({
      responses: [{ success: false, error: { code: "messaging/registration-token-not-registered" } }],
    }),
  });
  await service.dispatchNotification("notification-1");
  assert.equal(lastState(states)?.pushState, PushDeliveryState.NO_DEVICE);
  assert.equal(lastState(states)?.pushLastError, "messaging/registration-token-not-registered");
});

test("retries ran out: the notice says FAILED, keeping the Firebase code of the last try", async () => {
  const { service, states } = harness({});
  await service.recordPushFailed("notification-1", "PushDeliveryRetryRequired");
  assert.equal(lastState(states)?.pushState, PushDeliveryState.FAILED);
  assert.equal("pushLastError" in lastState(states)!, false);
  assert.deepEqual((lastState(states)!.where as any).pushState, { not: PushDeliveryState.ACCEPTED });
  await service.recordPushFailed("notification-1", "InvalidOutboxPayload");
  assert.equal(lastState(states)?.pushLastError, "InvalidOutboxPayload");
});

test("the outbox worker records FAILED on the notice when a push's retries run out, not before", async () => {
  const failed: Array<[string, string]> = [];
  const dispatcher = new OutboxDispatcher(
    {} as never,
    {
      dispatchNotification: async () => {
        const error = new Error("PushDeliveryRetryRequired") as Error & {
          deliveredInstallationIds: string[];
        };
        error.name = "PushDeliveryRetryRequired";
        error.deliveredInstallationIds = [];
        throw error;
      },
      recordPushFailed: async (id: string, code: string) => {
        failed.push([id, code]);
      },
      releaseUserInstallations: async () => undefined,
      releaseSessionInstallations: async () => undefined,
      moveSessionInstallations: async () => undefined,
    },
  );
  const worker = new OutboxWorker(
    { outboxEvent: { updateMany: async () => ({ count: 1 }) } } as never,
    dispatcher,
  );
  const now = new Date("2026-11-26T10:00:00.000Z");
  const event = (attemptCount: number): OutboxEvent => ({
    id: "event-1",
    type: OutboxEventTypes.pushNotificationRequested,
    aggregateType: "notification",
    aggregateId: "notification-1",
    payload: { notificationId: "notification-1" },
    status: "PROCESSING",
    attemptCount,
    nextAttemptAt: now,
    lockedAt: now,
    lockedBy: "worker",
    processedAt: null,
    lastError: null,
    createdAt: now,
    updatedAt: now,
  });
  await (worker as any).process(event(7));
  assert.deepEqual(failed, []);
  await (worker as any).process(event(8));
  assert.deepEqual(failed, [["notification-1", "PushDeliveryRetryRequired"]]);
});

// ── The recipient still holds the right when the push goes out ────────

test("a push goes out only while its recipient keeps the plan right its type needs", async () => {
  const cases: Array<[NotificationType, Member, boolean]> = [
    [NotificationType.PAYMENT_SCHEDULE_DUE_SOON, { canViewMoney: false }, false],
    [NotificationType.PAYMENT_SCHEDULE_DUE_SOON, { canViewMoney: true }, true],
    [NotificationType.TASK_DUE_SOON, { canManageTasks: false }, false],
    [NotificationType.TASK_DUE_SOON, { canManageTasks: true }, true],
    [NotificationType.QUOTE_OFFER_RECEIVED, { canManageProviders: false }, false],
    [NotificationType.QUOTE_OFFER_RECEIVED, { canManageProviders: true }, true],
    [NotificationType.WEDDING_COUNTDOWN, {}, true],
  ];
  for (const [type, member, allowed] of cases) {
    const run = harness({
      notification: { type, data: { recipientAudience: "CUSTOMER" } },
      owner: "owner-1",
      member,
      installations: [{ id: "installation-1", fid: "fid-1" }],
    });
    await run.service.dispatchNotification("notification-1");
    assert.equal(
      lastState(run.states)?.pushState,
      allowed ? PushDeliveryState.ACCEPTED : PushDeliveryState.SKIPPED_NO_ACCESS,
      `${type} ${JSON.stringify(member)}`,
    );
  }
  // A member who left, or a plan waiting out its deletion, is no access;
  // the owner always is.
  const left = harness({ owner: "owner-1", member: null });
  await left.service.dispatchNotification("notification-1");
  assert.equal(lastState(left.states)?.pushState, PushDeliveryState.SKIPPED_NO_ACCESS);
  const closing = harness({ owner: "owner-1", member: { canManageTasks: true }, deletionPending: true });
  await closing.service.dispatchNotification("notification-1");
  assert.equal(lastState(closing.states)?.pushState, PushDeliveryState.SKIPPED_NO_ACCESS);
  const owner = harness({ installations: [{ id: "installation-1", fid: "fid-1" }] });
  await owner.service.dispatchNotification("notification-1");
  assert.equal(lastState(owner.states)?.pushState, PushDeliveryState.ACCEPTED);
});

test("the rights a push needs follow its type; a provider's own notice and an invitation need none", () => {
  const right = (type: NotificationType, data: unknown = {}, weddingPlanId: string | null = "plan-1") =>
    pushPlanRight({ type, weddingPlanId, data });
  assert.equal(right(NotificationType.FUNDING_EXPECTED), "MONEY");
  assert.equal(right(NotificationType.TASK_OVERDUE), "TASKS");
  assert.equal(right(NotificationType.BOOKING_UPDATED, { recipientAudience: "CUSTOMER" }), "PROVIDERS");
  assert.equal(right(NotificationType.BOOKING_UPDATED, { recipientAudience: "PROVIDER" }), "NONE");
  assert.equal(right(NotificationType.SHARING_INVITATION), "NONE");
  assert.equal(right(NotificationType.GUEST_RESPONDED), "MEMBER");
  assert.equal(right(NotificationType.TASK_OVERDUE, {}, null), "NONE");
});

// ── Quiet hours and the wedding week ──────────────────────────────────

const aden = (day: string, time: string) => new Date(`${day}T${time}:00+03:00`);
const night = aden("2026-12-10", "23:30");
const weddingIn = (days: number) => new Date(Date.UTC(2026, 11, 10 + days));

test("the wedding week's urgent news comes through the night: 8 days before held, 7 through, the day through, the day after held", () => {
  const cancelled = { recipientAudience: "CUSTOMER", bookingEvent: "CANCELLED" };
  const at = (days: number) =>
    pushNotBefore(NotificationType.BOOKING_UPDATED, night, {
      weddingPlanId: "plan-1",
      weddingDate: weddingIn(days),
      data: cancelled,
    });
  assert.notEqual(at(8), null, "8 days before: held");
  assert.equal(at(7), null, "7 days before: through");
  assert.equal(at(3), null);
  assert.equal(at(0), null, "the day itself: through");
  assert.notEqual(at(-1), null, "the day after: held");
  // In the day it goes out either way.
  assert.equal(
    pushNotBefore(NotificationType.BOOKING_UPDATED, aden("2026-12-10", "12:00"), {
      weddingPlanId: "plan-1",
      weddingDate: weddingIn(8),
      data: cancelled,
    }),
    null,
  );
});

test("in the wedding week only the news that changes the wedding comes through; the rest waits", () => {
  const week = { weddingPlanId: "plan-1", weddingDate: weddingIn(3) };
  const through = (type: NotificationType, data: unknown) =>
    bypassesQuietHours(type, night, { ...week, data });
  for (const bookingEvent of ["DECLINED", "CANCELLED", "PROVIDER_SUSPENDED", "PROVIDER_CLOSED", "CHANGE_ACCEPTED", "CHANGE_DECLINED"]) {
    assert.equal(through(NotificationType.BOOKING_UPDATED, { recipientAudience: "CUSTOMER", bookingEvent }), true, bookingEvent);
  }
  assert.equal(through(NotificationType.BOOKING_UPDATED, { recipientAudience: "CUSTOMER", bookingEvent: "CONFIRMED" }), false);
  assert.equal(through(NotificationType.BOOKING_UPDATED, { recipientAudience: "CUSTOMER", reminder: true }), false);
  assert.equal(through(NotificationType.QUOTE_REJECTED, { recipientAudience: "CUSTOMER", status: "REJECTED" }), true);
  assert.equal(through(NotificationType.QUOTE_REJECTED, { recipientAudience: "CUSTOMER", status: "WITHDRAWN" }), true);
  assert.equal(through(NotificationType.QUOTE_REJECTED, { recipientAudience: "CUSTOMER", status: "EXPIRED" }), false);
  assert.equal(through(NotificationType.QUOTE_REJECTED, { recipientAudience: "PROVIDER", status: "REJECTED" }), false);
  assert.equal(through(NotificationType.PAYMENT_SCHEDULE_OVERDUE, {}), true);
  assert.equal(
    through(NotificationType.PAYMENT_SCHEDULE_DUE_SOON, { dueDate: "2026-12-10T00:00:00.000Z" }),
    true,
    "due today",
  );
  assert.equal(
    through(NotificationType.PAYMENT_SCHEDULE_DUE_SOON, { dueDate: "2026-12-11T00:00:00.000Z" }),
    false,
    "due tomorrow",
  );
  assert.equal(through(NotificationType.TASK_DUE_SOON, { daysUntil: 1 }), false);
  assert.equal(through(NotificationType.WEDDING_COUNTDOWN, { daysUntil: 3 }), false);
});

test("on the wedding day every notice of the plan comes through, except the guests' replies digest", () => {
  const day = { weddingPlanId: "plan-1", weddingDate: weddingIn(0) };
  for (const type of [
    NotificationType.TASK_DUE_SOON,
    NotificationType.WEDDING_COUNTDOWN,
    NotificationType.QUOTE_OFFER_RECEIVED,
    NotificationType.FUNDING_EXPECTED,
  ]) {
    assert.equal(bypassesQuietHours(type, night, { ...day, data: {} }), true, type);
  }
  assert.equal(bypassesQuietHours(NotificationType.GUEST_RESPONDED, night, day), false);
  // A notice of no plan, or a plan with no date, waits as before.
  assert.equal(bypassesQuietHours(NotificationType.TASK_DUE_SOON, night, { weddingPlanId: null, weddingDate: weddingIn(0) }), false);
  assert.equal(bypassesQuietHours(NotificationType.TASK_DUE_SOON, night, { weddingPlanId: "plan-1", weddingDate: null }), false);
  // Chat and a booking request still go at any hour.
  assert.equal(pushNotBefore(NotificationType.CHAT_MESSAGE_RECEIVED, night), null);
});

// ── The new pushes and their lock-screen words ────────────────────────

test("the new pushes have a channel and generic words: no name, amount or count on the lock screen", () => {
  const cases: Array<[NotificationType, unknown, string]> = [
    [NotificationType.QUOTE_REJECTED, { recipientAudience: "CUSTOMER", status: "REJECTED" }, "اعتذار عن طلب"],
    [NotificationType.QUOTE_REJECTED, { recipientAudience: "CUSTOMER", status: "WITHDRAWN" }, "سُحب عرض"],
    [NotificationType.QUOTE_REJECTED, { recipientAudience: "CUSTOMER", status: "EXPIRED" }, "انتهى طلب دون رد"],
    [NotificationType.QUOTE_REJECTED, { recipientAudience: "PROVIDER", status: "REJECTED" }, "عرضك ما انقبل"],
    [NotificationType.SHARING_INVITATION, {}, "دعوة إلى خطة عرس"],
    [NotificationType.SHARING_INVITE_ACCEPTED, {}, "قُبلت الدعوة"],
    [NotificationType.REVIEW_RECEIVED, { recipientAudience: "PROVIDER", rating: 2 }, "تقييم جديد"],
    [NotificationType.GUEST_RESPONDED, { repliesCount: 12 }, "ردود جديدة"],
  ];
  for (const [type, data, title] of cases) {
    assert.equal(isPushNotificationType(type, data), true, type);
    assert.ok(pushAndroidChannelId(type), type);
    const copy = pushNotificationCopy(type, data);
    assert.equal(copy.title, title, type);
    assert.match(copy.body, /في اعّرست/u);
    assert.doesNotMatch(copy.title + copy.body, /\d/u, type);
    // The new words are plain Modern Standard Arabic, no request formula.
    assert.doesNotMatch(copy.title + copy.body, /يرجى|تعذّر|اللي|الحين|ايش|عشان/u, type);
  }
  assert.equal(pushNotificationCopy(NotificationType.GUEST_RESPONDED).body, "وصلت ردود جديدة على دعوتك، والتفاصيل في اعّرست.");
});

// ── Who hears a provider's news about a plan ──────────────────────────

test("a provider's news reaches the owner and every member managing providers, once each, never the actor", async () => {
  const locked: unknown[] = [];
  const service = notificationsService({} as any, {} as any, new OutboxService());
  const tx = {
    $queryRaw: async () => [],
    weddingPlan: {
      findUnique: async () => ({ id: "plan-1", ownerUserId: "owner-1" }),
      findFirst: async () => ({ id: "plan-1", ownerUserId: "owner-1" }),
    },
  };
  (service as any).permissions = {
    lockPlanMembershipsForShareInTransaction: async (_tx: unknown, ids: string[]) => {
      locked.push(ids);
    },
    listPlanMembers: async () => [
      { weddingPlanId: "plan-1", userId: "partner-1", canManageProviders: true, receiveNotifications: true },
      { weddingPlanId: "plan-1", userId: "helper-1", canManageProviders: false, receiveNotifications: true },
      { weddingPlanId: "plan-1", userId: "quiet-1", canManageProviders: true, receiveNotifications: false },
      { weddingPlanId: "plan-1", userId: "requester-1", canManageProviders: true, receiveNotifications: false },
      { weddingPlanId: "plan-1", userId: "owner-1", canManageProviders: true, receiveNotifications: true },
    ],
  };
  (service as any).plans = {
    getPlan: async () => ({ id: "plan-1", ownerUserId: "owner-1" }),
  };
  assert.deepEqual(
    await service.resolveProviderUpdateRecipientsInTransaction(tx as any, "plan-1", "requester-1"),
    ["owner-1", "partner-1", "requester-1"],
  );
  assert.deepEqual(locked, [["plan-1"]]);
  assert.deepEqual(
    await service.resolveProviderUpdateRecipientsInTransaction(tx as any, "plan-1", "requester-1", ["partner-1"]),
    ["owner-1", "requester-1"],
  );
  // A request of no plan has its requester only.
  assert.deepEqual(
    await service.resolveProviderUpdateRecipientsInTransaction(tx as any, null, "requester-1"),
    ["requester-1"],
  );

  const created: any[] = [];
  (service as any).createNotificationInTransaction = async (_tx: unknown, input: any) => {
    created.push(input);
    return input;
  };
  await service.createProviderUpdateNotificationsInTransaction(
    tx as any,
    {
      userId: "requester-1",
      weddingPlanId: "plan-1",
      type: NotificationType.QUOTE_OFFER_RECEIVED,
      title: "t",
      body: "b",
      dedupeKey: "requester-1:quote-offer:offer-1",
    },
    ["provider-user"],
  );
  assert.deepEqual(
    created.map((input) => [input.userId, input.dedupeKey]),
    [
      ["owner-1", "owner-1:quote-offer:offer-1"],
      ["partner-1", "partner-1:quote-offer:offer-1"],
      ["requester-1", "requester-1:quote-offer:offer-1"],
    ],
  );
});

test("a notice re-keyed for another reader keeps its key unique per reader", () => {
  const base = {
    userId: "a",
    type: NotificationType.BOOKING_UPDATED,
    title: "t",
    body: "b",
    dedupeKey: "a:booking:1:CANCELLED:5",
  };
  assert.equal(noticeForRecipient(base, "a"), base);
  assert.equal(noticeForRecipient(base, "b").dedupeKey, "b:booking:1:CANCELLED:5");
  assert.equal(noticeForRecipient({ ...base, dedupeKey: "odd-key" }, "b").dedupeKey, "b:odd-key");
  assert.equal(noticeForRecipient({ ...base, dedupeKey: undefined }, "b").dedupeKey, undefined);
});

// ── The guests' replies as a digest ───────────────────────────────────

test("the guests' replies push at most once every three hours per plan; a reply inside the window is folded in", async () => {
  const rows: Array<Record<string, any>> = [];
  const outbox: Array<Record<string, any>> = [];
  const tx = {
    $queryRaw: async () => [{ id: "owner-1", status: "ACTIVE" }],
    user: { findMany: async () => [] },
    notificationPreference: { findUnique: async () => null },
    weddingPlan: { findUnique: async () => null, findFirst: async () => null },
    notification: {
      findUnique: async ({ where }: any) => rows.find((row) => row.dedupeKey === where.dedupeKey) ?? null,
      findFirst: async ({ where }: any) =>
        rows
          .filter(
            (row) =>
              row.userId === where.userId &&
              row.weddingPlanId === where.weddingPlanId &&
              row.type === where.type &&
              row.pushRequestedAt instanceof Date &&
              row.pushRequestedAt >= where.pushRequestedAt.gte,
          )
          .map((row) => ({ id: row.id }))
          .pop() ?? null,
      create: async ({ data }: any) => {
        const row = { ...data, id: `notification-${rows.length + 1}`, readAt: null, archivedAt: null, createdAt: new Date(), updatedAt: new Date() };
        rows.push(row);
        return row;
      },
      update: async ({ where, data }: any) => {
        const row = rows.find((candidate) => candidate.id === where.id)!;
        Object.assign(row, data);
        return row;
      },
    },
    outboxEvent: {
      create: async ({ data }: any) => {
        outbox.push(data);
        return { id: `outbox-${outbox.length}` };
      },
    },
  };
  const service = notificationsService({} as any, {} as any, new OutboxService());
  const reply = (hour: number) => ({
    userId: "owner-1",
    weddingPlanId: "plan-1",
    type: NotificationType.GUEST_RESPONDED,
    title: "وصلتك ردود جديدة من الضيوف",
    body: "الرد وصل من رابط الدعوة.",
    dedupeKey: `owner-1:guest-responded:plan-1:hour-${hour}`,
    mergeIntoExisting: true,
  });
  const pushes = () => outbox.filter((event) => event.type === OutboxEventTypes.pushNotificationRequested);

  await service.createNotificationInTransaction(tx as any, reply(1));
  assert.equal(pushes().length, 1);
  assert.equal(rows[0]!.pushState === PushDeliveryState.QUEUED || rows[0]!.pushState === PushDeliveryState.HELD, true);
  // Never through the night.
  assert.equal(pushes()[0]!.payload.heldThroughQuietHours, true);

  // A merged reply in the same hour, and a new hour's notice: inside the window.
  await service.createNotificationInTransaction(tx as any, reply(1));
  await service.createNotificationInTransaction(tx as any, reply(2));
  assert.equal(pushes().length, 1);
  assert.equal(rows[1]!.pushState, PushDeliveryState.SKIPPED_DIGEST);
  assert.equal(rows[1]!.pushRequestedAt, undefined);

  // Three hours after the push, the next reply pushes again.
  rows[0]!.pushRequestedAt = new Date(Date.now() - 3 * 60 * 60 * 1000 - 1000);
  await service.createNotificationInTransaction(tx as any, reply(4));
  assert.equal(pushes().length, 2);
});

// ── The opened acknowledgement ────────────────────────────────────────

test("PATCH /api/v1/notifications/:id/opened answers 204 and marks opened and read for the notice's own reader", async () => {
  const proto = NotificationsController.prototype as any;
  assert.equal(Reflect.getMetadata("path", proto.markOpened), ":id/opened");
  assert.equal(Reflect.getMetadata("method", proto.markOpened), 4 /* RequestMethod.PATCH */);
  assert.equal(Reflect.getMetadata("__httpCode__", proto.markOpened), 204);

  const calls: unknown[] = [];
  const controller = new NotificationsController({
    markOpened: async (user: unknown, id: string) => {
      calls.push([user, id]);
    },
  } as never);
  assert.equal(await controller.markOpened({ id: "user-1" } as never, "notification-1"), undefined);
  assert.deepEqual(calls, [[{ id: "user-1" }, "notification-1"]]);

  // Idempotent: opened and read are each set only while still empty.
  const writes: any[] = [];
  const service = notificationsService({
    $transaction: async (operation: any) => operation(tx),
  } as any, {} as any, new OutboxService());
  const tx = {
    notification: {
      updateMany: async (args: any) => {
        writes.push(args);
        return { count: 1 };
      },
    },
  };
  (service as any).lockOwnedForMutation = async (_tx: unknown, user: any, id: string) => {
    if (user.id !== "user-1") throw new Error("Notification not found");
    return { id };
  };
  (service as any).prisma = { $transaction: async (operation: any) => operation(tx) };
  await service.markOpened({ id: "user-1" } as never, "notification-1");
  assert.deepEqual(writes.map((write) => write.where), [
    { id: "notification-1", openedAt: null },
    { id: "notification-1", readAt: null },
  ]);
  await assert.rejects(() => service.markOpened({ id: "someone-else" } as never, "notification-1"));
});

// ── The five-minute task-reminder scan ────────────────────────────────

test("a task's own reminder time has its own five-minute scan; the hourly scan keeps the rest", async () => {
  const calls: unknown[] = [];
  const scheduler = new NotificationRemindersScheduler({
    generateDueNotifications: async (options: unknown) => {
      calls.push(options);
      return 0;
    },
  } as never);
  await scheduler.generateTaskReminderTimes();
  await scheduler.generateDueReminders(aden("2026-12-10", "12:05"));
  assert.deepEqual(calls, [{ onlyTaskReminderTimes: true }, { dayReminders: true }]);
});

// ── The server says whether it pushes ─────────────────────────────────

test("the production Firebase project is pinned when the host names it", () => {
  const environment = {
    NODE_ENV: "development",
    DATABASE_URL: "postgresql://local/test",
    JWT_SECRET: "a".repeat(64),
    AUTH_OTP_MODE: "disabled",
    PUSH_NOTIFICATIONS_ENABLED: "true",
    FIREBASE_PROJECT_ID: "aarast-prod",
  };
  assert.doesNotThrow(() => validateRuntimeEnvironment(environment, getJwtSecret));
  assert.doesNotThrow(() =>
    validateRuntimeEnvironment({ ...environment, FIREBASE_EXPECTED_PROJECT_ID: "aarast-prod" }, getJwtSecret),
  );
  assert.throws(
    () =>
      validateRuntimeEnvironment(
        { ...environment, FIREBASE_PROJECT_ID: "aarast-staging-qa", FIREBASE_EXPECTED_PROJECT_ID: "aarast-prod" },
        getJwtSecret,
      ),
    /FIREBASE_EXPECTED_PROJECT_ID/,
  );
});

test("the operator's /ready says whether push is on and for which project; the public one does not", async () => {
  const previous = {
    enabled: process.env.PUSH_NOTIFICATIONS_ENABLED,
    project: process.env.FIREBASE_PROJECT_ID,
  };
  try {
    process.env.PUSH_NOTIFICATIONS_ENABLED = "true";
    process.env.FIREBASE_PROJECT_ID = "aarast-prod";
    const service = new ReadinessService(
      { $queryRawUnsafe: async () => [1] } as never,
      { checkReadiness: async () => undefined } as never,
    );
    const report = await service.check();
    assert.deepEqual(report.checks.push, { status: "up", enabled: true, projectId: "aarast-prod" });
    assert.equal("push" in publicReadiness(report).checks, false);
    process.env.PUSH_NOTIFICATIONS_ENABLED = "false";
    const off = await service.check();
    assert.deepEqual(off.checks.push, { status: "disabled", enabled: false, projectId: null });
    // Push off never fails /ready: the same dependencies read the same.
    assert.equal(off.status, report.status);
  } finally {
    if (previous.enabled === undefined) delete process.env.PUSH_NOTIFICATIONS_ENABLED;
    else process.env.PUSH_NOTIFICATIONS_ENABLED = previous.enabled;
    if (previous.project === undefined) delete process.env.FIREBASE_PROJECT_ID;
    else process.env.FIREBASE_PROJECT_ID = previous.project;
  }
});
