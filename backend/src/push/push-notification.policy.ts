import { NotificationType } from "@prisma/client";

const PUSH_NOTIFICATION_TYPES = new Set<NotificationType>([
  NotificationType.TASK_ASSIGNED,
  NotificationType.TASK_DUE_SOON,
  NotificationType.TASK_OVERDUE,
  NotificationType.CHAT_MESSAGE_RECEIVED,
]);

export function isPushNotificationType(type: NotificationType): boolean {
  return PUSH_NOTIFICATION_TYPES.has(type);
}

export function pushNotificationCopy(type: NotificationType): {
  title: string;
  body: string;
} {
  switch (type) {
    case NotificationType.TASK_ASSIGNED:
      return {
        title: "مهمة جديدة",
        body: "تم إسناد مهمة جديدة إليك. افتح أعّرست لعرض التفاصيل.",
      };
    case NotificationType.TASK_DUE_SOON:
    case NotificationType.TASK_OVERDUE:
      return {
        title: "تذكير بمهمة",
        body: "لديك تحديث جديد على مهام الخطة. افتح أعّرست للمتابعة.",
      };
    case NotificationType.CHAT_MESSAGE_RECEIVED:
      return {
        title: "رسالة جديدة",
        body: "لديك رسالة جديدة. افتح أعّرست لقراءتها.",
      };
    default:
      throw new Error("UnsupportedPushNotificationType");
  }
}
