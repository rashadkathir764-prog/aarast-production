import { NotificationType, Prisma } from "@prisma/client";

const financialNotificationTypes = new Set<NotificationType>([
  NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
  NotificationType.PAYMENT_SCHEDULE_OVERDUE,
]);
const financialEntityPattern = /(money|finance|budget|cost|payment|schedule)/i;
const financialDataKeyPattern =
  /(amount|balance|budget|cost|currency|paid|payment|price|remaining|total)/i;

export interface AdminNotificationPrivacyInput {
  type: NotificationType;
  title: string;
  body: string;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
  data: Prisma.JsonValue | null;
}

export interface AdminNotificationPrivacyView {
  title: string;
  body: string;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
  data: Prisma.JsonValue | null;
  financialDetailsRedacted: boolean;
}

export function toAdminNotificationPrivacyView(
  notification: AdminNotificationPrivacyInput,
): AdminNotificationPrivacyView {
  if (!isFinancialNotification(notification)) {
    return {
      title: notification.title,
      body: notification.body,
      entityType: notification.entityType,
      entityId: notification.entityId,
      routeTarget: notification.routeTarget,
      data: notification.data,
      financialDetailsRedacted: false,
    };
  }

  return {
    title: "إشعار مالي",
    body: "تم إخفاء التفاصيل المالية لحماية خصوصية المستخدم.",
    entityType: "financial",
    entityId: null,
    routeTarget: null,
    data: null,
    financialDetailsRedacted: true,
  };
}

export function maskPhone(phone: string | null): string | null {
  if (!phone) return null;
  const digits = phone.replace(/\D/g, "");
  if (!digits) return null;
  return `••••${digits.slice(-4)}`;
}

function isFinancialNotification(
  notification: AdminNotificationPrivacyInput,
): boolean {
  return (
    financialNotificationTypes.has(notification.type) ||
    financialEntityPattern.test(notification.entityType ?? "") ||
    containsFinancialDataKey(notification.data)
  );
}

function containsFinancialDataKey(
  value: Prisma.JsonValue | null | undefined,
): boolean {
  if (!value || typeof value !== "object") return false;
  if (Array.isArray(value))
    return value.some((item) => containsFinancialDataKey(item));
  return Object.entries(value).some(
    ([key, nested]) =>
      financialDataKeyPattern.test(key) || containsFinancialDataKey(nested),
  );
}
