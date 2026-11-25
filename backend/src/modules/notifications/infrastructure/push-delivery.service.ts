import { Injectable } from "@nestjs/common";
import { Notification, NotificationType } from "@prisma/client";
import { FirebasePushClient } from "../../../push/firebase-push.client";
import {
  isPushNotificationType,
  pushNotificationCopy,
} from "../../../push/push-notification.policy";
import { runSerializableTransaction } from "../../../platform/database/serializable-transaction";
import { PrismaService } from "../../../platform/database/prisma.service";
import type { PushDeliveryPort } from "../public/push-delivery.port";

const MAX_FCM_TARGETS = 500;
const PUSH_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const PERMANENT_FCM_ERRORS = new Set([
  "messaging/installation-id-not-registered",
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

@Injectable()
export class PushDeliveryService implements PushDeliveryPort {
  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebasePushClient,
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

  async dispatchNotification(
    notificationId: string,
    alreadyDeliveredInstallationIds: readonly string[] = [],
  ): Promise<void> {
    if (!this.firebase.enabled) return;

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
    // RA-BE-185: a push held through quiet hours, or retried, whose notice
    // was read meanwhile tells the person nothing new.
    if (notification.readAt) return;
    const preference = await this.prisma.notificationPreference.findUnique({
      where: { userId: notification.userId },
      select: { pushEnabled: true },
    });
    if (preference?.pushEnabled !== true) return;

    const installations = await this.prisma.pushInstallation.findMany({
      where: { userId: notification.userId, enabled: true },
      orderBy: { createdAt: "asc" },
      select: { id: true, fid: true, updatedAt: true },
    });
    // RA-BE-190: a retry goes to the phones the earlier try did not reach.
    const reached = new Set(alreadyDeliveredInstallationIds);
    const targets = installations.filter((item) => !reached.has(item.id));
    const fids = targets.map((item) => item.fid);
    if (fids.length === 0) return;

    const permanentFailures = new Set<string>();
    let transientFailure = false;
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
          } else {
            transientFailure = true;
          }
        });
      } catch {
        transientFailure = true;
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
    if (transientFailure) {
      const error = new Error("PushDeliveryRetryRequired") as Error & {
        deliveredInstallationIds: string[];
      };
      error.name = "PushDeliveryRetryRequired";
      // Only those still registered: a phone that went away is not listed.
      error.deliveredInstallationIds = installations
        .filter((item) => reached.has(item.id))
        .map((item) => item.id);
      throw error;
    }
  }

  private messagePayload(notification: Notification) {
    const copy = pushNotificationCopy(notification.type, notification.data);
    const data: Record<string, string> = {
      notificationId: notification.id,
      type: notification.type,
    };
    return {
      notification: copy,
      data,
      android: {
        priority: "high" as const,
        ttl: PUSH_TTL_MS,
        collapseKey: `aarast_${notification.id}`,
        notification: {
          channelId: "aarast_updates",
          icon: "ic_stat_aarast",
          color: "#4C7180",
          defaultSound: true,
          priority: "high" as const,
          visibility: "private" as const,
          tag: `aarast_${notification.id}`,
        },
      },
    };
  }
}
