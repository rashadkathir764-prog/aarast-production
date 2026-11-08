import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { NotificationType, Prisma, ProviderStatus, ReviewStatus } from '@prisma/client';
import type { CreateNotificationInput } from '../src/modules/notifications/public/notifications.port';
import {
  offerAcceptedProviderNotification,
  offerAcceptedRequesterNotification,
  providerRejectedRequestNotification,
  quoteOfferReceivedNotification,
  quoteOfferRevisedNotification,
  quoteOfferWithdrawnNotification,
  quoteRequestExpiredRequesterNotification,
  quoteRequestExpiringProviderNotification,
  quoteSubmittedProviderNotification,
  quoteSubmittedRequesterNotification,
  requesterRejectedOfferNotification,
} from '../src/marketplace/quote-notifications';
import {
  bookingCustomerNotification,
  bookingProviderNotification,
  bookingReminderNotifications,
  customerClosedProviderNotification,
} from '../src/marketplace/booking-notifications';
import {
  planClosedForDeletionNotice,
  planErasedNotice,
  planReopenedNotice,
} from '../src/modules/identity/internal/profile/account-deletion-notices';
import {
  memberRemovedNotice,
  memberRightsChangedNotice,
} from '../src/modules/collaboration/internal/sharing-notices';
import {
  reviewReceivedProviderNotification,
  reviewRepliedNotification,
} from '../src/marketplace/review-notifications';
import { chatMessageNotification } from '../src/conversations/chat-notifications';
import {
  addressDueNotice,
  budgetCategoryExceededRow,
  type DueNotice,
  loanRepaymentRow,
  paymentDueNotice,
  taskDueNotice,
  weddingCountdownRow,
} from '../src/notifications/plan-reminders';
import { switchProviderStatusNotification } from '../src/admin/provider-status-notification';
import { noticeMessage } from '../src/marketplace/featured-period-notices.service';
import {
  NOTIFICATION_ROUTES,
  noticeRoutes,
} from '../src/shared-kernel/routes/notification-routes';
import {
  type AddressForm,
  gendered,
  textFor,
} from '../src/shared-kernel/voice/address-form';
import {
  dayMonthWords,
  daysBetween,
  weekdayDayMonthWords,
  whenWords,
} from '../src/shared-kernel/voice/day-words';
import { publicReviewReply, ownerReviewReply, starsWords } from '../src/modules/marketplace/public/review-reply';
import { startOfRiyadhDay } from '../src/shared-kernel/time/business-day';

// B4: every notice the server writes opens a phone route that exists (B-19)
// and reads as the app speaks (B-38): no raw amount, no numeric or ISO
// date, no English, the app's words, and each reader in their own form (D55).

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(backendRoot, '..');
const today = startOfRiyadhDay(new Date('2026-10-25T09:00:00.000Z'));
const FORMS: AddressForm[] = ['MASCULINE', 'FEMININE'];

const d = (value: string | number) => new Prisma.Decimal(value);

/** Every notice the builders write, in every variant. */
function allBuiltNotices(): Array<{ label: string; notice: CreateNotificationInput | DueNotice }> {
  const ids = {
    requester: 'user-1',
    provider: 'user-2',
    plan: 'plan-1',
    quote: 'quote-1',
    offer: 'offer-1',
    providerId: 'provider-1',
  };
  const quote = {
    requesterId: ids.requester,
    weddingPlanId: ids.plan,
    quoteRequestId: ids.quote,
    quoteOfferId: ids.offer,
    providerId: ids.providerId,
    providerName: 'استوديو ضوء صنعاء',
  };
  const booking = {
    bookingId: 'booking-1',
    quoteRequestId: ids.quote,
    providerId: ids.providerId,
    eventDate: new Date('2027-01-21T00:00:00.000Z'),
    revision: 1,
  };
  const schedule = {
    id: 'schedule-1',
    weddingCostId: 'cost-1',
    amount: d('500000'),
    dueDate: new Date('2026-10-30T00:00:00.000Z'),
    weddingCost: {
      weddingPlanId: ids.plan,
      title: 'قاعة سبأ',
      partyName: null,
      providerId: ids.providerId,
      privateToUserId: null,
    },
  } as unknown as Parameters<typeof paymentDueNotice>[1];
  const list: Array<{ label: string; notice: CreateNotificationInput | DueNotice }> = [
    { label: 'submitted/requester', notice: quoteSubmittedRequesterNotification({ ...quote, quoteId: ids.quote }) },
    { label: 'submitted/no-plan', notice: quoteSubmittedRequesterNotification({ ...quote, weddingPlanId: null, quoteId: ids.quote }) },
    { label: 'submitted/provider', notice: quoteSubmittedProviderNotification({ providerUserId: ids.provider, quoteId: ids.quote, providerId: ids.providerId, customerName: 'سلمى السقاف' }) },
    { label: 'accepted/requester', notice: offerAcceptedRequesterNotification({ ...quote, weddingPlanId: ids.plan }) },
    { label: 'accepted/provider', notice: offerAcceptedProviderNotification({ providerUserId: ids.provider, quoteRequestId: ids.quote, quoteOfferId: ids.offer, providerId: ids.providerId, customerName: 'محمد الحمدي' }) },
    { label: 'rejected/by-provider', notice: providerRejectedRequestNotification(quote) },
    { label: 'rejected/offer', notice: requesterRejectedOfferNotification({ providerUserId: ids.provider, quoteRequestId: ids.quote, quoteOfferId: ids.offer, providerId: ids.providerId }) },
    { label: 'offer/received', notice: quoteOfferReceivedNotification(quote) },
    { label: 'offer/revised', notice: quoteOfferRevisedNotification({ ...quote, versionNo: 2 }) },
    { label: 'offer/withdrawn', notice: quoteOfferWithdrawnNotification(quote) },
    { label: 'request/expiring', notice: quoteRequestExpiringProviderNotification({ providerUserId: ids.provider, quoteRequestId: ids.quote, providerId: ids.providerId, customerName: 'محمد', expiresAt: new Date('2026-10-26T09:00:00.000Z') }) },
    { label: 'request/expired', notice: quoteRequestExpiredRequesterNotification({ ...quote, answerDays: 7 }) },
    { label: 'booking/requested', notice: bookingProviderNotification('REQUESTED', { ...booking, providerUserId: ids.provider, customerName: 'محمد الحمدي' }) },
    { label: 'booking/cancelled-by-customer', notice: bookingProviderNotification('CANCELLED', { ...booking, providerUserId: ids.provider, customerName: null }) },
    ...(['CONFIRMED', 'DECLINED', 'CANCELLED'] as const).map((event) => ({
      label: `booking/${event}`,
      notice: bookingCustomerNotification(event, { ...booking, customerUserId: ids.requester, weddingPlanId: ids.plan, providerName: quote.providerName }),
    })),
    ...[7, 2, 1].flatMap((days) =>
      bookingReminderNotifications(
        {
          ...booking,
          eventDate: new Date(today.getTime() + (days * 24 + 3) * 60 * 60 * 1000),
          customerUserId: ids.requester,
          weddingPlanId: ids.plan,
          customerName: 'محمد الحمدي',
          providerUserId: ids.provider,
          providerName: quote.providerName,
        },
        today,
      ).map((notice, index) => ({ label: `booking/reminder-${days}-${index}`, notice })),
    ),
    { label: 'review/received', notice: reviewReceivedProviderNotification({ providerUserId: ids.provider, providerId: ids.providerId, reviewId: 'review-1', rating: 4, reviewerName: 'خالد القاضي' }) },
    { label: 'review/replied', notice: reviewRepliedNotification({ reviewerId: ids.requester, providerId: ids.providerId, providerName: quote.providerName, reviewId: 'review-1' }) },
    { label: 'chat/customer', notice: chatMessageNotification({ recipientId: ids.requester, weddingPlanId: ids.plan, conversationId: 'conversation-1', providerId: ids.providerId, recipientIsProvider: false, messageId: 'message-1' }) },
    { label: 'chat/provider', notice: chatMessageNotification({ recipientId: ids.provider, weddingPlanId: ids.plan, conversationId: 'conversation-1', providerId: ids.providerId, recipientIsProvider: true, messageId: 'message-1' }) },
    { label: 'task/soon', notice: taskDueNotice(ids.requester, { id: 'task-1', weddingPlanId: ids.plan, title: 'حجز القاعة', dueDate: new Date('2026-10-28T00:00:00.000Z') }, today) },
    { label: 'task/overdue', notice: taskDueNotice(ids.requester, { id: 'task-1', weddingPlanId: ids.plan, title: 'حجز القاعة', dueDate: new Date('2026-10-20T00:00:00.000Z') }, today) },
    { label: 'payment/owner', notice: paymentDueNotice(ids.requester, schedule, { id: ids.plan, currency: 'YER' }, today, { partyName: 'قاعة سبأ' }) },
    { label: 'payment/member', notice: paymentDueNotice('user-3', schedule, { id: ids.plan, currency: 'YER' }, today, null) },
    { label: 'payment/overdue', notice: paymentDueNotice(ids.requester, { ...schedule, dueDate: new Date('2026-10-20T00:00:00.000Z') } as typeof schedule, { id: ids.plan, currency: 'YER' }, today, { partyName: null }) },
    { label: 'budget/exceeded', notice: budgetCategoryExceededRow(ids.requester, { id: 'category-1', weddingPlanId: ids.plan, name: 'القاعة', allocatedAmount: d('2000000'), committedAmount: d('2500000'), expectedAmount: d('2500000') }, 'YER') },
    { label: 'loan/soon', notice: loanRepaymentRow(ids.requester, { id: 'repayment-1', weddingPlanId: ids.plan, sourceName: 'العم أحمد', amount: d('150000'), dueDate: new Date('2026-10-29T00:00:00.000Z') }, today, 'YER') },
    { label: 'loan/overdue', notice: loanRepaymentRow(ids.requester, { id: 'repayment-1', weddingPlanId: ids.plan, sourceName: 'العم أحمد', amount: d('150000'), dueDate: new Date('2026-10-01T00:00:00.000Z') }, today, 'YER') },
    ...[30, 7, 1, 0].map((days) => ({
      label: `countdown/${days}`,
      notice: weddingCountdownRow(ids.requester, { id: ids.plan, weddingDate: new Date(today.getTime() + days * 24 * 60 * 60 * 1000) }, today)!,
    })),
    // D63: the owner's deletion, told to the members and the providers.
    ...(['GROOM', 'BRIDE'] as const).flatMap((persona) => {
      const owner = { name: persona === 'BRIDE' ? 'سلمى أحمد' : 'محمد علي', persona };
      return [
        { label: `deletion/${persona}/closed`, notice: planClosedForDeletionNotice({ memberUserId: 'user-3', weddingPlanId: ids.plan, owner, scheduledFor: new Date('2026-11-27T09:00:00.000Z'), requestedAt: new Date('2026-10-28T09:00:00.000Z') }) },
        { label: `deletion/${persona}/reopened`, notice: planReopenedNotice({ memberUserId: 'user-3', weddingPlanId: ids.plan, owner, requestedAt: new Date('2026-10-28T09:00:00.000Z') }) },
        { label: `deletion/${persona}/erased`, notice: planErasedNotice({ memberUserId: 'user-3', weddingPlanId: ids.plan, owner, erasedAt: new Date('2026-11-27T09:00:00.000Z') }) },
      ];
    }),
    // J2-07: a member re-scoped or taken out of the plan, by a groom or a bride.
    ...(['GROOM', 'BRIDE'] as const).flatMap((persona) => {
      const actor = { name: persona === 'BRIDE' ? 'سلمى أحمد' : 'محمد علي', persona };
      const member = { memberUserId: 'user-3', sharedMemberId: 'member-3', weddingPlanId: ids.plan, planTitle: 'عرس سلمى', actor };
      return [
        { label: `sharing/${persona}/rights`, notice: memberRightsChangedNotice({ ...member, authorityVersion: 2 }) },
        { label: `sharing/${persona}/removed`, notice: memberRemovedNotice(member) },
      ];
    }),
    ...[new Date('2027-01-21T00:00:00.000Z'), null].map((confirmedDay) => ({
      label: `deletion/provider/${confirmedDay ? 'booked' : 'request'}`,
      notice: customerClosedProviderNotification({ quoteRequestId: ids.quote, providerUserId: ids.provider, customerName: 'محمد علي', confirmedDay, at: new Date('2026-11-27T09:00:00.000Z') }),
    })),
  ];
  return list;
}

/** Every provider-account notice: its type, words, and the route the writer gives it. */
function providerAccountNotices(): Array<{ label: string; type: NotificationType; title: string; body: string; route: string }> {
  const statuses = Object.values(ProviderStatus).flatMap((status) =>
    [null, 'صلّح وصف الملف.'].map((note) => {
      const copy = switchProviderStatusNotification('استوديو ضوء صنعاء', status, note);
      return { label: `status/${status}/${note ? 'note' : 'plain'}`, type: copy.type, title: copy.title, body: copy.body, route: noticeRoutes.providerPortal() };
    }),
  );
  const featured = (['started', 'ending', 'ended'] as const).flatMap((notice) =>
    [true, false].flatMap((shown) => {
      const message = noticeMessage(notice, '2026-12-31', shown);
      return message
        ? [{ label: `featured/${notice}/${shown}`, type: NotificationType.LISTING_PLAN_CHANGED, title: message.title, body: message.body, route: noticeRoutes.providerProfile() }]
        : [];
    }),
  );
  return [...statuses, ...featured];
}

/** The words a notice must never carry (B-38). */
function assertCleanWords(label: string, text: string): void {
  assert.doesNotMatch(text, /[A-Za-z]/u, `${label}: English in «${text}»`);
  assert.doesNotMatch(text, /\d{4,}/u, `${label}: a raw number in «${text}»`);
  assert.doesNotMatch(text, /\d{1,2}\/\d{1,2}\/\d{2,4}/u, `${label}: a numeric date in «${text}»`);
  assert.doesNotMatch(text, /\d{4}-\d{2}-\d{2}/u, `${label}: an ISO date in «${text}»`);
  assert.doesNotMatch(text, /ر\.ي|ريال|دولار/u, `${label}: an amount in the words «${text}»`);
  for (const word of ['مورد', 'بوابة', 'المزوّد', 'مزوّد', 'لديك', 'تم إ', 'تم ت', 'تم ق', 'تم ر', 'غدًا', 'قريباً']) {
    assert.equal(text.includes(word), false, `${label}: «${word}» in «${text}»`);
  }
}

/** A route shape (`:name` an id, `?key=:name` a query) as a pattern. */
function routePattern(shape: string): RegExp {
  const [pathPart, query] = shape.split('?');
  const escapedPath = pathPart!
    .split('/')
    .map((segment) => (segment.startsWith(':') ? '[A-Za-z0-9_-]+' : segment.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
    .join('/');
  const escapedQuery = query
    ? `\\?${query.split('&').map((pair) => `${pair.split('=')[0]}=[A-Za-z0-9_-]+`).join('&')}`
    : '';
  return new RegExp(`^${escapedPath}${escapedQuery}$`, 'u');
}

function routeTypeOf(notice: { type: NotificationType; routeTarget?: string | null }, label: string) {
  const shapes: readonly string[] = NOTIFICATION_ROUTES[notice.type];
  assert.ok(notice.routeTarget, `${label}: no route`);
  assert.ok(
    shapes.some((shape) => routePattern(shape).test(notice.routeTarget!)),
    `${label}: ${notice.type} route ${notice.routeTarget} is not one of ${shapes.join(', ')}`,
  );
}

test('B-19: every notification type has a route table entry, and a type with none is written nowhere', () => {
  const enumValues = Object.values(NotificationType).sort();
  assert.deepEqual(Object.keys(NOTIFICATION_ROUTES).sort(), enumValues);
  const unrouted = enumValues.filter((type) => NOTIFICATION_ROUTES[type].length === 0);
  // D63: PLAN_UPDATED tells a plan's members its owner asked to delete his
  // account, took it back, or was erased. J2-07: SHARING_UPDATED tells a
  // member their rights changed or they were taken out of the plan.
  assert.deepEqual(unrouted, ['GENERAL', 'SYNC_REQUIRED']);
  const sources = sourceFiles(path.join(backendRoot, 'src'));
  for (const type of unrouted) {
    const writers = sources.filter((file) =>
      new RegExp(`NotificationType\\.${type}\\b`, 'u').test(readFileSync(file, 'utf8')),
    );
    assert.deepEqual(writers.map((file) => path.relative(backendRoot, file)), [], `${type} is written`);
  }
});

test('B-19: every notice the builders write carries a route of its type', () => {
  for (const { label, notice } of allBuiltNotices()) {
    routeTypeOf(notice, label);
  }
  for (const notice of providerAccountNotices()) {
    routeTypeOf({ type: notice.type, routeTarget: notice.route }, notice.label);
  }
});

test('B-19: no route is written anywhere but the route table', () => {
  const offenders: string[] = [];
  let writers = 0;
  for (const file of sourceFiles(path.join(backendRoot, 'src'))) {
    if (file.endsWith(path.join('routes', 'notification-routes.ts'))) continue;
    const source = readFileSync(file, 'utf8');
    // The files that write a notice: a builder, a reminder or a direct write.
    if (!/createNotificationInTransaction\(|CreateNotificationInput|DueNotice\b/u.test(source)) continue;
    writers += 1;
    // A write sets the route on its own line; `{ routeTarget: … }` is a
    // read filter (the legacy provider visibility rule), not a route.
    for (const match of source.matchAll(/(?<!\{\s?)routeTarget:\s*(?:['"`]|PROVIDER_PORTAL_ROUTE)/gu)) {
      offenders.push(`${path.relative(backendRoot, file)}@${match.index}`);
    }
  }
  assert.ok(writers >= 15, `only ${writers} notice writers found`);
  assert.deepEqual(offenders, []);
});

test('B-19: every route shape is a route the phone registers, with the query its screen reads', () => {
  const routerDir = path.join(repoRoot, 'mobile', 'lib', 'core', 'routing');
  const files = readdirSync(routerDir)
    .filter((name) => name.startsWith('app_router') && name.endsWith('.dart'))
    .map((name) => readFileSync(path.join(routerDir, name), 'utf8'));
  const constants = new Map<string, string>();
  for (const source of files) {
    for (const match of source.matchAll(/static const (\w+) = '([^']+)'/gu)) {
      constants.set(match[1]!, match[2]!);
    }
  }
  const routes: Array<{ path: string; block: string }> = [];
  for (const source of files) {
    for (const match of source.matchAll(/path:\s*(?:'([^']+)'|AppRouter\.(\w+))/gu)) {
      const value = match[1] ?? constants.get(match[2]!);
      if (!value) continue;
      routes.push({ path: value, block: source.slice(match.index!, match.index! + 900) });
    }
  }
  const normalise = (value: string) =>
    value.split('/').map((segment) => (segment.startsWith(':') ? ':' : segment)).join('/');
  for (const [type, shapes] of Object.entries(NOTIFICATION_ROUTES)) {
    for (const shape of shapes as readonly string[]) {
      const [pathPart, query] = shape.split('?');
      const route = routes.find((entry) => normalise(entry.path) === normalise(pathPart!));
      assert.ok(route, `${type}: ${pathPart} is not a phone route`);
      for (const pair of query ? query.split('&') : []) {
        const key = pair.split('=')[0]!;
        assert.ok(
          route.block.includes(`queryParameters['${key}']`),
          `${type}: the phone route ${pathPart} does not read «${key}»`,
        );
      }
    }
  }
});

test('B-38: every notice reads in the app words, for both forms, with no amount, number or date in figures', () => {
  for (const { label, notice } of allBuiltNotices()) {
    for (const form of FORMS) {
      assertCleanWords(`${label}/${form}/title`, textFor(form, notice.title));
      assertCleanWords(`${label}/${form}/body`, textFor(form, notice.body));
    }
  }
  for (const notice of providerAccountNotices()) {
    assertCleanWords(`${notice.label}/title`, notice.title);
    assertCleanWords(`${notice.label}/body`, notice.body.replace('ملاحظة الفريق: صلّح وصف الملف.', ''));
  }
});

test('B-38: a money reminder carries its amount for the owner only, in data, never in its words', () => {
  const byLabel = new Map(allBuiltNotices().map((entry) => [entry.label, entry.notice]));
  const owner = byLabel.get('payment/owner')!;
  assert.equal((owner.data as Record<string, unknown>).amount, '500000');
  assert.equal((owner.data as Record<string, unknown>).currency, 'YER');
  assert.equal(textFor('MASCULINE', owner.title), 'دفعة قاعة سبأ بعد 5 أيام');
  assert.equal(textFor('MASCULINE', owner.body), 'الجمعة 30 أكتوبر');
  const member = byLabel.get('payment/member')!;
  assert.equal('amount' in (member.data as Record<string, unknown>), false);
  assert.equal('partyName' in (member.data as Record<string, unknown>), false);
  assert.equal(textFor('MASCULINE', member.body), 'الجمعة 30 أكتوبر · التفاصيل في المال');
  assert.equal((byLabel.get('budget/exceeded')!.data as Record<string, unknown>).amount, '500000');
  assert.equal((byLabel.get('loan/soon')!.data as Record<string, unknown>).amount, '150000');
  for (const label of ['offer/received', 'offer/revised', 'accepted/requester', 'booking/CONFIRMED']) {
    assert.equal(JSON.stringify(byLabel.get(label)!.data).includes('amount'), false, label);
  }
});

test('D55: every reminder of the hourly scan is written in its reader form, the same textFor as every notice', () => {
  const notice = taskDueNotice('user-1', { id: 'task-1', weddingPlanId: 'plan-1', title: 'حجز القاعة', dueDate: new Date('2026-10-28T00:00:00.000Z') }, today);
  const gender = { ...notice, body: gendered('خلّصها قبل موعدها.', 'خلّصيها قبل موعدها.') };
  assert.equal(addressDueNotice(gender, 'MASCULINE').body, 'خلّصها قبل موعدها.');
  assert.equal(addressDueNotice(gender, 'FEMININE').body, 'خلّصيها قبل موعدها.');
  // No reminder speaks a command in one gender to everyone.
  for (const { label, notice: row } of allBuiltNotices().filter((entry) => /^(task|payment|budget|loan|countdown)\//u.test(entry.label))) {
    for (const form of FORMS) {
      const written = addressDueNotice(row as DueNotice, form);
      assert.equal(typeof written.title, 'string', label);
      assert.equal(typeof written.body, 'string', label);
      for (const command of ['راجع', 'افتح', 'ادفع', 'تواصل']) {
        assert.equal(written.body.includes(command), false, `${label}/${form}: «${command}» in «${written.body}»`);
      }
    }
  }
});

test('B-38: days read the app way', () => {
  assert.equal(dayMonthWords('2026-10-30'), '30 أكتوبر');
  assert.equal(weekdayDayMonthWords(new Date('2026-10-30T00:00:00.000Z')), 'الجمعة 30 أكتوبر');
  assert.equal(weekdayDayMonthWords(new Date('2027-01-20T21:00:00.000Z')), 'الخميس 21 يناير');
  assert.equal(daysBetween(today, new Date('2026-10-30T00:00:00.000Z')), 5);
  assert.deepEqual([0, 1, 2, 5, 11].map(whenWords), ['اليوم', 'بكرة', 'بعد يومين', 'بعد 5 أيام', 'بعد 11 يوم']);
  assert.deepEqual([1, 2, 4].map(starsWords), ['نجمة وحدة', 'نجمتين', '4 نجوم']);
});

test('B-09: customers read a published reply only; the provider and the team read it in any state', () => {
  const reply = { replyBody: 'شكرًا', repliedAt: new Date('2026-10-20T00:00:00.000Z') };
  assert.deepEqual(publicReviewReply({ ...reply, replyStatus: ReviewStatus.PUBLISHED }), { body: 'شكرًا', repliedAt: reply.repliedAt });
  assert.equal(publicReviewReply({ ...reply, replyStatus: ReviewStatus.HIDDEN }), null);
  assert.equal(publicReviewReply({ replyBody: null, repliedAt: null, replyStatus: null }), null);
  assert.equal(ownerReviewReply({ ...reply, replyStatus: ReviewStatus.HIDDEN })?.status, ReviewStatus.HIDDEN);
});

function sourceFiles(root: string): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(root)) {
    const full = path.join(root, entry);
    if (statSync(full).isDirectory()) files.push(...sourceFiles(full));
    else if (full.endsWith('.ts')) files.push(full);
  }
  return files;
}
