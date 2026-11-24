import 'reflect-metadata';

import assert from 'node:assert/strict';
import test, { after, before } from 'node:test';
import {
  GuestInvitationLinksController,
  PublicRsvpController,
} from '../src/guests/guest-rsvp.controller';
import { GuestRsvpService } from '../src/guests/guest-rsvp.service';
import { ProviderBookingsController } from '../src/marketplace/bookings.controller';
import { BookingsService } from '../src/marketplace/bookings.service';
import { ProviderDashboardController } from '../src/provider-dashboard/provider-dashboard.controller';
import { ProviderDashboardService } from '../src/provider-dashboard/provider-dashboard.service';
import { AdminController } from '../src/admin/admin.controller';
import { AdminService } from '../src/admin/admin.service';
import { PushController } from '../src/push/push.controller';
import { PushInstallationsService } from '../src/modules/notifications/infrastructure/push-installations.service';
import { type TestApp, startHttpApp } from './support/http-app';

const { futureDay } = require('../scripts/smoke/smoke-utils.js') as {
  futureDay: (daysFromNow: number, now?: Date) => string;
};

// RA-TS-28: routes that no request in any test or smoke ever reached, so
// their guards and their input checks were never run. Each goes over HTTP
// through the real controller, guards, passport strategy and global pipes
// (see support/http-app.ts); only the service behind it is the test's, and
// it records what the route let through.

type Call = { method: string; args: unknown[] };
const calls: Call[] = [];

function recorder<T extends string>(methods: readonly T[], reply: unknown = { ok: true }) {
  return Object.fromEntries(
    methods.map((method) => [
      method,
      async (...args: unknown[]) => {
        calls.push({ method, args });
        return reply;
      },
    ]),
  );
}

const UUID = '3f8e2d6a-9b1c-4e57-8a42-5c0d7e91b2f3';
const owner = { id: 'user-owner' };
const GUEST_ID = 'guest-1';

let app: TestApp;

before(async () => {
  app = await startHttpApp(
    [
      PublicRsvpController,
      GuestInvitationLinksController,
      ProviderBookingsController,
      ProviderDashboardController,
      AdminController,
      PushController,
    ],
    [
      {
        provide: GuestRsvpService,
        useValue: recorder([
          'markInvitationOpened',
          'respond',
          'createInvitationLink',
          'replaceInvitationLink',
          'settleInvitationSend',
        ]),
      },
      {
        provide: BookingsService,
        useValue: recorder(['listBlockedDates', 'blockDate', 'unblockDate']),
      },
      {
        provide: ProviderDashboardService,
        useValue: recorder(['replyToReview']),
      },
      {
        provide: AdminService,
        useValue: recorder([
          'suspendProvider',
          'setProviderVerified',
          'decidePortfolioItem',
        ]),
      },
      {
        provide: PushInstallationsService,
        useValue: recorder(['register', 'unregister']),
      },
    ],
  );
});

after(async () => {
  await app.close();
});

function called(method: string): Call[] {
  return calls.filter((call) => call.method === method);
}

function reset() {
  calls.length = 0;
}

// ---------------------------------------------------------------- public RSVP

test('the invitation page reports that it was opened, with no account and nothing cached', async () => {
  reset();
  const response = await app.request('POST', '/api/v1/public/rsvp/link-token-1/opened');
  assert.equal(response.status, 201);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(called('markInvitationOpened').map((call) => call.args), [['link-token-1']]);
});

test('a guest\'s answer is checked before the service sees it', async () => {
  reset();
  const answer = (body: unknown) =>
    app.request('POST', '/api/v1/public/rsvp/link-token-1', { body });

  for (const bad of [
    { attendance: 'MAYBE' },
    {},
    { attendance: 'CONFIRMED', companionsCount: -1 },
    { attendance: 'CONFIRMED', companionsCount: 1.5 },
    { attendance: 'CONFIRMED', companionsCount: 1000 },
    { attendance: 'CONFIRMED', planEventId: 'x'.repeat(65) },
    { attendance: 'CONFIRMED', guestId: 'someone-else' },
  ]) {
    const response = await answer(bad);
    assert.equal(response.status, 400, JSON.stringify(bad));
  }
  assert.equal(called('respond').length, 0);

  const ok = await answer({ attendance: 'CONFIRMED', companionsCount: 2, planEventId: ' ev-1 ' });
  assert.equal(ok.status, 201);
  assert.deepEqual(called('respond').map((call) => call.args), [['link-token-1', 'CONFIRMED', 2, 'ev-1']]);
});

// ---------------------------------------------------------------- invitation links

test('a guest\'s invitation link needs an application session of its own', async () => {
  reset();
  const path = `/api/v1/guests/${GUEST_ID}/invitation-link`;

  assert.equal((await app.request('POST', path, { body: {} })).status, 401);
  assert.equal(
    (await app.request('POST', path, { body: {}, token: 'not-a-token' })).status,
    401,
  );
  // An admin session is another realm: it is not the plan owner's.
  const adminToken = app.tokenFor({ id: 'admin-1', adminRole: 'SUPER_ADMIN' }, 'admin');
  assert.equal((await app.request('POST', path, { body: {}, token: adminToken })).status, 401);
  // A person waiting out their account's deletion is refused with its code.
  const leaving = app.tokenFor({ id: 'user-leaving', deletionScheduledFor: new Date('2030-01-01') });
  const refused = await app.request('POST', path, { body: {}, token: leaving });
  assert.equal(refused.status, 403);
  assert.equal(refused.body.code, 'ACCOUNT_DELETION_PENDING');
  assert.equal(called('createInvitationLink').length, 0);
});

test('a guest\'s invitation link takes only what D116 names', async () => {
  reset();
  const token = app.tokenFor(owner);
  const path = `/api/v1/guests/${GUEST_ID}/invitation-link`;

  for (const bad of [
    { kind: 'SHOUT' },
    { reminder: 'yes' },
    { channel: 'PIGEON' },
    { planEventId: 'x'.repeat(65) },
    { unknown: true },
  ]) {
    assert.equal((await app.request('POST', path, { body: bad, token })).status, 400, JSON.stringify(bad));
  }
  assert.equal(called('createInvitationLink').length, 0);

  const ok = await app.request('POST', path, {
    body: { reminder: true, planEventId: '  ev-2 ' },
    token,
  });
  assert.equal(ok.status, 201);
  const [user, guestId, options] = called('createInvitationLink')[0].args as any[];
  assert.equal(user.id, owner.id);
  assert.equal(guestId, GUEST_ID);
  assert.deepEqual(options, { reminder: true, kind: undefined, planEventId: 'ev-2', channel: undefined });
});

test('replacing a guest\'s link, and settling a send, are the signed-in owner\'s', async () => {
  reset();
  const replace = `/api/v1/guests/${GUEST_ID}/invitation-link/replace`;
  const settle = '/api/v1/guests/invitation-sends/send-1/settle';
  assert.equal((await app.request('POST', replace)).status, 401);
  assert.equal((await app.request('POST', settle, { body: { sent: true } })).status, 401);

  const token = app.tokenFor(owner);
  assert.equal((await app.request('POST', replace, { token })).status, 201);
  assert.equal(called('replaceInvitationLink')[0].args[1], GUEST_ID);

  assert.equal((await app.request('POST', settle, { token, body: { sent: 'true' } })).status, 400);
  assert.equal((await app.request('POST', settle, { token, body: {} })).status, 400);
  assert.equal(called('settleInvitationSend').length, 0);
  assert.equal((await app.request('POST', settle, { token, body: { sent: false, channel: 'WHATSAPP' } })).status, 201);
  assert.deepEqual(called('settleInvitationSend')[0].args.slice(1), [
    'send-1',
    { sent: false, channel: 'WHATSAPP' },
  ]);
});

// ---------------------------------------------------------------- provider blocked dates

test('a provider\'s blocked days need a session, and a day written as YYYY-MM-DD', async () => {
  reset();
  const path = '/api/v1/provider/me/blocked-dates';
  assert.equal((await app.request('GET', path)).status, 401);
  assert.equal((await app.request('POST', path, { body: { date: futureDay(30) } })).status, 401);
  assert.equal((await app.request('DELETE', `${path}/${futureDay(30)}`)).status, 401);

  const token = app.tokenFor({ id: 'provider-user' });
  assert.equal((await app.request('GET', path, { token })).status, 200);
  assert.equal(called('listBlockedDates').length, 1);

  for (const bad of [{}, { date: 'tomorrow' }, { date: '12/12/2030' }, { date: `${futureDay(30)}T00:00:00Z` }, { date: futureDay(30), extra: 1 }]) {
    assert.equal((await app.request('POST', path, { token, body: bad })).status, 400, JSON.stringify(bad));
  }
  assert.equal(called('blockDate').length, 0);

  const day = futureDay(30);
  assert.equal((await app.request('POST', path, { token, body: { date: day } })).status, 201);
  assert.equal(called('blockDate')[0].args[1], day);

  assert.equal((await app.request('DELETE', `${path}/${day}`, { token })).status, 200);
  assert.equal(called('unblockDate')[0].args[1], day);
});

// ---------------------------------------------------------------- review reply

test('a provider\'s reply to a review needs a session and a body of 1 to 1000 characters', async () => {
  reset();
  const path = '/api/v1/provider/me/reviews/review-1/reply';
  assert.equal((await app.request('POST', path, { body: { body: 'شكرًا' } })).status, 401);

  const token = app.tokenFor({ id: 'provider-user' });
  for (const bad of [{}, { body: '' }, { body: 12 }, { body: 'ا'.repeat(1001) }, { body: 'شكرًا', extra: 1 }]) {
    assert.equal((await app.request('POST', path, { token, body: bad })).status, 400, JSON.stringify(bad).slice(0, 40));
  }
  assert.equal(called('replyToReview').length, 0);

  const ok = await app.request('POST', path, { token, body: { body: 'ا'.repeat(1000) } });
  assert.equal(ok.status, 200);
  const [user, reviewId, dto] = called('replyToReview')[0].args as any[];
  assert.equal(user.id, 'provider-user');
  assert.equal(reviewId, 'review-1');
  assert.equal(dto.body.length, 1000);
});

// ---------------------------------------------------------------- admin

test('an admin route answers only an admin session that holds its permission', async () => {
  reset();
  const verify = `/admin/providers/${UUID}/verify`;
  const suspend = `/admin/providers/${UUID}/suspend`;
  const decide = `/admin/portfolio-items/${UUID}/decision`;

  for (const [method, path, body] of [
    ['PATCH', verify, undefined],
    ['PATCH', suspend, { reason: 'x' }],
    ['PATCH', decide, { decision: 'APPROVE' }],
  ] as const) {
    assert.equal((await app.request(method, path, { body })).status, 401, `${path} with no session`);
    // The couple's own session is a signed-in user, and not an admin's.
    const application = app.tokenFor({ id: 'user-1' });
    assert.equal((await app.request(method, path, { body, token: application })).status, 403, `${path} with an app session`);
    // A signed-in admin without the permission: support reads, never writes.
    const support = app.tokenFor({ id: 'admin-support', adminRole: 'SUPPORT' }, 'admin');
    assert.equal((await app.request(method, path, { body, token: support })).status, 403, `${path} as support`);
  }
  // Verifying and suspending are the operations team's; deciding a photo is the moderators'.
  const operations = app.tokenFor({ id: 'admin-ops', adminRole: 'OPERATIONS' }, 'admin');
  assert.equal((await app.request('PATCH', decide, { body: { decision: 'APPROVE' }, token: operations })).status, 403);
  const moderator = app.tokenFor({ id: 'admin-mod', adminRole: 'MODERATOR' }, 'admin');
  assert.equal((await app.request('PATCH', verify, { token: moderator })).status, 403);
  assert.equal(called('setProviderVerified').length + called('suspendProvider').length + called('decidePortfolioItem').length, 0);
});

test('verifying and suspending a provider reach the service as the acting admin', async () => {
  reset();
  const operations = app.tokenFor({ id: 'admin-ops', adminRole: 'OPERATIONS' }, 'admin');

  assert.equal((await app.request('PATCH', `/admin/providers/${UUID}/verify`, { token: operations })).status, 200);
  assert.equal((await app.request('PATCH', `/admin/providers/${UUID}/unverify`, { token: operations })).status, 200);
  assert.deepEqual(
    called('setProviderVerified').map((call) => [(call.args[0] as any).id, call.args[1], call.args[2]]),
    [['admin-ops', UUID, true], ['admin-ops', UUID, false]],
  );

  const suspend = await app.request('PATCH', `/admin/providers/${UUID}/suspend`, {
    token: operations,
    body: { reason: 'شكاوى متكررة' },
  });
  assert.equal(suspend.status, 200);
  assert.equal((called('suspendProvider')[0].args[2] as any).reason, 'شكاوى متكررة');
  // The refusal's reason is capped at 2000 characters (RA-AD-16).
  assert.equal(
    (await app.request('PATCH', `/admin/providers/${UUID}/suspend`, { token: operations, body: { reason: 'ا'.repeat(2001) } })).status,
    400,
  );
  assert.equal(called('suspendProvider').length, 1);
});

test('a portfolio decision is one of two words on a UUID, with a reason of 400 characters at most', async () => {
  reset();
  const moderator = app.tokenFor({ id: 'admin-mod', adminRole: 'MODERATOR' }, 'admin');
  const path = `/admin/portfolio-items/${UUID}/decision`;

  assert.equal(
    (await app.request('PATCH', '/admin/portfolio-items/not-a-uuid/decision', { token: moderator, body: { decision: 'APPROVE' } })).status,
    400,
  );
  for (const bad of [{}, { decision: 'MAYBE' }, { decision: 'REJECT', reason: 'ا'.repeat(401) }, { decision: 'REJECT', noFacesChecked: 'yes' }]) {
    assert.equal((await app.request('PATCH', path, { token: moderator, body: bad })).status, 400, JSON.stringify(bad).slice(0, 40));
  }
  assert.equal(called('decidePortfolioItem').length, 0);

  const ok = await app.request('PATCH', path, {
    token: moderator,
    body: { decision: 'REJECT', reason: 'الوجوه ظاهرة', noFacesChecked: true },
  });
  assert.equal(ok.status, 200);
  const [user, id, dto] = called('decidePortfolioItem')[0].args as any[];
  assert.equal(user.id, 'admin-mod');
  assert.equal(id, UUID);
  assert.deepEqual({ ...dto }, { decision: 'REJECT', reason: 'الوجوه ظاهرة', noFacesChecked: true });
});

// ---------------------------------------------------------------- push installations

test('a phone\'s push installation needs a session, a safe id and a platform', async () => {
  reset();
  const path = '/api/v1/push/installations/current';
  const fid = 'dGVzdC1pbnN0YWxsYXRpb24';

  assert.equal((await app.request('PUT', path, { body: { fid, platform: 'ANDROID' } })).status, 401);
  assert.equal((await app.request('DELETE', path, { body: { fid, platform: 'ANDROID' } })).status, 401);

  const token = app.tokenFor(owner);
  for (const bad of [
    {},
    { fid, platform: 'WINDOWS' },
    { fid: 'short', platform: 'IOS' },
    { fid: 'has spaces in it xx', platform: 'IOS' },
    { fid: 'a'.repeat(201), platform: 'IOS' },
    { fid, platform: 'IOS', userId: 'someone-else' },
  ]) {
    assert.equal((await app.request('PUT', path, { token, body: bad })).status, 400, JSON.stringify(bad).slice(0, 50));
  }
  assert.equal(called('register').length, 0);

  const ok = await app.request('PUT', path, { token, body: { fid, platform: 'IOS' } });
  assert.equal(ok.status, 200);
  assert.equal(ok.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(called('register')[0].args.slice(1), [fid, 'IOS']);
  assert.equal((called('register')[0].args[0] as any).id, owner.id);
});

test('a person waiting out their deletion can take the phone off, and cannot put it on', async () => {
  reset();
  const path = '/api/v1/push/installations/current';
  const body = { fid: 'dGVzdC1pbnN0YWxsYXRpb24', platform: 'ANDROID' };
  const leaving = app.tokenFor({ id: 'user-leaving', deletionScheduledFor: new Date('2030-01-01') });

  const put = await app.request('PUT', path, { token: leaving, body });
  assert.equal(put.status, 403);
  assert.equal(put.body.code, 'ACCOUNT_DELETION_PENDING');
  assert.equal(called('register').length, 0);

  assert.equal((await app.request('DELETE', path, { token: leaving, body })).status, 200);
  assert.deepEqual(called('unregister')[0].args.slice(1), [body.fid]);
});
