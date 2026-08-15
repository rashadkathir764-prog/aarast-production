import { Injectable } from "@nestjs/common";
import { Notification, NotificationType } from "@prisma/client";
import { FirebasePushClient } from "./firebase-push.client";
import {
  isPushNotificationType,
  pushNotificationCopy,
} from "./push-notification.policy";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import type { PushDeliveryPort } from "../modules/notifications/public/push-delivery.port";

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

  async dispatchNotification(notificationId: string): Promise<void> {
    if (!this.firebase.enabled) return;

    const notification = await this.prisma.notification.findUnique({
      where: { id: notificationId },
      include: {
        user: {
          select: {
            notificationPreference: {
              select: { pushEnabled: true },
            },
            pushInstallations: {
              where: { enabled: true },
              orderBy: { createdAt: "asc" },
              select: { id: true, fid: true, updatedAt: true },
            },
          },
        },
      },
    });
    if (
      !notification ||
      !isPushNotificationType(notification.type) ||
      notification.user.notificationPreference?.pushEnabled !== true
    ) {
      return;
    }

    const fids = notification.user.pushInstallations.map((item) => item.fid);
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
          if (item.success) return;
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
      const failedInstallations = notification.user.pushInstallations.filter(
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
      const error = new Error("PushDeliveryRetryRequired");
      error.name = "PushDeliveryRetryRequired";
      throw error;
    }
  }

  private messagePayload(notification: Notification) {
    const copy = pushNotificationCopy(notification.type);
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
