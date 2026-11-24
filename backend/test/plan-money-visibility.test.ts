import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Prisma } from '@prisma/client';
import { WeddingPlansService } from '../src/wedding-plans/wedding-plans.service';
import {
  collaborationHistory,
  collaborationPermissions,
  planningOwnerPorts,
} from './support/owner-ports';

// RA-BE-158: the plan's answer showed its money whenever no permission check
// was handed to it. Money shows only to a reader who may see it.

const plan = {
  id: 'plan-1',
  ownerUserId: 'owner-1',
  title: 'عرس',
  city: null,
  location: null,
  weddingDate: null,
  priorities: [],
  estimatedBudget: new Prisma.Decimal(7_000_000),
  budgetIncludesMahr: true,
  currency: 'YER',
  onboardingPath: null,
  persona: 'GROOM',
  onboardingCompletedAt: null,
  status: 'ACTIVE',
  createdAt: new Date('2026-11-01T00:00:00.000Z'),
  updatedAt: new Date('2026-11-01T00:00:00.000Z'),
};

function service(canViewMoney: boolean) {
  return new WeddingPlansService(
    {} as any,
    collaborationPermissions({ canViewMoney: () => canViewMoney }) as any,
    collaborationHistory({}) as any,
    ...planningOwnerPorts,
  ) as unknown as {
    toResponse(plan: unknown, reader?: unknown): {
      estimatedBudget: string | null;
      budgetIncludesMahr: boolean | null;
    };
  };
}

test('RA-BE-158: with no reader named, the plan answer hides its money', () => {
  const response = service(true).toResponse(plan);
  assert.equal(response.estimatedBudget, null);
  assert.equal(response.budgetIncludesMahr, null);
});

test('RA-BE-158: the plan owner named as reader sees the money; anyone else does not', () => {
  const owner = service(false).toResponse(plan, { ownerUserId: 'owner-1' });
  assert.equal(owner.estimatedBudget, '7000000');
  assert.equal(owner.budgetIncludesMahr, true);

  const stranger = service(true).toResponse(plan, { ownerUserId: 'someone-else' });
  assert.equal(stranger.estimatedBudget, null);
  assert.equal(stranger.budgetIncludesMahr, null);
});

test('RA-BE-158: a shared reader sees the money only with its permission', () => {
  const context = { plan, isOwner: false, sharedMember: { id: 'member-1' } };
  assert.equal(service(false).toResponse(plan, context).estimatedBudget, null);
  assert.equal(service(true).toResponse(plan, context).estimatedBudget, '7000000');
});
