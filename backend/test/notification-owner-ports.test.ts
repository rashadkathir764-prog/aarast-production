import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  ContributionAction,
  ContributionEntityType,
  PaymentScheduleStatus,
  type Prisma,
  WeddingCostStatus,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from '@prisma/client';
import { findConversationProviderId } from '../src/conversations/conversation-lifecycle';
import { ContributorScopeService } from '../src/modules/collaboration/internal/contributor-scope.service';
import { PermissionService } from '../src/modules/collaboration/internal/permission.service';
import { FinancePortService } from '../src/modules/finance/infrastructure/finance-port.service';
import { ProviderReadService } from '../src/modules/marketplace/infrastructure/provider-read.service';
import { PlanReadService } from '../src/modules/planning/infrastructure/plan-read.service';
import { TasksPortService } from '../src/modules/tasks/infrastructure/tasks-port.service';

// The notifications service used to walk the planning plans, their members,
// the due tasks and payment schedules, the contribution history, the
// provider row and the conversation's provider itself, and to lock the plan,
// member, task, cost, schedule and provider rows with its own SQL. Each
// owner now serves the read and takes the lock on the caller's client with
// the statement notifications ran.

function recorder() {
  const calls: Array<[string, unknown]> = [];
  const sql = (query: { strings: string[]; values: unknown[] }) => ({
    sql: query.strings.join('?').replace(/\s+/g, ' ').trim(),
    values: query.values,
  });
  const delegate = (table: string, results: Record<string, unknown>) =>
    Object.fromEntries(
      Object.entries(results).map(([method, result]) => [
        method,
        async (args: unknown) => { calls.push([`${table}.${method}`, args]); return result; },
      ]),
    );
  const tx = {
    $queryRaw: async (query: { strings: string[]; values: unknown[] }) => { calls.push(['$queryRaw', sql(query)]); return [{ id: 'row' }]; },
    weddingPlan: delegate('weddingPlan', { findMany: [{ id: 'plan-1' }] }),
    sharedMember: delegate('sharedMember', {}),
    contributionEvent: delegate('contributionEvent', {
      findMany: [
        { entityId: 'task-1', entityType: ContributionEntityType.TASK, historyScope: { weddingPlanId: 'plan-1' }, contributorTenure: { actorUserId: 'user-1' } },
        { entityId: 'cost-1', entityType: ContributionEntityType.WEDDING_COST, historyScope: { weddingPlanId: 'plan-1' }, contributorTenure: { actorUserId: null } },
      ],
    }),
    weddingTask: delegate('weddingTask', { findMany: [{ id: 'task-1', weddingPlanId: 'plan-1' }], findUnique: { id: 'task-1', weddingPlanId: 'plan-1' }, findFirst: { id: 'task-1' } }),
    paymentSchedule: delegate('paymentSchedule', { findMany: [{ id: 'schedule-1', weddingCost: { weddingPlanId: 'plan-1' } }], findFirst: { id: 'schedule-1' } }),
    provider: delegate('provider', { findUnique: { id: 'provider-1', userId: 'user-1' } }),
    conversation: delegate('conversation', { findUnique: { providerId: 'provider-1' } }),
  } as unknown as Prisma.TransactionClient;
  return { tx, calls };
}

const before = new Date('2026-09-24T20:59:59.999Z');

test('planning lists the plans in a status and locks plan rows in id order', async () => {
  const { tx, calls } = recorder();
  const plans = new PlanReadService();
  assert.deepEqual(await plans.listPlansInStatus(tx, WeddingPlanStatus.PLANNING), [{ id: 'plan-1' }]);
  assert.deepEqual(await plans.lockPlanRowsForShareInTransaction(tx, []), []);
  assert.deepEqual(await plans.lockPlanRowsForShareInTransaction(tx, ['plan-2', 'plan-1', 'plan-2']), [{ id: 'row' }]);
  assert.deepEqual(calls, [
    ['weddingPlan.findMany', { where: { status: WeddingPlanStatus.PLANNING } }],
    ['$queryRaw', { sql: 'SELECT "id" FROM "WeddingPlan" WHERE "id" = ANY(?::text[]) ORDER BY "id" ASC FOR SHARE', values: [['plan-1', 'plan-2']] }],
  ]);
});

test('collaboration locks every membership row of the plans and lists the live actors\' qualifying contributions', async () => {
  const { tx, calls } = recorder();
  const permissions = new PermissionService({} as any, new PlanReadService());
  await permissions.lockPlanMembershipsForShareInTransaction(tx, []);
  await permissions.lockPlanMembershipsForShareInTransaction(tx, ['plan-2', 'plan-1']);
  const scope = new ContributorScopeService({} as any);
  const rules = [
    { entityType: ContributionEntityType.TASK, actions: [ContributionAction.CREATED, ContributionAction.COMPLETED] },
    { entityType: ContributionEntityType.WEDDING_COST, actions: [ContributionAction.CREATED, ContributionAction.COMPLETED, ContributionAction.PAYMENT_RECORDED] },
  ];
  assert.deepEqual(await scope.listQualifyingContributionsInTransaction(tx, [], ['user-1'], rules), []);
  assert.deepEqual(await scope.listQualifyingContributionsInTransaction(tx, ['plan-1'], [], rules), []);
  assert.deepEqual(await scope.listQualifyingContributionsInTransaction(tx, ['plan-1'], ['user-1'], rules), [
    { entityId: 'task-1', entityType: ContributionEntityType.TASK, weddingPlanId: 'plan-1', actorUserId: 'user-1' },
  ]);
  assert.deepEqual(calls, [
    ['$queryRaw', { sql: 'SELECT "id" FROM "SharedMember" WHERE "weddingPlanId" = ANY(?::text[]) ORDER BY "weddingPlanId" ASC, "id" ASC FOR SHARE', values: [['plan-1', 'plan-2']] }],
    ['contributionEvent.findMany', {
      where: {
        historyScope: { weddingPlanId: { in: ['plan-1'] } },
        contributorTenure: { actorUserId: { in: ['user-1'] } },
        entityId: { not: null },
        OR: [
          { entityType: ContributionEntityType.TASK, action: { in: [ContributionAction.CREATED, ContributionAction.COMPLETED] } },
          { entityType: ContributionEntityType.WEDDING_COST, action: { in: [ContributionAction.CREATED, ContributionAction.COMPLETED, ContributionAction.PAYMENT_RECORDED] } },
        ],
      },
      select: {
        entityId: true,
        entityType: true,
        historyScope: { select: { weddingPlanId: true } },
        contributorTenure: { select: { actorUserId: true } },
      },
    }],
  ]);
});

test('tasks serves the assigned and due tasks, the contributor visibility check and the task locks', async () => {
  const { tx, calls } = recorder();
  const tasks = new TasksPortService();
  assert.deepEqual(await tasks.listAssignedTasks(tx, 'user-1', []), []);
  assert.deepEqual(await tasks.listAssignedTasks(tx, 'user-1', ['plan-1']), [{ id: 'task-1', weddingPlanId: 'plan-1' }]);
  assert.deepEqual(await tasks.listDueTasks(tx, { weddingPlanIds: [], dueBefore: before }), []);
  assert.deepEqual(await tasks.listDueTasks(tx, { weddingPlanIds: ['plan-1'], dueBefore: before, taskIds: [] }), []);
  assert.equal((await tasks.listDueTasks(tx, { weddingPlanIds: ['plan-1'], dueBefore: before })).length, 1);
  assert.equal((await tasks.listDueTasks(tx, { weddingPlanIds: ['plan-1'], dueBefore: before, taskIds: ['task-1'] })).length, 1);
  assert.deepEqual(await tasks.lockTaskForShareInTransaction(tx, 'task-1', 'plan-1'), { id: 'task-1', weddingPlanId: 'plan-1' });
  assert.equal(await tasks.lockTaskForShareInTransaction(tx, 'task-1', 'plan-9'), null);
  await tasks.lockTaskRowsForShareInTransaction(tx, []);
  await tasks.lockTaskRowsForShareInTransaction(tx, ['task-2', 'task-1']);
  assert.equal(await tasks.isTaskVisibleToContributor(tx, 'plan-1', 'task-1', 'user-1', ['task-9']), true);

  const dueWhere = (ids?: string[]) => ({
    ...(ids ? { id: { in: ids } } : {}),
    weddingPlanId: { in: ['plan-1'] },
    dueDate: { not: null, lte: before },
    status: { notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED] },
  });
  assert.deepEqual(calls, [
    ['weddingTask.findMany', { where: { weddingPlanId: { in: ['plan-1'] }, assigneeUserId: 'user-1' }, select: { id: true, weddingPlanId: true } }],
    ['weddingTask.findMany', { where: dueWhere() }],
    ['weddingTask.findMany', { where: dueWhere(['task-1']) }],
    ['$queryRaw', { sql: 'SELECT "id" FROM "WeddingTask" WHERE "id" = ? AND "weddingPlanId" = ? FOR SHARE', values: ['task-1', 'plan-1'] }],
    ['weddingTask.findUnique', { where: { id: 'task-1' } }],
    ['$queryRaw', { sql: 'SELECT "id" FROM "WeddingTask" WHERE "id" = ? AND "weddingPlanId" = ? FOR SHARE', values: ['task-1', 'plan-9'] }],
    ['weddingTask.findUnique', { where: { id: 'task-1' } }],
    ['$queryRaw', { sql: 'SELECT "id" FROM "WeddingTask" WHERE "id" = ANY(?::text[]) ORDER BY "id" ASC FOR SHARE', values: [['task-1', 'task-2']] }],
    ['weddingTask.findFirst', { where: { id: 'task-1', weddingPlanId: 'plan-1', OR: [{ assigneeUserId: 'user-1' }, { id: { in: ['task-9'] } }] }, select: { id: true } }],
  ]);
});

test('finance serves the due schedules, the schedules of contributed costs, the visibility check and the row locks', async () => {
  const { tx, calls } = recorder();
  const finance = new FinancePortService();
  assert.deepEqual(await finance.listDuePaymentSchedules(tx, { weddingPlanIds: [], dueBefore: before }), []);
  assert.deepEqual(await finance.listDuePaymentSchedules(tx, { weddingPlanIds: ['plan-1'], dueBefore: before, scheduleIds: [] }), []);
  assert.equal((await finance.listDuePaymentSchedules(tx, { weddingPlanIds: ['plan-1'], dueBefore: before })).length, 1);
  assert.equal((await finance.listDuePaymentSchedules(tx, { weddingPlanIds: ['plan-1'], dueBefore: before, scheduleIds: ['schedule-1'] })).length, 1);
  assert.deepEqual(await finance.listPaymentScheduleIdsForCosts(tx, [{ weddingPlanId: 'plan-1', costIds: [] }]), []);
  assert.deepEqual(await finance.listPaymentScheduleIdsForCosts(tx, [{ weddingPlanId: 'plan-1', costIds: ['cost-1'] }]), [{ id: 'schedule-1', weddingPlanId: 'plan-1' }]);
  assert.equal(await finance.isPaymentScheduleOfCosts(tx, 'plan-1', 'schedule-1', []), false);
  assert.equal(await finance.isPaymentScheduleOfCosts(tx, 'plan-1', 'schedule-1', ['cost-1']), true);
  await finance.lockCostRowsForShareInTransaction(tx, []);
  await finance.lockCostRowsForShareInTransaction(tx, ['cost-2', 'cost-1']);
  await finance.lockPaymentScheduleRowsForShareInTransaction(tx, ['schedule-1']);

  const dueWhere = (ids?: string[]) => ({
    ...(ids ? { id: { in: ids } } : {}),
    dueDate: { lte: before },
    status: PaymentScheduleStatus.PENDING,
    weddingCost: { weddingPlanId: { in: ['plan-1'] }, status: { not: WeddingCostStatus.CANCELLED } },
  });
  // V1 checklist 4.10: a private cost reminds only its account.
  const include = { weddingCost: { select: { weddingPlanId: true, title: true, partyName: true, providerId: true, privateToUserId: true } } };
  assert.deepEqual(calls, [
    ['paymentSchedule.findMany', { where: dueWhere(), include }],
    ['paymentSchedule.findMany', { where: dueWhere(['schedule-1']), include }],
    ['paymentSchedule.findMany', { where: { OR: [{ weddingCost: { weddingPlanId: 'plan-1', id: { in: ['cost-1'] } } }] }, select: { id: true, weddingCost: { select: { weddingPlanId: true } } } }],
    ['paymentSchedule.findFirst', { where: { id: 'schedule-1', weddingCost: { weddingPlanId: 'plan-1', id: { in: ['cost-1'] } } }, select: { id: true } }],
    ['$queryRaw', { sql: 'SELECT "id" FROM "WeddingCost" WHERE "id" = ANY(?::text[]) ORDER BY "id" ASC FOR SHARE', values: [['cost-1', 'cost-2']] }],
    ['$queryRaw', { sql: 'SELECT "id" FROM "PaymentSchedule" WHERE "id" = ANY(?::text[]) ORDER BY "id" ASC FOR SHARE', values: [['schedule-1']] }],
  ]);
});

test('marketplace locks the user\'s provider row for share and messaging names a conversation\'s provider', async () => {
  const { tx, calls } = recorder();
  assert.deepEqual(await new ProviderReadService().lockOwnedProviderForShareInTransaction(tx, 'user-1'), { id: 'provider-1', userId: 'user-1' });
  assert.equal(await findConversationProviderId(tx, 'conversation-1'), 'provider-1');
  assert.deepEqual(calls, [
    ['$queryRaw', { sql: 'SELECT "id" FROM "Provider" WHERE "userId" = ? FOR SHARE', values: ['user-1'] }],
    ['provider.findUnique', { where: { userId: 'user-1' } }],
    ['conversation.findUnique', { where: { id: 'conversation-1' }, select: { providerId: true } }],
  ]);
});
