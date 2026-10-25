import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Prisma } from '@prisma/client';
import { readPlanBookedServices } from '../src/dashboard/plan-booked-services';

// D60: one definition of «محجوز», read by the home tile and the providers
// board. The walk found «2 محجوز» on the home and «محجوز 4» on the board:
// the home counted accepted-offer links.

const tx = {} as Prisma.TransactionClient;

function owners(input: {
  bookings: Array<{ quoteRequestId: string; quoteOfferId: string | null }>;
  costs: Array<{ id: string; quoteOfferId: string; budgetCategoryId: string }>;
  outside: string[];
}) {
  return {
    providers: {
      listPlanConfirmedBookings: async () => input.bookings,
    },
    finance: {
      listCostsForOffers: async (_client: unknown, ids: readonly string[]) =>
        input.costs
          .filter((cost) => ids.includes(cost.quoteOfferId))
          .map((cost) => ({
            ...cost,
            totalAmount: new Prisma.Decimal(1),
            paidAmount: new Prisma.Decimal(0),
            status: 'OPEN' as const,
            lastPaidAt: null,
          })),
      listOutsidePartyItemIds: async () => input.outside,
    },
  };
}

test('a confirmed booking books its item, an outside party books its own, an accepted offer alone books nothing', async () => {
  const booked = await readPlanBookedServices(
    tx,
    owners({
      // The hall and the hospitality are confirmed; the studio's offer was
      // accepted but never confirmed, so it is not listed here at all.
      bookings: [
        { quoteRequestId: 'q-hall', quoteOfferId: 'o-hall' },
        { quoteRequestId: 'q-food', quoteOfferId: 'o-food' },
      ],
      costs: [
        { id: 'c-hall', quoteOfferId: 'o-hall', budgetCategoryId: 'item-hall' },
        { id: 'c-food', quoteOfferId: 'o-food', budgetCategoryId: 'item-food' },
        { id: 'c-studio', quoteOfferId: 'o-studio', budgetCategoryId: 'item-photo' },
      ],
      // The band was agreed outside اعّرست; the hall's item also has one.
      outside: ['item-band', 'item-hall'],
    }),
    'plan-1',
    { quoteRequestIds: null, costIds: null },
  );
  assert.deepEqual(booked, {
    count: 3,
    budgetCategoryIds: ['item-band', 'item-food', 'item-hall'],
    quoteRequestIds: [],
  });
});

test('a booked offer without an item, or whose cost the reader may not see, counts once by its request', async () => {
  const booked = await readPlanBookedServices(
    tx,
    owners({
      bookings: [
        { quoteRequestId: 'q-1', quoteOfferId: 'o-1' },
        { quoteRequestId: 'q-2', quoteOfferId: null },
      ],
      costs: [{ id: 'c-private', quoteOfferId: 'o-1', budgetCategoryId: 'item-1' }],
      outside: [],
    }),
    'plan-1',
    { quoteRequestIds: null, costIds: [] },
  );
  assert.deepEqual(booked, { count: 2, budgetCategoryIds: [], quoteRequestIds: ['q-1', 'q-2'] });
});
