import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NotFoundException } from '@nestjs/common';
import { AdminUserDetails } from '../src/admin/admin-user-details';
import type { AdminConversationReportView } from '../src/admin/admin-owners';

// RA-AD-25: an account's page answers the first week's questions: the plans
// he owns or shares, his business, the chat reports he filed and those filed
// on him, and where he is signed in. No money, no guests.

const now = new Date('2026-10-24T08:00:00.000Z');
const account = {
  id: 'user-1',
  name: 'محمد',
  phone: '+967777000001',
  email: null,
  role: 'USER',
  status: 'ACTIVE',
  avatarUrl: null,
  createdAt: now,
  updatedAt: now,
};

function view(
  id: string,
  reporter: { id: string; name: string },
  reported: AdminConversationReportView['reported'],
  provider = { id: 'provider-9', businessName: 'قاعة الريان' },
): AdminConversationReportView {
  return {
    id,
    conversationId: `c-${id}`,
    reason: `سبب ${id}`,
    status: 'OPEN',
    createdAt: now,
    updatedAt: now,
    reporter: { ...reporter, phone: null, avatarUrl: null },
    conversation: { provider, quoteRequests: [] },
    reported,
  };
}

function harness(overrides: { providerProfile?: unknown; account?: unknown } = {}) {
  const asked: Record<string, unknown[]> = {};
  const owners: any = {
    accounts: {
      getAccount: async () => ('account' in overrides ? overrides.account : account),
      getAccountSessions: async (_tx: unknown, userId: string, at: Date) => {
        asked.sessions = [userId, at];
        return { application: 2, admin: 0, lastLoginAt: now };
      },
    },
    attachAccounts: async (_tx: unknown, rows: any[]) =>
      rows.map((row) => ({ ...row, providerProfile: overrides.providerProfile ?? null })),
    plans: {
      listOwnedPlans: async () => [
        { id: 'plan-1', title: 'عرس محمد ونورة', status: 'PLANNING', weddingDate: now, estimatedBudget: '9000000' },
      ],
      getPlans: async (_tx: unknown, ids: string[]) => {
        asked.memberPlans = ids;
        return [{ id: 'plan-2', title: 'عرس أخوه', status: 'PLANNING', weddingDate: null, estimatedBudget: '1' }];
      },
    },
    collaboration: { listMemberPlanIds: async () => ['plan-2'] },
    messaging: {
      listAccountConversationReports: async (_tx: unknown, who: unknown, take: number) => {
        asked.reports = [who, take];
        return [{ id: 'row' }];
      },
    },
    attachConversationReports: async () => [
      // He reported a business.
      view('r1', { id: 'user-1', name: 'محمد' }, {
        kind: 'PROVIDER',
        provider: { id: 'provider-9', businessName: 'قاعة الريان', status: 'ACTIVE' },
      }),
      // A business reported him.
      view('r2', { id: 'owner-9', name: 'صاحب القاعة' }, {
        kind: 'CUSTOMER',
        user: { id: 'user-1', name: 'محمد', phone: null },
      }),
      // Someone reported his business.
      view('r3', { id: 'user-5', name: 'سالم' }, {
        kind: 'PROVIDER',
        provider: { id: 'provider-1', businessName: 'استوديو ضوء', status: 'ACTIVE' },
      }, { id: 'provider-1', businessName: 'استوديو ضوء' }),
      // Another member of his plan reported a business: not about him.
      view('r4', { id: 'user-7', name: 'أخوه' }, {
        kind: 'PROVIDER',
        provider: { id: 'provider-9', businessName: 'قاعة الريان', status: 'ACTIVE' },
      }),
    ],
  };
  const prisma: any = { $transaction: async (run: (tx: unknown) => unknown) => run({}) };
  return { details: new AdminUserDetails({ prisma, owners }), asked };
}

test('the account page names his plans, his business, the reports on both sides and his sessions', async () => {
  const { details, asked } = harness({
    providerProfile: {
      id: 'provider-1',
      businessName: 'استوديو ضوء',
      status: 'ACTIVE',
      city: null,
      primaryCategory: null,
    },
  });

  const user = await details.get('user-1', now);

  assert.deepEqual(user.plans, [
    { id: 'plan-1', title: 'عرس محمد ونورة', status: 'PLANNING', weddingDate: now, role: 'OWNER' },
    { id: 'plan-2', title: 'عرس أخوه', status: 'PLANNING', weddingDate: null, role: 'MEMBER' },
  ]);
  assert.equal(JSON.stringify(user.plans).includes('estimatedBudget'), false);
  assert.equal(user.provider?.businessName, 'استوديو ضوء');
  assert.deepEqual(asked.reports, [{ userId: 'user-1', providerId: 'provider-1' }, 20]);
  assert.deepEqual(
    user.reports.map(({ id, direction, counterpart }) => ({ id, direction, counterpart })),
    [
      { id: 'r1', direction: 'FILED', counterpart: 'قاعة الريان' },
      { id: 'r2', direction: 'AGAINST', counterpart: 'قاعة الريان' },
      { id: 'r3', direction: 'AGAINST', counterpart: 'سالم' },
    ],
  );
  assert.deepEqual(user.sessions, { application: 2, admin: 0, lastLoginAt: now });
  assert.deepEqual(asked.sessions, ['user-1', now]);
  assert.deepEqual(asked.memberPlans, ['plan-2']);
});

test('an account that is not there is a 404', async () => {
  const { details } = harness({ account: null });
  await assert.rejects(details.get('gone', now), NotFoundException);
});
