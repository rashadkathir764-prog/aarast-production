import 'reflect-metadata';

import assert from 'node:assert/strict';
import test, { after, before } from 'node:test';
import { AdminController } from '../src/admin/admin.controller';
import { AdminService } from '../src/admin/admin.service';
import { ConversationsController } from '../src/conversations/conversations.controller';
import { ConversationsService } from '../src/conversations/conversations.service';
import {
  AccountAssistantConsentController,
  WeddingPlanAssistantController,
} from '../src/dashboard/assistant/assistant.controller';
import { AssistantService } from '../src/dashboard/assistant/assistant.service';
import { type TestApp, startHttpApp } from './support/http-app';

// RA-TS-28, second part: the admin moderation, catalog and account routes,
// the conversation report and the assistant's consent and report, none of
// which a request in any test or smoke reached. Same pattern as
// http-routes-guards-and-validation.test.ts: the REAL controller, guards,
// passport strategy and global pipes over HTTP (support/http-app.ts); only
// the service behind the route is the test's, and it records what the route
// let through.

type Call = { method: string; args: unknown[] };
const calls: Call[] = [];

function recorder(methods: readonly string[]) {
  return Object.fromEntries(
    methods.map((method) => [
      method,
      async (...args: unknown[]) => {
        calls.push({ method, args });
        return { ok: true };
      },
    ]),
  );
}

const UUID = '3f8e2d6a-9b1c-4e57-8a42-5c0d7e91b2f3';
const ADMIN_METHODS = [
  'activateProvider',
  'activateUser',
  'updateReviewStatus',
  'updateReviewReplyStatus',
  'hideReview',
  'updateConversationReportStatus',
  'resolveAssistantAnswerReport',
  'createCategory',
  'updateCategory',
  'deleteCategory',
  'updateCity',
  'deleteCity',
  'restoreAccountDeletion',
  'decideProfileChange',
  'getBooking',
] as const;

let app: TestApp;

before(async () => {
  app = await startHttpApp(
    [
      AdminController,
      ConversationsController,
      WeddingPlanAssistantController,
      AccountAssistantConsentController,
    ],
    [
      { provide: AdminService, useValue: recorder(ADMIN_METHODS) },
      { provide: ConversationsService, useValue: recorder(['report']) },
      {
        provide: AssistantService,
        useValue: recorder(['recordConsent', 'withdrawConsent', 'reportAnswer']),
      },
    ],
  );
});

after(async () => {
  await app.close();
});

const called = (method: string) => calls.filter((call) => call.method === method);
const reset = () => {
  calls.length = 0;
};
const adminAs = (adminRole: 'SUPER_ADMIN' | 'OPERATIONS' | 'MODERATOR' | 'SUPPORT') =>
  app.tokenFor({ id: `admin-${adminRole}`, adminRole }, 'admin');

// ---------------------------------------------------------------- admin permissions

// Every write below is one permission of AdminPermission; `refused` is the
// role that holds the permission's READ but not its write, so a route guarded
// by the read permission by mistake lets it through and the test fails. The couple's own
// session is not an admin's (403), nobody signed in is 401, and an admin
// whose role lacks the permission is 403; the role that holds it gets through
// to the service with its own id as the acting admin.
const writes: {
  name: string;
  method: string;
  path: string;
  body?: unknown;
  service: (typeof ADMIN_METHODS)[number];
  allowed: 'OPERATIONS' | 'MODERATOR';
  refused: 'OPERATIONS' | 'MODERATOR' | 'SUPPORT';
  status: number;
}[] = [
  { name: 'activate a provider', method: 'PATCH', path: `/admin/providers/${UUID}/activate`, service: 'activateProvider', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 200 },
  { name: 'activate a user', method: 'PATCH', path: `/admin/users/${UUID}/activate`, service: 'activateUser', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 200 },
  { name: 'set a review\'s status', method: 'PATCH', path: `/admin/reviews/${UUID}/status`, body: { status: 'HIDDEN' }, service: 'updateReviewStatus', allowed: 'MODERATOR', refused: 'OPERATIONS', status: 200 },
  { name: 'set a review reply\'s status', method: 'PATCH', path: `/admin/reviews/${UUID}/reply-status`, body: { status: 'HIDDEN' }, service: 'updateReviewReplyStatus', allowed: 'MODERATOR', refused: 'OPERATIONS', status: 200 },
  { name: 'hide a review', method: 'DELETE', path: `/admin/reviews/${UUID}`, service: 'hideReview', allowed: 'MODERATOR', refused: 'OPERATIONS', status: 200 },
  { name: 'close a conversation report', method: 'PATCH', path: `/admin/conversation-reports/${UUID}/status`, body: { status: 'REVIEWED', note: 'تمت المراجعة' }, service: 'updateConversationReportStatus', allowed: 'MODERATOR', refused: 'OPERATIONS', status: 200 },
  { name: 'resolve an assistant answer report', method: 'PATCH', path: `/admin/assistant-reports/${UUID}/resolve`, service: 'resolveAssistantAnswerReport', allowed: 'MODERATOR', refused: 'OPERATIONS', status: 200 },
  { name: 'add a provider category', method: 'POST', path: '/admin/provider-categories', body: { nameAr: 'تصوير' }, service: 'createCategory', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 201 },
  { name: 'edit a provider category', method: 'PATCH', path: `/admin/provider-categories/${UUID}`, body: { nameAr: 'تصوير' }, service: 'updateCategory', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 200 },
  { name: 'delete a provider category', method: 'DELETE', path: `/admin/provider-categories/${UUID}`, service: 'deleteCategory', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 200 },
  { name: 'edit a city', method: 'PATCH', path: `/admin/cities/${UUID}`, body: { nameAr: 'صنعاء' }, service: 'updateCity', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 200 },
  { name: 'delete a city', method: 'DELETE', path: `/admin/cities/${UUID}`, service: 'deleteCity', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 200 },
  { name: 'restore an account out of deletion', method: 'POST', path: `/admin/data-requests/${UUID}/restore`, service: 'restoreAccountDeletion', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 201 },
  { name: 'decide a provider\'s profile change', method: 'PATCH', path: `/admin/provider-profile-changes/${UUID}/decision`, body: { decision: 'APPROVE' }, service: 'decideProfileChange', allowed: 'OPERATIONS', refused: 'SUPPORT', status: 200 },
];

for (const route of writes) {
  test(`admin: ${route.name} is for the role that holds its permission, as itself`, async () => {
    reset();
    const send = (token?: string) =>
      app.request(route.method, route.path, { body: route.body, token });

    assert.equal((await send()).status, 401, 'no session');
    assert.equal((await send(app.tokenFor({ id: 'user-1' }))).status, 403, 'the couple\'s session');
    assert.equal((await send(adminAs(route.refused))).status, 403, `${route.refused} lacks it`);
    assert.equal(called(route.service).length, 0, 'the service is not reached by a refusal');

    const ok = await send(adminAs(route.allowed));
    assert.equal(ok.status, route.status);
    const [call] = called(route.service);
    assert.ok(call, `${route.service} reached`);
    assert.equal((call.args[0] as { id: string }).id, `admin-${route.allowed}`);
    if (route.path.includes(UUID)) {
      assert.ok(call.args.includes(UUID), 'the id in the path is what the service gets');
    }
  });
}

test('admin: a booking is read by a UUID, and never by another word', async () => {
  reset();
  const path = (id: string) => `/admin/bookings/${id}`;
  assert.equal((await app.request('GET', path(UUID))).status, 401);
  assert.equal((await app.request('GET', path(UUID), { token: app.tokenFor({ id: 'user-1' }) })).status, 403);
  const support = adminAs('SUPPORT');
  assert.equal((await app.request('GET', path('not-a-uuid'), { token: support })).status, 400);
  assert.equal((await app.request('GET', path('12345'), { token: support })).status, 400);
  assert.equal(called('getBooking').length, 0);
  assert.equal((await app.request('GET', path(UUID), { token: support })).status, 200);
  assert.deepEqual(called('getBooking').map((call) => call.args), [[UUID]]);
});

// ---------------------------------------------------------------- admin input checks

test('admin: a category and a city are written within their lengths', async () => {
  reset();
  const ops = adminAs('OPERATIONS');
  const long = (n: number) => 'ا'.repeat(n);
  for (const [method, path] of [
    ['POST', '/admin/provider-categories'],
    ['PATCH', `/admin/provider-categories/${UUID}`],
  ] as const) {
    for (const bad of [
      {},
      { nameAr: 12 },
      { nameAr: long(161) },
      { nameAr: 'تصوير', slug: 'a'.repeat(121) },
      { nameAr: 'تصوير', icon: 'a'.repeat(81) },
      { nameAr: 'تصوير', sortOrder: 1.5 },
      { nameAr: 'تصوير', sortOrder: 1_000_001 },
      { nameAr: 'تصوير', isActive: 'yes' },
      { nameAr: 'تصوير', colour: 'red' },
    ]) {
      assert.equal((await app.request(method, path, { token: ops, body: bad })).status, 400, `${method} ${path} ${JSON.stringify(bad).slice(0, 50)}`);
    }
  }
  for (const bad of [{}, { nameAr: long(161) }, { nameAr: 'صنعاء', countryCode: 'YEMEN-XXX' }, { nameAr: 'صنعاء', sortOrder: -1_000_001 }, { nameAr: 'صنعاء', isActive: 1 }]) {
    assert.equal((await app.request('PATCH', `/admin/cities/${UUID}`, { token: ops, body: bad })).status, 400, JSON.stringify(bad).slice(0, 50));
  }
  assert.equal(called('createCategory').length + called('updateCategory').length + called('updateCity').length, 0);

  const ok = await app.request('POST', '/admin/provider-categories', {
    token: ops,
    body: { nameAr: long(160), slug: 'photo', sortOrder: -5, showForBride: true },
  });
  assert.equal(ok.status, 201);
  assert.deepEqual({ ...(called('createCategory')[0].args[1] as object) }, {
    nameAr: long(160),
    slug: 'photo',
    sortOrder: -5,
    showForBride: true,
  });
});

test('admin: a review\'s status, a report\'s status and a profile change\'s decision are checked before the service', async () => {
  reset();
  const moderator = adminAs('MODERATOR');
  const operations = adminAs('OPERATIONS');

  for (const path of [`/admin/reviews/${UUID}/status`, `/admin/reviews/${UUID}/reply-status`, `/admin/conversation-reports/${UUID}/status`]) {
    for (const bad of [{}, { status: 7 }, { status: ['HIDDEN'] }]) {
      assert.equal((await app.request('PATCH', path, { token: moderator, body: bad })).status, 400, `${path} ${JSON.stringify(bad)}`);
    }
  }
  assert.equal((await app.request('PATCH', `/admin/conversation-reports/${UUID}/status`, { token: moderator, body: { status: 'DISMISSED', note: 5 } })).status, 400);
  assert.equal(called('updateReviewStatus').length + called('updateReviewReplyStatus').length + called('updateConversationReportStatus').length, 0);

  const path = `/admin/provider-profile-changes/${UUID}/decision`;
  assert.equal((await app.request('PATCH', '/admin/provider-profile-changes/not-a-uuid/decision', { token: operations, body: { decision: 'APPROVE' } })).status, 400);
  for (const bad of [{}, { decision: 'MAYBE' }, { decision: 'REJECT', reason: 'ا'.repeat(401) }, { decision: 'REJECT', reason: 5 }, { decision: 'REJECT', extra: 1 }]) {
    assert.equal((await app.request('PATCH', path, { token: operations, body: bad })).status, 400, JSON.stringify(bad).slice(0, 50));
  }
  assert.equal(called('decideProfileChange').length, 0);
  assert.equal((await app.request('PATCH', path, { token: operations, body: { decision: 'REJECT', reason: 'الشعار غير واضح' } })).status, 200);
  assert.deepEqual({ ...(called('decideProfileChange')[0].args[2] as object) }, { decision: 'REJECT', reason: 'الشعار غير واضح' });
});

// ---------------------------------------------------------------- conversation report

test('reporting a conversation needs a session and a reason of 3 to 500 characters', async () => {
  reset();
  const path = '/api/v1/conversations/conv-1/report';
  assert.equal((await app.request('POST', path, { body: { reason: 'إساءة' } })).status, 401);
  assert.equal((await app.request('POST', path, { body: { reason: 'إساءة' }, token: adminAs('SUPER_ADMIN') })).status, 401, 'an admin session is another realm');

  const token = app.tokenFor({ id: 'user-reporter' });
  for (const bad of [{}, { reason: '' }, { reason: 'ab' }, { reason: 7 }, { reason: 'ا'.repeat(501) }, { reason: 'إساءة', conversationId: 'other' }]) {
    assert.equal((await app.request('POST', path, { token, body: bad })).status, 400, JSON.stringify(bad).slice(0, 40));
  }
  assert.equal(called('report').length, 0);

  assert.equal((await app.request('POST', path, { token, body: { reason: 'ا'.repeat(500) } })).status, 201);
  const [user, id, reason] = called('report')[0].args as [{ id: string }, string, string];
  assert.equal(user.id, 'user-reporter');
  assert.equal(id, 'conv-1');
  assert.equal(reason.length, 500);
});

// ---------------------------------------------------------------- assistant consent and reports

test('the assistant\'s consent is recorded and taken back by the signed-in owner, for the plan in the path', async () => {
  reset();
  const path = '/api/v1/wedding-plans/plan-1/assistant/consent';
  assert.equal((await app.request('PUT', path)).status, 401);
  assert.equal((await app.request('DELETE', path)).status, 401);
  assert.equal((await app.request('PUT', path, { token: adminAs('SUPER_ADMIN') })).status, 401);
  const leaving = app.tokenFor({ id: 'user-leaving', deletionScheduledFor: new Date('2030-01-01') });
  const refused = await app.request('PUT', path, { token: leaving });
  assert.equal(refused.status, 403);
  assert.equal(refused.body.code, 'ACCOUNT_DELETION_PENDING');
  assert.equal(called('recordConsent').length, 0);

  const token = app.tokenFor({ id: 'user-owner' });
  assert.equal((await app.request('PUT', path, { token })).status, 200);
  assert.equal((await app.request('DELETE', path, { token })).status, 200);
  const [putUser, putPlan] = called('recordConsent')[0].args as [{ id: string }, string];
  assert.deepEqual([putUser.id, putPlan], ['user-owner', 'plan-1']);
  const [delUser, delPlan] = called('withdrawConsent')[0].args as [{ id: string }, string];
  assert.deepEqual([delUser.id, delPlan], ['user-owner', 'plan-1']);
});

test('a report on the assistant\'s answer is checked, trimmed and sent as its reader\'s', async () => {
  reset();
  const path = '/api/v1/wedding-plans/plan-1/assistant/reports';
  const valid = { answerId: 'ans-1', kind: 'PLAN', answer: 'الإجابة', reason: 'غير دقيقة' };
  assert.equal((await app.request('POST', path, { body: valid })).status, 401);

  const token = app.tokenFor({ id: 'user-owner' });
  for (const bad of [
    {},
    { ...valid, kind: 'POETRY' },
    { ...valid, answerId: 'x'.repeat(101) },
    { ...valid, answer: '   ' },
    { ...valid, reason: '' },
    { ...valid, reason: 'ا'.repeat(501) },
    { ...valid, question: 'ا'.repeat(501) },
    { ...valid, answer: 'ا'.repeat(20_001) },
    { ...valid, userId: 'someone-else' },
  ]) {
    assert.equal((await app.request('POST', path, { token, body: bad })).status, 400, JSON.stringify(bad).slice(0, 60));
  }
  assert.equal(called('reportAnswer').length, 0);

  const ok = await app.request('POST', path, {
    token,
    body: { ...valid, question: '  كم الميزانية؟ ', answer: ' الإجابة ', reason: ' غير دقيقة ' },
  });
  assert.equal(ok.status, 201);
  const [user, plan, report] = called('reportAnswer')[0].args as [{ id: string }, string, object];
  assert.deepEqual([user.id, plan], ['user-owner', 'plan-1']);
  assert.deepEqual({ ...report }, {
    answerId: 'ans-1',
    kind: 'PLAN',
    question: 'كم الميزانية؟',
    answer: 'الإجابة',
    reason: 'غير دقيقة',
  });
});
