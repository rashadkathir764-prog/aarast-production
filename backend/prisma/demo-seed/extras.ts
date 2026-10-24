// Notifications for the demo accounts, the admin team's audit trail, and the
// removal of the ad-hoc rows an earlier hand-written SQL session left behind.
import {
  AdminAuditPhase,
  AdminRole,
  NotificationPriority,
  NotificationType,
  PrismaClient,
} from '@prisma/client';
import { type DemoAccountKey, userId } from './accounts';
import { offerId, requestId } from './market-data';
import { planId } from './plan';
import { demoId, hoursAgo } from './support';

interface NotificationSpec {
  key: string;
  to: DemoAccountKey;
  plan?: 'groom' | 'bride';
  type: NotificationType;
  priority?: NotificationPriority;
  title: string;
  body: string;
  route?: string;
  request?: string;
  hours: number;
  read?: boolean;
}

const NOTIFICATIONS: readonly NotificationSpec[] = [
  { key: 'g-offer', to: 'groom', plan: 'groom', type: NotificationType.QUOTE_OFFER_RECEIVED, title: 'وصلك عرض تصوير ثاني', body: 'عدسة سبأ · 480 ألف', request: 'lens', hours: 1 },
  { key: 'g-saleh', to: 'groom', plan: 'groom', type: NotificationType.PLAN_UPDATED, title: 'صالح خلّص مهمتين', body: 'استلم البدلة · رتّب الغداء', hours: 3 },
  { key: 'g-payment', to: 'groom', plan: 'groom', type: NotificationType.PAYMENT_SCHEDULE_DUE_SOON, priority: NotificationPriority.HIGH, title: 'دفعة القاعة بعد 5 أيام', body: '500,000 ر.ي · قاعة سبأ', hours: 6 },
  { key: 'g-booking', to: 'groom', plan: 'groom', type: NotificationType.BOOKING_UPDATED, title: 'قاعة سبأ أكدت حجز 21 يناير', body: 'محجوز · بدون أي دفع داخل التطبيق', hours: 80, read: true },
  { key: 'g-friday', to: 'groom', plan: 'groom', type: NotificationType.GENERAL, title: 'جمعة مباركة', body: 'هذا الأسبوع: دفعة وحدة، و3 مهام، و5 ضيوف ردّوا', hours: 120, read: true },
  { key: 'b-payment', to: 'bride', plan: 'bride', type: NotificationType.PAYMENT_SCHEDULE_DUE_SOON, priority: NotificationPriority.HIGH, title: 'دفعة الصالة بعد 5 أيام', body: '500,000 ر.ي · صالة الياسمين', hours: 6 },
  { key: 'b-booking', to: 'bride', plan: 'bride', type: NotificationType.BOOKING_UPDATED, title: 'صالة الياسمين أكدت حجز 21 يناير', body: 'محجوز · بدون أي دفع داخل التطبيق', hours: 80, read: true },
  { key: 'p-new', to: 'providerStudio', type: NotificationType.QUOTE_REQUEST_SUBMITTED, priority: NotificationPriority.HIGH, title: 'طلب جديد من سلمى', body: 'حفلة نساء · 21 يناير', request: 'studioBride', hours: 10 },
  { key: 'p-chat', to: 'providerStudio', type: NotificationType.CHAT_MESSAGE_RECEIVED, title: 'رسالة جديدة', body: 'ممكن تضيفون تصوير جوي؟', request: 'studio', hours: 118 },
  { key: 'p-review', to: 'providerStudio', type: NotificationType.GENERAL, title: 'تقييم جديد', body: '4 نجوم من خالد', hours: 200, read: true },
  { key: 'h-chat', to: 'providerHall', type: NotificationType.QUOTE_REQUEST_SUBMITTED, title: 'حجز مؤكد', body: 'عرس محمد · 21 يناير', request: 'hall', hours: 300, read: true },
];

export async function seedNotifications(prisma: PrismaClient): Promise<void> {
  for (const spec of NOTIFICATIONS) {
    const requestKey = spec.request;
    const data = {
      userId: userId(spec.to),
      weddingPlanId: spec.plan ? planId(spec.plan) : null,
      type: spec.type,
      priority: spec.priority ?? NotificationPriority.NORMAL,
      title: spec.title,
      body: spec.body,
      entityType: requestKey ? 'quote_request' : null,
      entityId: requestKey ? requestId(requestKey) : null,
      routeTarget: requestKey ? `/providers?quoteId=${requestId(requestKey)}` : null,
      data: requestKey
        ? { quoteRequestId: requestId(requestKey), quoteOfferId: offerId(requestKey) }
        : undefined,
      readAt: spec.read ? hoursAgo(spec.hours - 1) : null,
      archivedAt: null,
    };
    const id = demoId('notif', spec.key);
    const createdAt = hoursAgo(spec.hours);
    await prisma.notification.upsert({
      where: { dedupeKey: `demo:${spec.key}` },
      create: { id, dedupeKey: `demo:${spec.key}`, createdAt, ...data },
      update: data,
    });
  }
}

const AUDIT: ReadonlyArray<{
  key: string;
  actor: DemoAccountKey;
  role: AdminRole;
  action: string;
  route: string;
  phase: AdminAuditPhase;
  status: number;
  hours: number;
}> = [
  { key: 'a1', actor: 'adminRashad', role: AdminRole.SUPER_ADMIN, action: 'providers.request-changes', route: '/api/v1/admin/providers/:id/review', phase: AdminAuditPhase.SUCCEEDED, status: 200, hours: 3 },
  { key: 'a2', actor: 'adminNadia', role: AdminRole.OPERATIONS, action: 'providers.verify', route: '/api/v1/admin/providers/:id/verify', phase: AdminAuditPhase.SUCCEEDED, status: 200, hours: 6 },
  { key: 'a3', actor: 'adminNadia', role: AdminRole.OPERATIONS, action: 'providers.suspend', route: '/api/v1/admin/providers/:id/status', phase: AdminAuditPhase.SUCCEEDED, status: 200, hours: 26 },
  { key: 'a4', actor: 'adminSara', role: AdminRole.MODERATOR, action: 'providers.suspend', route: '/api/v1/admin/providers/:id/status', phase: AdminAuditPhase.FAILED, status: 403, hours: 27 },
];

export async function seedAdminAudit(prisma: PrismaClient): Promise<void> {
  // The audit log is append-only (a database trigger refuses updates), so a
  // row that is already there stays as it is.
  await prisma.adminAuditLog.createMany({
    skipDuplicates: true,
    data: AUDIT.map((entry) => ({
      id: demoId('audit', entry.key),
      eventId: `demo-audit-${entry.key}`,
      actorUserId: userId(entry.actor),
      actorAdminRole: entry.role,
      action: entry.action,
      method: 'POST',
      route: entry.route,
      targetId: null,
      phase: entry.phase,
      statusCode: entry.status,
      createdAt: hoursAgo(entry.hours),
    })),
  });
}

/**
 * An earlier session filled the local database with hand-written SQL rows whose
 * ids start with `seed_` (extra participants, plans, a task and 124 guests of
 * one dev account). They overlap what this seed owns, so they go; the demo's
 * own rows use the `demo_` prefix.
 */
export async function removeAdHocRows(prisma: PrismaClient): Promise<Record<string, number>> {
  const like = { startsWith: 'seed_' };
  const removed: Record<string, number> = {};
  removed.sharedMembers = (await prisma.sharedMember.deleteMany({ where: { id: like } })).count;
  removed.tasks = (await prisma.weddingTask.deleteMany({ where: { id: like } })).count;
  removed.guests = (await prisma.guest.deleteMany({ where: { id: like } })).count;
  removed.plans = (await prisma.weddingPlan.deleteMany({ where: { id: like } })).count;
  removed.users = (await prisma.user.deleteMany({ where: { id: like } })).count;
  return removed;
}
