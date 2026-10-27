import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Prisma } from '@prisma/client';
import { summarizeFunding } from '../src/modules/finance/infrastructure/money-picture';
import { taskReminderNotice } from '../src/notifications/plan-reminders';
import { PermissionService } from '../src/modules/collaboration/internal/permission.service';

// The 2026-10-27 owner-vision audit, phase 1 (money correctness).

const d = (value: string | number) => new Prisma.Decimal(value);
const today = new Date('2026-10-27T00:00:00.000Z');

function loan(status: 'PLEDGED' | 'RECEIVED', amount: number, repaid: number) {
  return {
    id: `loan-${status}`,
    weddingPlanId: 'plan-1',
    kind: 'LOAN',
    sourceName: 'خالي',
    sourcePhone: null,
    amount: d(amount),
    status,
    receivedAt: null,
    expectedAt: null,
    note: null,
    createdAt: today,
    updatedAt: today,
    repayments: [
      {
        id: `r-${status}`,
        fundingSourceId: `loan-${status}`,
        amount: d(repaid),
        dueDate: new Date('2026-11-01T00:00:00.000Z'),
        paidAt: null,
        status: 'PLANNED',
        note: null,
        createdAt: today,
        updatedAt: today,
      },
    ],
  } as any;
}

test('G33: a promised loan is no debt until it arrives', () => {
  const spent = { confirmedCost: d(0), paidByOwner: d(0), paidByOthers: d(0), today };
  const pledgedOnly = summarizeFunding([loan('PLEDGED', 500000, 100000)], spent);
  assert.equal(pledgedOnly.loanTotal, '0');
  assert.equal(pledgedOnly.loanOutstanding, '0');
  assert.equal(pledgedOnly.nextLoanRepayment, null);
  assert.equal(pledgedOnly.pledged, '500000');

  const both = summarizeFunding(
    [loan('PLEDGED', 500000, 100000), loan('RECEIVED', 300000, 100000)],
    spent,
  );
  assert.equal(both.loanTotal, '300000');
  assert.equal(both.loanOutstanding, '300000');
  assert.equal(both.nextLoanRepayment?.fundingSourceId, 'loan-RECEIVED');
});

test('G36: the task «ذكّرني» time reminds once per reader and time', () => {
  const reminderAt = new Date('2026-10-27T06:00:00.000Z');
  const notice = taskReminderNotice('user-1', {
    id: 'task-1',
    weddingPlanId: 'plan-1',
    title: 'حجز القاعة',
    reminderAt,
  });
  assert.equal(notice.type, 'TASK_DUE_SOON');
  assert.equal(notice.body, 'حجز القاعة');
  assert.equal(notice.entityId, 'task-1');
  assert.equal(
    notice.dedupeKey,
    'user-1:TASK_REMINDER:task:task-1:2026-10-27T06:00:00.000Z',
  );
  const moved = taskReminderNotice('user-1', {
    id: 'task-1',
    weddingPlanId: 'plan-1',
    title: 'حجز القاعة',
    reminderAt: new Date('2026-10-28T06:00:00.000Z'),
  });
  assert.notEqual(moved.dedupeKey, notice.dedupeKey);
});

test('G15: an archived plan takes settlement of its money, nothing else', async () => {
  const archived = {
    isOwner: true,
    plan: { id: 'plan-1', status: 'ARCHIVED', ownerUserId: 'owner' },
    sharedMember: null,
  };
  const service = Object.create(PermissionService.prototype) as any;
  service.getLockedPlanAccessContext = async () => archived;
  service.canManageMoney = () => true;
  const user = { id: 'owner' } as any;

  await assert.rejects(
    service.assertMoneyManageableInTransaction({}, 'plan-1', user),
    (error: any) => error.getResponse().code === 'PLAN_ARCHIVED_READ_ONLY',
  );
  assert.equal(
    await service.assertMoneyManageableInTransaction({}, 'plan-1', user, { settlement: true }),
    archived,
  );
});
