import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  parseQuoteOfferLines,
  quoteOfferChanges,
  quoteOfferEditFromOldVersion,
  quoteOfferVersionView,
  readQuoteOfferLines,
} from '../src/modules/marketplace/public/quote-offer-versions';
import {
  providerRejectedRequestNotification,
  requesterRejectedOfferNotification,
} from '../src/marketplace/quote-notifications';

// G24 (owner-vision audit 2026-10-27): B-05, B-07, B-11.

// RA-MO-289: an edit from his other phone's older copy of the offer undid
// the newer one, field by field. The edit names the version it was made
// from, and an older one is refused.
test('an offer edit made from an older version is refused', () => {
  assert.equal(quoteOfferEditFromOldVersion(undefined, 3), null);
  assert.equal(quoteOfferEditFromOldVersion(3, 3), null);
  const refused = quoteOfferEditFromOldVersion(2, 3);
  assert.ok(refused);
  assert.equal(refused.getStatus(), 409);
  assert.deepEqual(
    (refused.getResponse() as { code: string }).code,
    'QUOTE_OFFER_CHANGED',
  );
  // The service checks it after a retry that changes nothing returned.
  const service = readFileSync(
    join(__dirname, '..', 'src', 'provider-dashboard', 'provider-dashboard.service.ts'),
    'utf8',
  );
  assert.match(
    service,
    /if \(changes\.length === 0\) return existing;[\s\S]{0,300}quoteOfferEditFromOldVersion\(\s*dto\.baseVersionNo,/u,
  );
});

test('B-07: offer lines are checked and normalized', () => {
  assert.equal(parseQuoteOfferLines(undefined), undefined);
  assert.equal(parseQuoteOfferLines(null), null);
  assert.equal(parseQuoteOfferLines([]), null);
  assert.deepEqual(
    parseQuoteOfferLines([
      { label: '  ألبوم  40 صورة ', kind: 'INCLUDED' },
      { label: 'فيديو درون', kind: 'EXTRA', amount: '80000' },
      { label: 'الطباعة', kind: 'EXCLUDED' },
    ]),
    [
      { label: 'ألبوم 40 صورة', kind: 'INCLUDED', amount: null },
      { label: 'فيديو درون', kind: 'EXTRA', amount: '80000' },
      { label: 'الطباعة', kind: 'EXCLUDED', amount: null },
    ],
  );
  for (const bad of [
    'نص',
    [{ label: '', kind: 'INCLUDED' }],
    [{ label: 'x', kind: 'MAYBE' }],
    [{ label: 'x', kind: 'INCLUDED', amount: '5' }],
    [{ label: 'x', kind: 'EXTRA', amount: '-5' }],
  ]) {
    assert.throws(
      () => parseQuoteOfferLines(bad),
      (error: any) => error.getResponse().code === 'QUOTE_OFFER_LINES_INVALID',
    );
  }
});

test('B-07: a line change is a version change, hidden from a viewer without money', () => {
  const base = { title: null, message: 'm', amount: '100', currency: 'YER', validUntil: null };
  const changes = quoteOfferChanges(
    { ...base, lines: null, deliveryDays: null },
    {
      ...base,
      lines: [{ label: 'درون', kind: 'EXTRA', amount: '80000' }],
      deliveryDays: 30,
    },
  );
  assert.deepEqual(
    changes.map((change) => change.field),
    ['lines', 'deliveryDays'],
  );
  const view = quoteOfferVersionView(
    {
      currentVersionNo: 2,
      versionChanges: changes as any,
      revisedAt: null,
      withdrawnAt: null,
      withdrawnReason: null,
      lines: [{ label: 'درون', kind: 'EXTRA', amount: '80000' }],
      deliveryDays: 30,
      rejectReason: 'PRICE',
      rejectMessage: null,
    },
    false,
  );
  assert.deepEqual(view.changes.map((change) => change.field), ['deliveryDays']);
  assert.deepEqual(view.lines, [{ label: 'درون', kind: 'EXTRA', amount: null }]);
  assert.equal(view.deliveryDays, 30);
  assert.equal(view.rejectReason, 'PRICE');
  assert.deepEqual(readQuoteOfferLines('broken' as any), []);
});

test('B-05 and B-11: each side reads the other\'s reason in its words', () => {
  const declined = providerRejectedRequestNotification({
    requesterId: 'u1',
    weddingPlanId: 'p1',
    quoteRequestId: 'q1',
    providerId: 'pr1',
    providerName: 'استوديو الفن',
    declineReason: 'BUSY_THAT_DAY',
  });
  assert.equal(declined.title, 'اعتذر استوديو الفن: مشغول ذاك اليوم');
  const rejected = requesterRejectedOfferNotification({
    providerUserId: 'pu1',
    quoteRequestId: 'q1',
    quoteOfferId: 'o1',
    providerId: 'pr1',
    reason: 'PRICE',
  });
  assert.equal(rejected.body, 'السبب: السعر فوق اللي حاسب له');
});
