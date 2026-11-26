import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import {
  AdminRole,
  ConversationReportStatus,
  NotificationType,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { AdminMutationExecutor } from "../src/admin/admin-mutation-executor";
import {
  AdminPermission,
  hasAdminPermission,
} from "../src/modules/backoffice/domain/admin-permissions";
import { MessagingAdminService } from "../src/modules/messaging/infrastructure/messaging-admin.service";
import { OutboxService } from "../src/platform/outbox/outbox.service";
import { PermissionService } from "../src/modules/collaboration/internal/permission.service";
import { PrismaService } from "../src/platform/database/prisma.service";
import {
  isPushNotificationType,
  pushAndroidChannelId,
  pushNotBefore,
  pushNotificationCopy,
} from "../src/push/push-notification.policy";
import { NOTIFICATION_ROUTES } from "../src/shared-kernel/routes/notification-routes";
import { notificationsService } from "./support/owner-ports";

// Q-50 (أ), D124 (RA-AD-22): the operations team reads the reports it acts
// on (it suspends and disables, the moderator does not); closing a report
// takes a reason, and the reporter is told it as a notification, under his
// notification switches and the quiet hours.

test("Q-50: operations reads the reports and does not close them; the moderator keeps both", () => {
  assert.equal(hasAdminPermission(AdminRole.OPERATIONS, AdminPermission.CONVERSATION_REPORTS_READ), true);
  assert.equal(hasAdminPermission(AdminRole.OPERATIONS, AdminPermission.CONVERSATION_REPORTS_WRITE), false);
  assert.equal(hasAdminPermission(AdminRole.MODERATOR, AdminPermission.CONVERSATION_REPORTS_READ), true);
  assert.equal(hasAdminPermission(AdminRole.MODERATOR, AdminPermission.CONVERSATION_REPORTS_WRITE), true);
  // The moderator still suspends no provider (option (أ), not (ب)).
  assert.equal(hasAdminPermission(AdminRole.MODERATOR, AdminPermission.PROVIDERS_WRITE), false);
  assert.equal(hasAdminPermission(AdminRole.SUPPORT, AdminPermission.CONVERSATION_REPORTS_READ), false);
});

type Notice = Record<string, any>;

function harness(options: { providerUserId?: string | null; current?: ConversationReportStatus } = {}) {
  const sets: Array<{ id: string; change: Record<string, unknown> }> = [];
  const notices: Notice[] = [];
  const tx = {} as never;
  const prisma = {
    $transaction: async (run: (client: unknown) => Promise<unknown>) => run(tx),
  } as unknown as PrismaService;
  const owners = {
    accounts: {
      lockAccountsForUpdateInTransaction: async () => [
        { id: "admin-1", role: UserRole.ADMIN, adminRole: AdminRole.MODERATOR, status: UserStatus.ACTIVE },
      ],
    },
    messaging: {
      lockConversationReportForUpdateInTransaction: async (_tx: unknown, id: string) =>
        id === "report-1"
          ? {
              status: options.current ?? ConversationReportStatus.OPEN,
              reporterUserId: "reporter-1",
              conversationId: "conversation-1",
              providerId: "provider-1",
            }
          : null,
      setConversationReportStatusInTransaction: async (_tx: unknown, id: string, change: Record<string, unknown>) => {
        sets.push({ id, change });
        return { id, conversationId: "conversation-1", reason: "إزعاج", ...change, createdAt: new Date(0), updatedAt: new Date(0) };
      },
    },
    marketplace: {
      findProviderAccount: async () => ({ userId: options.providerUserId ?? "provider-owner" }),
    },
  };
  const notifications = {
    createNotificationInTransaction: async (_client: unknown, input: Notice) => {
      notices.push(input);
      return null;
    },
  };
  const executor = new AdminMutationExecutor(prisma, owners as never, notifications as never);
  return { executor, sets, notices };
}

const admin = { id: "admin-1" } as never;

test("Q-50: a report is not closed without the reason its reporter is told", async () => {
  const { executor, sets, notices } = harness();
  for (const note of [undefined, "", "   "]) {
    await assert.rejects(
      () => executor.updateConversationReportStatus(admin, "report-1", { status: "REVIEWED", note }),
      BadRequestException,
    );
  }
  await assert.rejects(
    () => executor.updateConversationReportStatus(admin, "report-1", { status: "DISMISSED", note: "ا".repeat(501) }),
    BadRequestException,
  );
  assert.deepEqual(sets, []);
  assert.deepEqual(notices, []);
});

test("Q-50: closing keeps the reason and its time, and tells the customer who reported", async () => {
  const { executor, sets, notices } = harness();
  await executor.updateConversationReportStatus(admin, "report-1", {
    status: "REVIEWED",
    note: "  نبهنا المزود، وما يتكرر  ",
  });
  assert.equal(sets.length, 1);
  assert.equal(sets[0]!.change.status, ConversationReportStatus.REVIEWED);
  assert.equal(sets[0]!.change.closingNote, "نبهنا المزود، وما يتكرر");
  assert.ok(sets[0]!.change.closedAt instanceof Date);

  assert.equal(notices.length, 1);
  const notice = notices[0]!;
  assert.equal(notice.userId, "reporter-1");
  assert.equal(notice.type, NotificationType.CONVERSATION_REPORT_CLOSED);
  assert.equal(notice.title, "راجعنا بلاغك");
  assert.equal(notice.body, "نبهنا المزود، وما يتكرر");
  assert.equal(notice.routeTarget, "/conversations/conversation-1");
  assert.equal(notice.entityType, "ConversationReport");
  assert.equal(notice.entityId, "report-1");
  assert.equal(notice.dedupeKey, "conversation-report:report-1:REVIEWED");
  // A customer's notice names no provider audience.
  assert.equal(notice.data.recipientAudience, undefined);
});

test("Q-50: a provider who reported is told in his own notices", async () => {
  const { executor, notices } = harness({ providerUserId: "reporter-1" });
  await executor.updateConversationReportStatus(admin, "report-1", {
    status: "DISMISSED",
    note: "ما لقينا مخالفة في المحادثة",
  });
  assert.equal(notices[0]!.data.recipientAudience, "PROVIDER");
  assert.equal(notices[0]!.dedupeKey, "conversation-report:report-1:DISMISSED");
});

test("Q-50: reopening a report clears its reason and tells no one", async () => {
  const { executor, sets, notices } = harness({ current: ConversationReportStatus.REVIEWED });
  await executor.updateConversationReportStatus(admin, "report-1", { status: "OPEN" });
  assert.deepEqual(sets[0]!.change, {
    status: ConversationReportStatus.OPEN,
    closingNote: null,
    closedAt: null,
  });
  assert.deepEqual(notices, []);
});

test("Q-50: messaging locks the report with whom to tell, and writes the reason with the status", async () => {
  const calls: Array<[string, unknown]> = [];
  const client = {
    $queryRaw: async (query: unknown) => {
      calls.push(["$queryRaw", query]);
      return [{ status: "OPEN", reporterUserId: "reporter-1", conversationId: "conversation-1", providerId: "provider-1" }];
    },
    conversationReport: {
      update: async (args: unknown) => {
        calls.push(["conversationReport.update", args]);
        return { id: "report-1" };
      },
    },
  };
  const service = new MessagingAdminService();
  assert.deepEqual(await service.lockConversationReportForUpdateInTransaction(client as never, "report-1"), {
    status: "OPEN",
    reporterUserId: "reporter-1",
    conversationId: "conversation-1",
    providerId: "provider-1",
  });
  assert.match((calls[0]![1] as { sql: string }).sql, /FROM "ConversationReport"[\s\S]*FOR UPDATE/);
  const closedAt = new Date("2026-11-25T10:00:00Z");
  await service.setConversationReportStatusInTransaction(client as never, "report-1", {
    status: ConversationReportStatus.DISMISSED,
    closingNote: "ما فيه شيء",
    closedAt,
  });
  assert.deepEqual((calls[1]![1] as { data: unknown }).data, {
    status: ConversationReportStatus.DISMISSED,
    closingNote: "ما فيه شيء",
    closedAt,
  });
});

/** An instant at `hhmm` Aden time on 2026-11-24 (UTC+3). */
function aden(hhmm: string): Date {
  const [hours, minutes] = hhmm.split(":").map(Number);
  return new Date(Date.parse("2026-11-24T00:00:00.000Z") + ((hours! - 3) * 60 + minutes!) * 60_000);
}

test("Q-50: the notice reaches the phone on the messages channel, held through the quiet hours, with nothing of the report on the lock screen", () => {
  const type = NotificationType.CONVERSATION_REPORT_CLOSED;
  assert.equal(isPushNotificationType(type, {}), true);
  assert.equal(pushAndroidChannelId(type), "aarast_messages");
  assert.notEqual(pushNotBefore(type, aden("23:30")), null);
  assert.equal(pushNotBefore(type, aden("12:00")), null);
  assert.deepEqual(pushNotificationCopy(type), {
    title: "رُوجع بلاغك",
    body: "ما تم فيه تجده في اعّرست.",
  });
  assert.deepEqual([...NOTIFICATION_ROUTES.CONVERSATION_REPORT_CLOSED], ["/conversations/:conversationId"]);
});

test("Q-50: the notice is under the messages switch: off, nothing is written or sent", async () => {
  let written = 0;
  const client = {
    $queryRaw: async () => [{ id: "reporter-1" }],
    user: { findMany: async () => [] },
    notificationPreference: {
      findUnique: async () => ({
        taskRemindersEnabled: true,
        paymentRemindersEnabled: true,
        providerMessagesEnabled: false,
        bookingRemindersEnabled: true,
      }),
    },
    notification: { create: async () => ++written },
    outboxEvent: { create: async () => ++written },
  };
  const service = notificationsService({} as PrismaService, {} as PermissionService, new OutboxService());
  const created = await service.createNotificationInTransaction(client as never, {
    userId: "reporter-1",
    type: NotificationType.CONVERSATION_REPORT_CLOSED,
    title: "راجعنا بلاغك",
    body: "نبهنا المزود",
  });
  assert.equal(created, null);
  assert.equal(written, 0);
});
