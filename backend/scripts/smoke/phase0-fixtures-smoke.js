#!/usr/bin/env node
'use strict';

const { PrismaClient } = require('@prisma/client');
const { assertManagedSmokeEnvironment } = require('./smoke-utils');
const {
  createOtpAttemptFixture,
  createPermissionRevocationFixture,
  createQuoteDecisionFixture,
  createSuperAdminPairFixture,
  withFixture,
} = require('../../test/support/phase0-postgres-support');

assertManagedSmokeEnvironment(process.env);

async function assertClean(prisma, scope) {
  const [
    users, plans, quotes, conversations, budgetCategories, weddingCosts, costPayments, paymentSchedules,
    planProviderLinks, chatMessages, chatAttachments, conversationEvents, conversationParticipants,
    notifications, outboxEvents, sharedMembers, conversationReports,
  ] = await Promise.all([
    prisma.user.count({ where: { appEmail: { contains: scope } } }),
    prisma.weddingPlan.count({ where: { title: { contains: scope } } }),
    prisma.quoteOffer.count({ where: { title: { contains: scope } } }),
    prisma.conversation.count({ where: { createdBy: { appEmail: { contains: scope } } } }),
    prisma.budgetCategory.count({ where: { name: { contains: scope } } }),
    prisma.weddingCost.count({ where: { title: { contains: scope } } }),
    prisma.costPayment.count({ where: { weddingCost: { title: { contains: scope } } } }),
    prisma.paymentSchedule.count({ where: { weddingCost: { title: { contains: scope } } } }),
    prisma.planProviderLink.count({ where: { weddingPlan: { title: { contains: scope } } } }),
    prisma.chatMessage.count({ where: { body: scope } }),
    prisma.chatAttachment.count({ where: { message: { body: scope } } }),
    prisma.conversationEvent.count({ where: { dedupeKey: `phase0-${scope}` } }),
    prisma.conversationParticipant.count({ where: { user: { appEmail: { contains: scope } } } }),
    prisma.notification.count({ where: { title: scope } }),
    prisma.outboxEvent.count({ where: { type: 'PHASE0_FIXTURE' } }),
    prisma.sharedMember.count({ where: { user: { appEmail: { contains: scope } } } }),
    prisma.conversationReport.count({ where: { reporter: { appEmail: { contains: scope } } } }),
  ]);
  if ([
    users, plans, quotes, conversations, budgetCategories, weddingCosts, costPayments, paymentSchedules,
    planProviderLinks, chatMessages, chatAttachments, conversationEvents, conversationParticipants,
    notifications, outboxEvents, sharedMembers, conversationReports,
  ].some(Boolean)) {
    throw new Error(`Phase 0 fixture cleanup left rows for ${scope}.`);
  }
}

async function createOperationOutputs(prisma, fixture) {
  await prisma.$transaction(async (tx) => {
    const category = await tx.budgetCategory.create({
      data: {
        weddingPlanId: fixture.plan.id,
        name: `Phase 0 output ${fixture.scope}`,
        normalizedName: `phase0-output-${fixture.scope}`,
      },
    });
    const cost = await tx.weddingCost.create({
      data: {
        weddingPlanId: fixture.plan.id,
        budgetCategoryId: category.id,
        providerId: fixture.provider.id,
        quoteOfferId: fixture.offer.id,
        title: `Phase 0 output ${fixture.scope}`,
        totalAmount: 100,
      },
    });
    await tx.paymentSchedule.create({
      data: { weddingCostId: cost.id, amount: 10, dueDate: new Date(Date.now() + 86_400_000) },
    });
    await tx.costPayment.create({ data: { weddingCostId: cost.id, amount: 5 } });
    await tx.weddingCost.update({
      where: { id: cost.id },
      data: { paidAmount: 5, status: 'PARTIALLY_PAID' },
    });
    await tx.planProviderLink.create({
    data: {
      weddingPlanId: fixture.plan.id,
      providerId: fixture.provider.id,
      quoteRequestId: fixture.quoteRequest.id,
      quoteOfferId: fixture.offer.id,
    },
    });
    await tx.conversationEvent.create({
    data: {
      conversationId: fixture.conversation.id,
      quoteRequestId: fixture.quoteRequest.id,
      quoteOfferId: fixture.offer.id,
      type: 'QUOTE_OFFER_ACCEPTED',
      dedupeKey: `phase0-${fixture.scope}`,
    },
    });
    const message = await tx.chatMessage.create({
    data: { conversationId: fixture.conversation.id, senderUserId: fixture.owner.id, body: fixture.scope },
    });
    await tx.chatAttachment.create({
    data: { messageId: message.id, storageKey: `phase0/${fixture.scope}`, contentType: 'image/webp', byteSize: 1 },
    });
    const notification = await tx.notification.create({
      data: {
        userId: fixture.owner.id,
        weddingPlanId: fixture.plan.id,
        type: 'GENERAL',
        title: fixture.scope,
        body: fixture.scope,
      },
    });
    await tx.outboxEvent.create({
      data: {
        type: 'PHASE0_FIXTURE',
        aggregateType: 'notification',
        aggregateId: notification.id,
        payload: { scope: fixture.scope },
      },
    });
  });
}

async function main() {
  const prisma = new PrismaClient();
  try {
    for (const createFixture of [createSuperAdminPairFixture, createOtpAttemptFixture]) {
      let scope;
      await withFixture(
        (environment) => createFixture(prisma, environment),
        async (fixture) => { scope = fixture.scope; },
      );
      await assertClean(prisma, scope);
    }
    for (const createFixture of [createQuoteDecisionFixture, createPermissionRevocationFixture]) {
      let scope;
      await withFixture(
        (environment) => createFixture(prisma, environment),
        async (fixture) => { scope = fixture.scope; await createOperationOutputs(prisma, fixture); },
      );
      await assertClean(prisma, scope);
    }
    console.log('PASS - Phase 0 PostgreSQL fixtures create operation outputs and clean them in finally.');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
