import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import * as presenter from '../src/dashboard/dashboard-summary.presenter';
import {
  bookingCustomerNotification,
  bookingProviderNotification,
  bookingReminderNotifications,
} from '../src/marketplace/booking-notifications';
import { quoteOfferCurrencyMismatch } from '../src/marketplace/quote-offer-currency';
import {
  quoteOfferReceivedNotification,
  quoteOfferWithdrawnNotification,
} from '../src/marketplace/quote-notifications';
import {
  mahrAgreementViolation,
  mahrPicture,
  mahrRemaining,
  mahrSideOf,
} from '../src/modules/finance/domain/mahr-policy';
import { parseMahrAgreement } from '../src/modules/finance/public/mahr-agreement';
import { pushNotificationCopy } from '../src/push/push-notification.policy';
import {
  addressFormOf,
  gendered,
  isGendered,
  textFor,
} from '../src/shared-kernel/voice/address-form';

const d = (value: string | number) => new Prisma.Decimal(value);

test('B5: the reader is spoken to by who they are, not by whose plan it is', () => {
  // محمد (a groom) helping in سلمى's plan.
  assert.equal(
    addressFormOf({ accountPersona: 'GROOM', memberRole: 'GROOM', planPersona: 'BRIDE' }),
    'MASCULINE',
  );
  // سلمى (a bride) as family in محمد's plan.
  assert.equal(
    addressFormOf({ accountPersona: 'BRIDE', memberRole: 'FAMILY', planPersona: 'GROOM' }),
    'FEMININE',
  );
  // An invited bride who never made her own plan: her partner role says it.
  assert.equal(
    addressFormOf({ accountPersona: null, memberRole: 'BRIDE', planPersona: 'GROOM' }),
    'FEMININE',
  );
  // Someone unknown speaks as the plan's own party: نورة in the women's
  // wedding, الوالد in the men's.
  assert.equal(
    addressFormOf({ accountPersona: 'HELPER', memberRole: 'HELPER', planPersona: 'BRIDE' }),
    'FEMININE',
  );
  assert.equal(
    addressFormOf({ accountPersona: 'HELPER', memberRole: 'VIEWER', planPersona: 'GROOM' }),
    'MASCULINE',
  );
  assert.equal(addressFormOf({}), 'MASCULINE');
  const text = gendered('افتح', 'افتحي');
  assert.equal(textFor('MASCULINE', text), 'افتح');
  assert.equal(textFor('FEMININE', text), 'افتحي');
  assert.equal(textFor('FEMININE', 'تم'), 'تم');
  assert.equal(isGendered('تم'), false);
});

test('B5: the mahr side follows the plan persona and its amounts stay within the mahr', () => {
  assert.equal(mahrSideOf('GROOM'), 'PAYS');
  assert.equal(mahrSideOf('BRIDE'), 'RECEIVES');
  assert.equal(mahrSideOf('HELPER'), null);
  assert.equal(mahrSideOf(null), null);

  assert.equal(mahrAgreementViolation({ total: d(3_000_000), settled: d(2_000_000) }), null);
  assert.equal(mahrAgreementViolation({ total: d(3_000_000), settled: d(3_000_000) }), null);
  assert.equal(mahrAgreementViolation({ total: d(0), settled: d(0) })?.kind, 'invalid');
  assert.equal(
    mahrAgreementViolation({ total: d(3_000_000), settled: d(3_000_001) })?.kind,
    'invalid',
  );

  const due = new Date('2026-11-15T00:00:00.000Z');
  assert.deepEqual(
    mahrRemaining({ total: d(3_000_000), settled: d(2_000_000), remainingDueAt: due }),
    { amount: d(1_000_000), dueAt: due },
  );
  // Nothing left has no due day.
  assert.equal(
    mahrRemaining({ total: d(3_000_000), settled: d(3_000_000), remainingDueAt: due }).dueAt,
    null,
  );

  assert.deepEqual(mahrPicture('PAYS', d(3_000_000), d(2_000_000), due), {
    side: 'PAYS',
    total: '3000000',
    settled: '2000000',
    remaining: '1000000',
    nextDueAt: due,
    complete: false,
  });
  const done = mahrPicture('RECEIVES', d(3_000_000), d(3_000_000), due);
  assert.equal(done.complete, true);
  assert.equal(done.nextDueAt, null);
});

test('B5: a06 is read as money and a day; a bad amount or day is refused', () => {
  const agreement = parseMahrAgreement({
    total: '3000000',
    settled: 2_000_000,
    remainingDueDate: '2026-11-15',
  });
  assert.equal(agreement.total.toString(), '3000000');
  assert.equal(agreement.settled.toString(), '2000000');
  assert.equal(agreement.remainingDueAt?.toISOString(), '2026-11-15T00:00:00.000Z');
  assert.equal(parseMahrAgreement({ total: '5' }).settled.toString(), '0');
  assert.throws(() => parseMahrAgreement({ total: '-1' }), BadRequestException);
  assert.throws(() => parseMahrAgreement({ total: 'ثلاثة' }), BadRequestException);
  assert.throws(
    () => parseMahrAgreement({ total: '3', remainingDueDate: 'not-a-date' }),
    BadRequestException,
  );
});

test('B5: the home next steps speak to a bride in the feminine and name her guests', () => {
  const base = {
    weddingPlanId: 'plan-1',
    tasks: [],
    paymentSchedules: [],
    providers: [],
    today: new Date(2026, 9, 25),
    receivedQuotes: 0,
    pendingInvites: 0,
    hasLocation: false,
    hasBudget: false,
    guestCount: 0,
    quoteRequestsCount: 0,
    acceptedProviders: 0,
    currency: 'YER',
  };
  const bride = presenter.buildImportantItems({
    ...base,
    form: 'FEMININE',
    planPersona: 'BRIDE',
  });
  const titles = bride.map((item) => item.title);
  assert.ok(titles.includes('أكملي موقع الزفاف'), titles.join(' | '));
  assert.ok(titles.includes('حددي ميزانية الخطة'));
  assert.ok(titles.includes('ابدئي قائمة الضيفات'));
  const offers = presenter.buildImportantItems({
    ...base,
    receivedQuotes: 1,
    hasLocation: true,
    hasBudget: true,
    guestCount: 3,
    form: 'FEMININE',
    planPersona: 'BRIDE',
  });
  assert.equal(
    offers.find((item) => item.type === 'QUOTE_RECEIVED')?.body,
    'راجعي العرض الحقيقي ثم اقبليه أو ارفضيه من مركز الخطة.',
  );

  // A groom helping in the bride's plan: his own form, her plan's guests.
  const groomInBridePlan = presenter.buildImportantItems({
    ...base,
    form: 'MASCULINE',
    planPersona: 'BRIDE',
  });
  assert.ok(
    groomInBridePlan.map((item) => item.title).includes('ابدأ قائمة الضيفات'),
  );
});

test('B5: notices to the customer come in both forms; to the provider they name the customer without her gender', () => {
  const offer = quoteOfferReceivedNotification({
    requesterId: 'u1',
    weddingPlanId: 'p1',
    quoteRequestId: 'q1',
    quoteOfferId: 'o1',
    providerId: 'pr1',
    providerName: 'صالة الياسمين',
  });
  assert.match(textFor('FEMININE', offer.body), /افتحي الطلب/u);
  assert.match(textFor('MASCULINE', offer.body), /افتح الطلب/u);

  const withdrawn = quoteOfferWithdrawnNotification({
    requesterId: 'u1',
    weddingPlanId: 'p1',
    quoteRequestId: 'q1',
    quoteOfferId: 'o1',
    providerId: 'pr1',
    providerName: 'صالة الياسمين',
  });
  assert.match(textFor('FEMININE', withdrawn.body), /تقدرين تسأليه/u);

  const booking = {
    bookingId: 'b1',
    quoteRequestId: 'q1',
    providerId: 'pr1',
    eventDate: new Date('2027-01-21T00:00:00.000Z'),
    revision: 1,
  };
  const cancelled = bookingCustomerNotification('CANCELLED', {
    ...booking,
    customerUserId: 'u1',
    weddingPlanId: 'p1',
    providerName: 'صالة الياسمين',
  });
  // B-38: the day in words; still her form.
  assert.match(textFor('FEMININE', cancelled.body), /تقدرين تكلمينه أو تختارين/u);
  assert.match(textFor('MASCULINE', cancelled.body), /تقدر تكلمه أو تختار/u);

  const requested = bookingProviderNotification('REQUESTED', {
    ...booking,
    providerUserId: 'pu',
    customerName: 'سلمى السقاف',
  });
  assert.equal(typeof requested.title, 'string');
  assert.equal(typeof requested.body, 'string');
  // B-38: «طلب حجز … من …» names her without a verb in her gender, the day
  // in words and no «بوابة المزوّد».
  assert.equal(requested.title, 'طلب حجز من سلمى');
  assert.equal(requested.body, 'يوم الخميس 21 يناير. أكّد الحجز أو اعتذر.');
  assert.doesNotMatch(`${requested.title} ${requested.body}`, /سلمى يطلب|سلمى تطلب/u);

  const [customerReminder] = bookingReminderNotifications(
    {
      bookingId: 'b1',
      quoteRequestId: 'q1',
      providerId: 'pr1',
      eventDate: new Date('2027-01-21T00:00:00.000Z'),
      customerUserId: 'u1',
      weddingPlanId: 'p1',
      customerName: 'سلمى',
      providerUserId: null,
      providerName: 'صالة الياسمين',
    },
    new Date('2027-01-20T00:00:00.000Z'),
  );
  assert.match(textFor('FEMININE', customerReminder.body), /تواصلي معه/u);
});

test('B5: the lock screen tells without an imperative in either gender', () => {
  const customerTypes = [
    NotificationType.TASK_ASSIGNED,
    NotificationType.TASK_DUE_SOON,
    NotificationType.CHAT_MESSAGE_RECEIVED,
    NotificationType.WEDDING_COUNTDOWN,
    NotificationType.QUOTE_OFFER_RECEIVED,
    NotificationType.BOOKING_UPDATED,
  ];
  for (const type of customerTypes) {
    const copy = pushNotificationCopy(type, { versionNo: 2 });
    assert.doesNotMatch(copy.body, /افتح|شوف|راجع/u, `${type}: ${copy.body}`);
  }
});

test('B5: a currency refusal speaks to the customer in her form', () => {
  const error = quoteOfferCurrencyMismatch('YER', 'customer', 'FEMININE');
  const body = error.getResponse() as { message: string };
  assert.match(body.message, /اطلبي من المزود/u);
  const provider = quoteOfferCurrencyMismatch('YER', 'provider').getResponse() as {
    message: string;
  };
  assert.match(provider.message, /فأرسل عرضك/u);
});
