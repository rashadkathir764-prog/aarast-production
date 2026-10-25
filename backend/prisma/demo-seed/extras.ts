// Notifications for the demo accounts, the admin team's audit trail, and the
// removal of the ad-hoc rows an earlier hand-written SQL session left behind.
import {
  AdminAuditPhase,
  AdminRole,
  NotificationPriority,
  PrismaClient,
} from '@prisma/client';
import type { CreateNotificationInput } from '../../src/modules/notifications/public/notifications.port';
import { quoteOfferReceivedNotification, quoteSubmittedProviderNotification } from '../../src/marketplace/quote-notifications';
import { bookingCustomerNotification } from '../../src/marketplace/booking-notifications';
import { reviewReceivedProviderNotification, reviewRepliedNotification } from '../../src/marketplace/review-notifications';
import { chatMessageNotification } from '../../src/conversations/chat-notifications';
import { type AddressForm, addressFormOf, textFor } from '../../src/shared-kernel/voice/address-form';
import { DEMO_ACCOUNTS, type DemoAccountKey, userId } from './accounts';
import { offerId, PROVIDERS, providerId, requestId, STUDIO_ID } from './market-data';
import { planId } from './plan';
import { day, demoId, demoUuid, hoursAgo } from './support';

/**
 * B-19/B-38: the demo's notices are the server's own, written by the same
 * builders the events use (each one's words, route and data), so a walk
 * reads exactly what a real request, booking, message or review writes. The
 * reminders (payments, tasks, the countdown) are not seeded: the hourly scan
 * writes them from the plans' dates.
 */
interface DemoNotice {
  input: CreateNotificationInput;
  hours: number;
  read?: boolean;
}

const WEDDING_DAY = day('2027-01-21');

function providerSpec(key: string) {
  const spec = PROVIDERS.find((candidate) => candidate.key === key);
  if (!spec) throw new Error(`Unknown provider ${key}`);
  return spec;
}

function providerIdOf(key: string): string {
  return providerId(providerSpec(key));
}

function providerNameOf(key: string): string {
  return providerSpec(key).businessName;
}

function nameOf(key: DemoAccountKey): string {
  const account = DEMO_ACCOUNTS.find((candidate) => candidate.key === key);
  if (!account) throw new Error(`Unknown account ${key}`);
  return account.name;
}

function formOf(key: DemoAccountKey): AddressForm {
  const account = DEMO_ACCOUNTS.find((candidate) => candidate.key === key);
  return addressFormOf({ accountPersona: account?.persona ?? null });
}

function demoNotices(): DemoNotice[] {
  return [
    {
      input: quoteOfferReceivedNotification({
        requesterId: userId('groom'),
        weddingPlanId: planId('groom'),
        quoteRequestId: requestId('lens'),
        quoteOfferId: offerId('lens'),
        providerId: providerIdOf('lens'),
        providerName: providerNameOf('lens'),
      }),
      hours: 1,
    },
    {
      input: bookingCustomerNotification('CONFIRMED', {
        bookingId: demoUuid('booking:hall'),
        quoteRequestId: requestId('hall'),
        providerId: providerIdOf('hall'),
        eventDate: WEDDING_DAY,
        revision: 0,
        customerUserId: userId('groom'),
        weddingPlanId: planId('groom'),
        providerName: providerNameOf('hall'),
      }),
      hours: 80,
      read: true,
    },
    {
      input: bookingCustomerNotification('CONFIRMED', {
        bookingId: demoUuid('booking:yasmine'),
        quoteRequestId: requestId('yasmine'),
        providerId: providerIdOf('yasmine'),
        eventDate: WEDDING_DAY,
        revision: 0,
        customerUserId: userId('bride'),
        weddingPlanId: planId('bride'),
        providerName: providerNameOf('yasmine'),
      }),
      hours: 80,
      read: true,
    },
    {
      input: quoteSubmittedProviderNotification({
        providerUserId: userId('providerStudio'),
        quoteId: requestId('studioBride'),
        providerId: STUDIO_ID,
        customerName: nameOf('bride'),
      }),
      hours: 10,
    },
    {
      input: chatMessageNotification({
        recipientId: userId('providerStudio'),
        weddingPlanId: planId('groom'),
        conversationId: demoId('conv', 'studio'),
        providerId: STUDIO_ID,
        recipientIsProvider: true,
        messageId: demoId('msg', 'studio-3'),
      }),
      hours: 118,
    },
    {
      input: reviewReceivedProviderNotification({
        providerUserId: userId('providerStudio'),
        providerId: STUDIO_ID,
        reviewId: demoUuid('review:studio:khaled'),
        rating: 4,
        reviewerName: nameOf('customerKhaled'),
      }),
      hours: 200,
      read: true,
    },
    {
      input: reviewRepliedNotification({
        reviewerId: userId('customerKhaled'),
        providerId: STUDIO_ID,
        providerName: providerNameOf('studio'),
        reviewId: demoUuid('review:studio:khaled'),
      }),
      hours: 190,
    },
  ];
}

export async function seedNotifications(prisma: PrismaClient): Promise<void> {
  // The hand-written notices of earlier seeds (some of a kind the server
  // never writes) go; the demo keeps only real ones.
  await prisma.notification.deleteMany({ where: { dedupeKey: { startsWith: 'demo:' } } });
  for (const notice of demoNotices()) {
    const { input } = notice;
    const key = DEMO_ACCOUNTS.find((account) => userId(account.key) === input.userId)?.key;
    if (!key) throw new Error(`Unknown recipient ${input.userId}`);
    const form = formOf(key);
    const data = {
      userId: input.userId,
      weddingPlanId: input.weddingPlanId ?? null,
      type: input.type,
      priority: input.priority ?? NotificationPriority.NORMAL,
      title: textFor(form, input.title),
      body: textFor(form, input.body),
      entityType: input.entityType ?? null,
      entityId: input.entityId ?? null,
      routeTarget: input.routeTarget ?? null,
      data: input.data,
      readAt: notice.read ? hoursAgo(notice.hours - 1) : null,
      archivedAt: null,
    };
    const dedupeKey = input.dedupeKey!;
    await prisma.notification.upsert({
      where: { dedupeKey },
      create: { id: demoId('notif', dedupeKey), dedupeKey, createdAt: hoursAgo(notice.hours), ...data },
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
