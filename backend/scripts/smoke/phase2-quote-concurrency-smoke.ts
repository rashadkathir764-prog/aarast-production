import 'reflect-metadata';

import assert from 'node:assert/strict';
import {
  Prisma,
  PrismaClient,
  QuoteOfferStatus,
  QuoteRequestStatus,
  SharedMemberRole,
} from '@prisma/client';
import { MarketplaceService } from '../../src/marketplace/marketplace.service';
import { PermissionService } from '../../src/sharing/permission.service';
import { ProviderDashboardService } from '../../src/provider-dashboard/provider-dashboard.service';

const { assertManagedSmokeEnvironment } = require('./smoke-utils.js') as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createPermissionRevocationFixture,
  createQuoteDecisionFixture,
  withFixture,
} = require('../../test/support/phase0-postgres-support.js') as {
  createPermissionRevocationFixture: (
    prisma: any,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<any>;
  createQuoteDecisionFixture: (
    prisma: any,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<any>;
  withFixture: (
    createFixture: (environment: NodeJS.ProcessEnv) => Promise<any>,
    callback: (fixture: any) => Promise<void>,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<void>;
};

assertManagedSmokeEnvironment(process.env);

const prisma = new PrismaClient();
const notifications = {
  createNotification: async (input: unknown) => input,
  createNotificationInTransaction: async (
    _tx: unknown,
    input: unknown,
  ) => input,
};
const repetitions = Number(
  process.env.PHASE2_QUOTE_RACE_REPETITIONS ?? '1',
);
if (
  !Number.isInteger(repetitions) ||
  repetitions < 1 ||
  repetitions > 100
) {
  throw new Error(
    'PHASE2_QUOTE_RACE_REPETITIONS must be an integer from 1 to 100.',
  );
}

function authenticatedUser(user: {
  id: string;
  name: string;
  phone: string | null;
}) {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
  } as any;
}

function deferred(): {
  promise: Promise<void>;
  resolve: () => void;
} {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

async function holdOfferLock(offerId: string): Promise<{
  release: () => Promise<void>;
}> {
  const acquired = deferred();
  const released = deferred();
  let releasedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.$queryRaw(
        Prisma.sql`SELECT "id" FROM "QuoteOffer" WHERE "id" = ${offerId} FOR UPDATE`,
      );
      acquired.resolve();
      await released.promise;
    },
    { timeout: 20_000 },
  );
  await acquired.promise;
  return {
    release: async () => {
      if (!releasedOnce) {
        releasedOnce = true;
        released.resolve();
      }
      await transaction;
    },
  };
}

async function waitForBlockedMutation(
  operation: Promise<unknown>,
  label: string,
): Promise<void> {
  const state = await Promise.race([
    operation.then(
      () => 'settled',
      () => 'settled',
    ),
    new Promise<'blocked'>((resolve) =>
      setTimeout(() => resolve('blocked'), 75),
    ),
  ]);
  assert.equal(state, 'blocked', `${label} must be waiting on the row lock`);
}

function marketplaceWithPermissionSignal(): {
  service: MarketplaceService;
  permissionChecked: Promise<void>;
} {
  const permissions = new PermissionService(prisma as any);
  const permissionChecked = deferred();
  const original = permissions.assertMoneyManageable.bind(permissions);
  permissions.assertMoneyManageable = async (...args) => {
    const context = await original(...args);
    permissionChecked.resolve();
    return context;
  };
  return {
    service: new MarketplaceService(
      prisma as any,
      permissions,
      notifications as any,
    ),
    permissionChecked: permissionChecked.promise,
  };
}

async function assertAcceptedGraph(
  fixture: any,
  expectedAmount: string,
): Promise<void> {
  const [offer, quote, costs, links] = await prisma.$transaction([
    prisma.quoteOffer.findUniqueOrThrow({ where: { id: fixture.offer.id } }),
    prisma.quoteRequest.findUniqueOrThrow({
      where: { id: fixture.quoteRequest.id },
    }),
    prisma.weddingCost.findMany({
      where: { quoteOfferId: fixture.offer.id },
    }),
    prisma.planProviderLink.findMany({
      where: { quoteOfferId: fixture.offer.id },
    }),
  ]);
  assert.equal(offer.status, QuoteOfferStatus.ACCEPTED);
  assert.equal(quote.status, QuoteRequestStatus.ACCEPTED);
  assert.equal(costs.length, 1);
  assert.equal(links.length, 1);
  assert.equal(offer.amount?.toString(), expectedAmount);
  assert.equal(costs[0]?.totalAmount.toString(), expectedAmount);
}

async function assertAcceptWinsRejectRace(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const { service, permissionChecked } =
        marketplaceWithPermissionSignal();
      const actor = authenticatedUser(fixture.owner);
      const blocker = await holdOfferLock(fixture.offer.id);
      const accept = service.acceptQuoteOffer(actor, fixture.offer.id);
      try {
        await permissionChecked;
        await waitForBlockedMutation(accept, 'accept');
        const reject = service.rejectQuoteOffer(actor, fixture.offer.id);
        await waitForBlockedMutation(reject, 'reject');
        await blocker.release();

        const [accepted, rejected] = await Promise.allSettled([accept, reject]);
        assert.equal(accepted.status, 'fulfilled');
        assert.equal(
          rejected.status,
          'rejected',
          'reject must re-read PENDING after accept owns the transition lock',
        );
        await assertAcceptedGraph(fixture, '100');
        const firstCost = await prisma.weddingCost.findUniqueOrThrow({
          where: { quoteOfferId: fixture.offer.id },
          select: { id: true },
        });
        const replay = await service.acceptQuoteOffer(
          actor,
          fixture.offer.id,
        );
        assert.equal(replay.weddingCost.id, firstCost.id);
        assert.equal(
          await prisma.weddingCost.count({
            where: { quoteOfferId: fixture.offer.id },
          }),
          1,
          'accept replay must return the original cost without duplication',
        );
      } finally {
        await blocker.release();
      }
    },
  );
}

async function assertAcceptWinsUpdateRace(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const { service, permissionChecked } =
        marketplaceWithPermissionSignal();
      const providerDashboard = new ProviderDashboardService(
        prisma as any,
        notifications as any,
        {} as any,
      );
      const blocker = await holdOfferLock(fixture.offer.id);
      const accept = service.acceptQuoteOffer(
        authenticatedUser(fixture.owner),
        fixture.offer.id,
      );
      try {
        await permissionChecked;
        await waitForBlockedMutation(accept, 'accept');
        const update = providerDashboard.updateQuoteOffer(
          authenticatedUser(fixture.providerUser),
          fixture.offer.id,
          { amount: 999 } as any,
        );
        await waitForBlockedMutation(update, 'update');
        await blocker.release();

        const [accepted, updated] = await Promise.allSettled([accept, update]);
        assert.equal(accepted.status, 'fulfilled');
        assert.equal(
          updated.status,
          'rejected',
          'update must not change an offer after acceptance wins the lock',
        );
        await assertAcceptedGraph(fixture, '100');
      } finally {
        await blocker.release();
      }
    },
  );
}

async function assertPermissionRevocationWinsBeforeAcceptance(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      await prisma.sharedMember.update({
        where: { id: fixture.sharedMember.id },
        data: { canViewMoney: true, canManageMoney: true },
      });
      const { service, permissionChecked } =
        marketplaceWithPermissionSignal();
      const blocker = await holdOfferLock(fixture.offer.id);
      const accept = service.acceptQuoteOffer(
        authenticatedUser(fixture.member),
        fixture.offer.id,
      );
      try {
        await permissionChecked;
        await waitForBlockedMutation(accept, 'accept');
        await prisma.sharedMember.update({
          where: { id: fixture.sharedMember.id },
          data: {
            role: SharedMemberRole.VIEWER,
            canManageProviders: false,
            canViewMoney: false,
            canManageMoney: false,
          },
        });
        await blocker.release();

        const result = await Promise.allSettled([accept]);
        assert.equal(
          result[0]?.status,
          'rejected',
          'accept must re-check live provider and money permissions in its transaction',
        );
        assert.equal(
          await prisma.weddingCost.count({
            where: { quoteOfferId: fixture.offer.id },
          }),
          0,
        );
        assert.equal(
          await prisma.planProviderLink.count({
            where: { quoteOfferId: fixture.offer.id },
          }),
          0,
        );
        const offer = await prisma.quoteOffer.findUniqueOrThrow({
          where: { id: fixture.offer.id },
        });
        assert.equal(offer.status, QuoteOfferStatus.PENDING);
      } finally {
        await blocker.release();
      }
    },
  );
}

async function assertAcceptWinsCancelRace(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const { service, permissionChecked } =
        marketplaceWithPermissionSignal();
      const actor = authenticatedUser(fixture.owner);
      const blocker = await holdOfferLock(fixture.offer.id);
      const accept = service.acceptQuoteOffer(actor, fixture.offer.id);
      try {
        await permissionChecked;
        await waitForBlockedMutation(accept, 'accept');
        const cancel = service.cancelQuoteRequestForCurrentUser(
          actor,
          fixture.quoteRequest.id,
        );
        await waitForBlockedMutation(cancel, 'cancel');
        await blocker.release();

        const [accepted, cancelled] = await Promise.allSettled([
          accept,
          cancel,
        ]);
        assert.equal(accepted.status, 'fulfilled');
        assert.equal(
          cancelled.status,
          'rejected',
          'cancel must re-read the request state after accept wins the lock',
        );
        await assertAcceptedGraph(fixture, '100');
      } finally {
        await blocker.release();
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    for (let iteration = 0; iteration < repetitions; iteration += 1) {
      await assertAcceptWinsRejectRace();
      await assertAcceptWinsUpdateRace();
      await assertAcceptWinsCancelRace();
      await assertPermissionRevocationWinsBeforeAcceptance();
    }
    console.log(
      `PASS - Phase 2 quote decisions are serialized and permission revocation fails closed (${repetitions} repetition(s)).`,
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
