import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Prisma } from '@prisma/client';
import {
  lateTaskWindowStart,
  orderNextSteps,
  type RankedNextStep,
} from '../src/dashboard/dashboard-priority';

// REFINEMENT_SPEC 2.1 (2026-11-26) replaced the old ordering by the item's
// priority label then its day (`selectTopDashboardActions`, which put a task
// late by weeks before a payment due today) with the spec's fixed tiers. The
// two tests below kept their intent, a cap of three and the day deciding
// inside one place, on the new ordering.

const step = (
  id: string,
  tier: number,
  key: number,
  kind: RankedNextStep<string>['kind'] = 'OTHER',
  amount: string | null = null,
): RankedNextStep<string> => ({
  tier,
  key,
  kind,
  amount: amount === null ? null : new Prisma.Decimal(amount),
  step: id,
});

test('next steps are capped at three and ordered by the spec\'s tiers', () => {
  assert.deepEqual(
    orderNextSteps([
      step('setup', 6, 0),
      step('quote', 5, 0, 'QUOTE'),
      step('task-late', 3, 2, 'TASK'),
      step('payment-due', 1, Date.UTC(2026, 5, 25), 'PAYMENT'),
    ]),
    ['payment-due', 'task-late', 'quote'],
  );
});

test('inside one tier the key decides, then the larger amount, then payment before task before offer', () => {
  assert.deepEqual(
    orderNextSteps(
      [
        step('later', 1, Date.UTC(2026, 6, 2), 'PAYMENT', '100'),
        step('sooner-small', 1, Date.UTC(2026, 5, 28), 'PAYMENT', '100'),
        step('sooner-large', 1, Date.UTC(2026, 5, 28), 'PAYMENT', '900'),
      ],
      5,
    ),
    ['sooner-large', 'sooner-small', 'later'],
  );
  assert.deepEqual(
    orderNextSteps([
      step('quote', 4, 0, 'QUOTE'),
      step('task', 4, 0, 'TASK'),
      step('payment', 4, 0, 'PAYMENT'),
    ]),
    ['payment', 'task', 'quote'],
  );
  // Equal in everything: the order they were built in.
  assert.deepEqual(
    orderNextSteps([step('first', 6, 0), step('second', 6, 0)]),
    ['first', 'second'],
  );
});

test('the late-task window starts seven days before today', () => {
  const today = new Date('2026-11-25T21:00:00.000Z');
  assert.equal(
    lateTaskWindowStart(today).toISOString(),
    '2026-11-18T21:00:00.000Z',
  );
});
