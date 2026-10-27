import assert from 'node:assert/strict';
import { test } from 'node:test';
import { groupSpending, SPENDING_MIN_PLANS } from '../src/admin/admin-success-report';

// G41: the back office reads what plans agreed per item, anonymous.

const row = (plan: number, total: string, extra: Partial<{ city: string | null; currency: string; itemName: string }> = {}) => ({
  weddingPlanId: `plan-${plan}`,
  itemName: extra.itemName ?? 'قاعة',
  city: extra.city === undefined ? 'صنعاء' : extra.city,
  currency: extra.currency ?? 'YER',
  total,
});

test('a group shows only with enough plans, each plan once', () => {
  assert.equal(SPENDING_MIN_PLANS, 5);
  const four = [1, 2, 3, 4].map((plan) => row(plan, '500000'));
  assert.deepEqual(groupSpending(four), []);

  const rows = [
    row(1, '200000'),
    row(1, '100000'),
    row(2, '400000'),
    row(3, '500000', { city: 'صنعاء ' }),
    row(4, '600000'),
    row(5, '900000'),
    row(6, '50', { currency: 'SAR' }),
    row(7, '1', { city: null }),
  ];
  const [group] = groupSpending(rows);
  assert.equal(group.plans, 5);
  assert.equal(group.min, '300000.00');
  assert.equal(group.median, '500000.00');
  assert.equal(group.max, '900000.00');
  assert.equal(group.currency, 'YER');
  assert.equal(groupSpending(rows).length, 1);
});
