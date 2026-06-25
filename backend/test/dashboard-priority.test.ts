import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { selectTopDashboardActions } from '../src/dashboard/dashboard-priority';

test('dashboard next actions are capped at three and ordered by priority', () => {
  const actions = selectTopDashboardActions([
    { id: 'setup', priority: 'LOW' as const, dueDate: null },
    { id: 'quote', priority: 'HIGH' as const, dueDate: null },
    {
      id: 'overdue-task',
      priority: 'URGENT' as const,
      dueDate: new Date('2026-06-20T00:00:00.000Z'),
    },
    {
      id: 'installment',
      priority: 'URGENT' as const,
      dueDate: new Date('2026-06-25T00:00:00.000Z'),
    },
  ]);

  assert.deepEqual(
    actions.map((action) => action.id),
    ['overdue-task', 'installment', 'quote'],
  );
});

test('dashboard actions use due date ordering inside the same priority', () => {
  const actions = selectTopDashboardActions([
    {
      id: 'later',
      priority: 'HIGH' as const,
      dueDate: new Date('2026-07-02T00:00:00.000Z'),
    },
    {
      id: 'sooner',
      priority: 'HIGH' as const,
      dueDate: new Date('2026-06-28T00:00:00.000Z'),
    },
  ]);

  assert.equal(actions[0]?.id, 'sooner');
});
