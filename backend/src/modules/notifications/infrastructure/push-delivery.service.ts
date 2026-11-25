import { Inject, Injectable, Logger } from "@nestjs/common";
import {
  Notification,
  NotificationType,
  PushDeliveryState,
} from "@prisma/client";
import { FirebasePushClient } from "../../../push/firebase-push.client";
import {
  isPushNotificationType,
  pushAndroidChannelId,
  pushNotificationCopy,
  pushPlanRight,
} from "../../../push/push-notification.policy";
import { runSerializableTransaction } from "../../../platform/database/serializable-transaction";
import { PrismaService } from "../../../platform/database/prisma.service";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort,
  isPlanDeletionPending,
  type PlanAccessContext,
} from "../../collaboration/public/collaboration-permission.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../../planning/public/plan-read.port";
import type { PushDeliveryPort } from "../public/push-delivery.port";

const MAX_FCM_TARGETS = 500;
const PUSH_TTL_MS = 7 * 24 * 60 * 60 * 1000;
/** The phone is gone: its registration is let go. */
const PERMANENT_FCM_ERRORS = new Set([
  "messaging/installation-id-not-registered",
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);
/**
 * The server's own Firebase setup is refused (a credential of another
 * project, a sender the app does not know, a message Firebase cannot take):
 * no retry can succeed, so it fails at once and is logged as an error.
 */
export const CONFIGURATION_FCM_ERRORS = new Set([
  "messaging/mismatched-credential",
  "messaging/sender-id-mismatch",
  "messaging/third-party-auth-error",
  "messaging/invalid-argument",
  "app/invalid-credential",
  "PushConfigurationError",
]);

@Injectable()
export class PushDeliveryService implements PushDeliveryPort {
  private readonly logger = new Logger(PushDeliveryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebasePushClient,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: CollaborationPermissionPort,
    @Inject(PLAN_READ_PORT)
    private readonly plans: PlanReadPort,
  ) {}

  /**
   * D112 (Q-11): every session of the account was ended at [revokedAt] (a
   * new password, «اخرج من كل الأجهزة», a new number), so the phones it was
   * signed in on are no longer its phones. Their registrations go, as a
   * sign-out's own does; one made since then belongs to a phone that signed
   * in again and stays. With none left the account's push is off until a
   * phone registers again, as after any last sign-out. A new password keeps
   * the session that set it, and that phone's registration, [keepFid], stays
   * with it (RA-BE-133).
   */
  async releaseUserInstallations(
    userId: string,
    revokedAt: Date,
    keepFid?: string,
  ): Promise<void> {
    await runSerializableTransaction(this.prisma, async (tx) => {
      await tx.pushInstallation.deleteMany({
        where: {
          userId,
          lastSeenAt: { lt: revokedAt },
          ...(keepFid ? { fid: { not: keepFid } } : {}),
        },
      });
      const remaining = await tx.pushInstallation.count({
        where: { userId, enabled: true },
      });
      if (remaining === 0) {
        await tx.notificationPreference.updateMany({
          where: { userId },
          data: { pushEnabled: false },
        });
      }
    });
  }

  /**
   * RA-MO-358: the application session [sessionId] ended (a sign-out here
   * or on another phone, a refresh token used twice), so the phone that
   * registered under it is no longer the account's phone. Its registration
   * goes; an account left with none has push off until a phone registers
   * again, as after any last sign-out.
   */
  async releaseSessionInstallations(sessionId: string): Promise<void> {
    await runSerializableTransaction(this.prisma, async (tx) => {
      const released = await tx.pushInstallation.findMany({
        where: { sessionId },
        select: { userId: true },
      });
      if (released.length === 0) return;
      await tx.pushInstallation.deleteMany({ where: { sessionId } });
      for (const userId of new Set(released.map((item) => item.userId))) {
        const remaining = await tx.pushInstallation.count({
          where: { userId, enabled: true },
        });
        if (remaining === 0) {
          await tx.notificationPreference.updateMany({
            where: { userId },
            data: { pushEnabled: false },
          });
        }
      }
    });
  }

  /**
   * RA-MO-358: a refresh gives the session a new id; the registration made
   * under the old one belongs to the new, or a later sign-out would not
   * find it.
   */
  async moveSessionInstallations(
    sessionId: string,
    nextSessionId: string,
  ): Promise<void> {
    await this.prisma.pushInstallation.updateMany({
      where: { sessionId },
      data: { sessionId: nextSessionId },
    });
  }

  /**
   * Sends the notice's push and records, on the notice, what became of it
   * (`PushDeliveryState`). No outcome is silent any more: a server without
   * Firebase, push turned off, no phone, a notice read first or a recipient
   * who lost the plan right each say so. Firebase's acceptance is recorded
   * as accepted with the count of phones it took, never as delivered (it
   * gives no delivery receipt). A refusal of the server's own Firebase
   * configuration is permanent: recorded FAILED with its code and logged as
   * an error, not retried eight times.
   */
  async dispatchNotification(
    notificationId: string,
    alreadyDeliveredInstallationIds: readonly string[] = [],
  ): Promise<void> {
    // The push preference and the installations are notifications' own
    // rows keyed by the recipient; they used to be reached through
    // identity's user row.
    const notification = await this.prisma.notification.findUnique({
      where: { id: notificationId },
    });
    if (
      !notification ||
      !isPushNotificationType(notification.type, notification.data)
    ) {
      return;
    }
    if (!this.firebase.enabled) {
      await this.recordState(notification.id, PushDeliveryState.DISABLED);
      return;
    }
    // RA-BE-185: a push held through quiet hours, or retried, whose notice
    // was read meanwhile tells the person nothing new.
    if (notification.readAt) {
      await this.recordState(notification.id, PushDeliveryState.SKIPPED_READ);
      return;
    }
    if (!(await this.recipientStillEntitled(notification))) {
      await this.recordState(notification.id, PushDeliveryState.SKIPPED_NO_ACCESS);
      return;
    }
    const preference = await this.prisma.notificationPreference.findUnique({
      where: { userId: notification.userId },
      select: { pushEnabled: true },
    });
    if (preference?.pushEnabled !== true) {
      await this.recordState(notification.id, PushDeliveryState.PREFERENCE_OFF);
      return;
    }

    const installations = await this.prisma.pushInstallation.findMany({
      where: { userId: notification.userId, enabled: true },
      orderBy: { createdAt: "asc" },
      select: { id: true, fid: true, updatedAt: true },
    });
    // RA-BE-190: a retry goes to the phones the earlier try did not reach.
    const reached = new Set(alreadyDeliveredInstallationIds);
    const targets = installations.filter((item) => !reached.has(item.id));
    const fids = targets.map((item) => item.fid);
    if (fids.length === 0) {
      const accepted = installations.filter((item) => reached.has(item.id)).length;
      await this.recordState(
        notification.id,
        accepted > 0 ? PushDeliveryState.ACCEPTED : PushDeliveryState.NO_DEVICE,
        accepted > 0 ? { acceptedDevices: accepted } : {},
      );
      return;
    }

    const permanentFailures = new Set<string>();
    let transientFailure = false;
    let transientCode: string | null = null;
    let configurationFailure: string | null = null;
    let permanentCode: string | null = null;
    for (let index = 0; index < fids.length; index += MAX_FCM_TARGETS) {
      const batchFids = fids.slice(index, index + MAX_FCM_TARGETS);
      try {
        const response = await this.firebase.sendEachForMulticast({
          fids: batchFids,
          ...this.messagePayload(notification),
        });
        response.responses.forEach((item, responseIndex) => {
          if (item.success) {
            reached.add(targets[index + responseIndex]!.id);
            return;
          }
          const code = item.error?.code;
          if (code && PERMANENT_FCM_ERRORS.has(code)) {
            permanentFailures.add(batchFids[responseIndex]!);
            permanentCode ??= code;
          } else if (code && CONFIGURATION_FCM_ERRORS.has(code)) {
            configurationFailure ??= code;
          } else {
            transientFailure = true;
            transientCode ??= code ?? "unknown";
          }
        });
      } catch (error) {
        const code = firebaseErrorCode(error);
        if (CONFIGURATION_FCM_ERRORS.has(code)) {
          configurationFailure ??= code;
        } else {
          transientFailure = true;
          transientCode ??= code;
        }
      }
    }

    if (permanentFailures.size > 0) {
      const failedInstallations = installations.filter(
        (installation) => permanentFailures.has(installation.fid),
      );
      await runSerializableTransaction(this.prisma, async (tx) => {
        await tx.pushInstallation.deleteMany({
          where: {
            OR: failedInstallations.map((installation) => ({
              id: installation.id,
              userId: notification.userId,
              updatedAt: installation.updatedAt,
            })),
          },
        });
        const remainingInstallations = await tx.pushInstallation.count({
          where: { userId: notification.userId, enabled: true },
        });
        if (remainingInstallations === 0) {
          await tx.notificationPreference.updateMany({
            where: { userId: notification.userId },
            data: { pushEnabled: false },
          });
        }
      });
    }
    // Only those still registered: a phone that went away is not listed.
    const deliveredInstallationIds = installations
      .filter((item) => reached.has(item.id))
      .map((item) => item.id);
    const accepted = deliveredInstallationIds.length;
    if (configurationFailure) {
      // The server's own Firebase configuration was refused: every retry
      // would be refused the same way, so it is not retried, and the
      // operator hears of it.
      this.logger.error(
        `Push refused by Firebase configuration (${configurationFailure}) for notification ${notification.id}; not retried`,
      );
      await this.recordState(notification.id, PushDeliveryState.FAILED, {
        lastError: configurationFailure,
        ...(accepted > 0 ? { acceptedDevices: accepted } : {}),
      });
      return;
    }
    if (transientFailure) {
      await this.recordState(
        notification.id,
        accepted > 0 ? PushDeliveryState.PARTIAL : PushDeliveryState.RETRYING,
        {
          lastError: transientCode,
          ...(accepted > 0 ? { acceptedDevices: accepted } : {}),
        },
      );
      const error = new Error("PushDeliveryRetryRequired") as Error & {
        deliveredInstallationIds: string[];
      };
      error.name = "PushDeliveryRetryRequired";
      error.deliveredInstallationIds = deliveredInstallationIds;
      throw error;
    }
    if (accepted === 0) {
      // Every phone it was sent to is no longer registered (they were let
      // go just above): there is no phone to reach.
      await this.recordState(notification.id, PushDeliveryState.NO_DEVICE, {
        lastError: permanentCode,
      });
      return;
    }
    await this.recordState(notification.id, PushDeliveryState.ACCEPTED, {
      acceptedDevices: accepted,
      lastError: null,
    });
  }

  /**
   * The outbox gave up on the push (its retries ran out): the notice says
   * it failed, with the last refusal's code. A push already accepted for
   * every phone is left as it is.
   */
  async recordPushFailed(notificationId: string, lastError: string): Promise<void> {
    await this.prisma.notification.updateMany({
      where: {
        id: notificationId,
        pushState: { not: PushDeliveryState.ACCEPTED },
      },
      data: {
        pushState: PushDeliveryState.FAILED,
        pushStateAt: new Date(),
        // A retry that ran out keeps the Firebase code its last try
        // recorded; any other failure is named by its own code.
        ...(lastError === "PushDeliveryRetryRequired"
          ? {}
          : { pushLastError: shortCode(lastError) }),
      },
    });
  }

  private async recordState(
    notificationId: string,
    state: PushDeliveryState,
    detail: { acceptedDevices?: number; lastError?: string | null } = {},
  ): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { id: notificationId },
      data: {
        pushState: state,
        pushStateAt: new Date(),
        ...(detail.acceptedDevices !== undefined
          ? { pushAcceptedDevices: detail.acceptedDevices }
          : {}),
        ...(detail.lastError !== undefined
          ? { pushLastError: detail.lastError === null ? null : shortCode(detail.lastError) }
          : {}),
      },
    });
  }

  /**
   * A held or retried push leaves after its notice was written: the
   * recipient must still be the plan's owner, or a member who may enter it
   * with the right this notice needs (`pushPlanRight`), when it goes out.
   */
  private async recipientStillEntitled(
    notification: Pick<Notification, "userId" | "weddingPlanId" | "type" | "data">,
  ): Promise<boolean> {
    const right = pushPlanRight(notification);
    if (right === "NONE" || !notification.weddingPlanId) return true;
    // The plan is planning's row and the membership collaboration's, read
    // through their ports.
    const plan = await this.plans.getPlan(this.prisma, notification.weddingPlanId);
    if (!plan) return false;
    if (plan.ownerUserId === notification.userId) return true;
    if (isPlanDeletionPending(plan)) return false;
    const member = await this.permissions.getMembership(
      this.prisma,
      plan.id,
      notification.userId,
    );
    if (!member) return false;
    const context: PlanAccessContext = { plan, isOwner: false, sharedMember: member };
    switch (right) {
      case "MONEY":
        return this.permissions.canViewMoney(context);
      case "TASKS":
        return this.permissions.canManageTasks(context);
      case "PROVIDERS":
        return this.permissions.canManageProviders(context);
      default:
        return true;
    }
  }

  private messagePayload(notification: Notification) {
    const copy = pushNotificationCopy(notification.type, notification.data);
    const data: Record<string, string> = {
      notificationId: notification.id,
      type: notification.type,
    };
    // RA-BE-190: the messages of one conversation are one alert on the
    // phone (Android: one collapse key and tag; iOS: one thread); every
    // other notification is its own.
    const thread =
      notification.type === NotificationType.CHAT_MESSAGE_RECEIVED &&
      notification.entityType === "conversation" &&
      notification.entityId
        ? `aarast_chat_${notification.entityId}`
        : null;
    const alertKey = thread ?? `aarast_${notification.id}`;
    return {
      notification: copy,
      data,
      android: {
        priority: "high" as const,
        ttl: PUSH_TTL_MS,
        collapseKey: alertKey,
        notification: {
          channelId: pushAndroidChannelId(notification.type),
          icon: "ic_stat_aarast",
          color: "#4C7180",
          defaultSound: true,
          priority: "high" as const,
          visibility: "private" as const,
          tag: alertKey,
        },
      },
      ...(thread ? { apns: { payload: { aps: { threadId: thread } } } } : {}),
    };
  }
}

/** Firebase's error code (`messaging/...`), else the error's name. */
function firebaseErrorCode(error: unknown): string {
  const code = (error as { code?: unknown } | null)?.code;
  if (typeof code === "string" && code.length > 0) return code;
  return error instanceof Error ? error.name : "UnknownError";
}

function shortCode(value: string): string {
  return value.replace(/[^A-Za-z0-9_./-]/g, "").slice(0, 120) || "UnknownError";
}
