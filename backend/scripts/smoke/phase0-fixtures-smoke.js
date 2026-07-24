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

const REQUIRED_OPERATION_OUTPUT_KEYS = Object.freeze([
  'budgetCategory',
  'cost',
  'costPayment',
  'paymentSchedule',
  'planProviderLink',
  'conversationEvent',
  'chatMessage',
  'chatAttachment',
  'notification',
  'outboxEvent',
]);

async function assertClean(prisma, fixture) {
  if (fixture.quoteRequest) {
    const output = fixture.operationOutputs;
    if (!output || typeof output !== 'object') {
      throw new Error(`Phase 0 quote fixture ${fixture.scope} is missing operationOutputs.`);
    }
    for (const key of REQUIRED_OPERATION_OUTPUT_KEYS) {
      const value = output[key];
      if (
        !Object.prototype.hasOwnProperty.call(output, key) ||
        !value ||
        typeof value !== 'object' ||
        typeof value.id !== 'string' ||
        value.id.trim().length === 0
      ) {
        throw new Error(`Phase 0 quote fixture ${fixture.scope} has an invalid operation output: ${key}.`);
      }
    }
  }
  const ids = (...items) => items.filter(Boolean).map((item) => item.id);
  const output = fixture.operationOutputs ?? {};
  const userIds = ids(fixture.actingAdmin, fixture.peerAdmin, fixture.user, fixture.owner, fixture.providerUser, fixture.member);
  const phones = [fixture.user?.phone, fixture.owner?.phone, fixture.providerUser?.phone, fixture.member?.phone]
    .filter(Boolean);
  const checks = [
    prisma.user.count({ where: { id: { in: userIds } } }),
    prisma.otpCode.count({ where: { phone: { in: phones } } }),
    prisma.city.count({ where: { id: { in: ids(fixture.city) } } }),
    prisma.providerCategory.count({ where: { id: { in: ids(fixture.category) } } }),
    prisma.provider.count({ where: { id: { in: ids(fixture.provider) } } }),
    prisma.providerService.count({ where: { id: { in: ids(fixture.service) } } }),
    prisma.weddingPlan.count({ where: { id: { in: ids(fixture.plan) } } }),
    prisma.quoteRequest.count({ where: { id: { in: ids(fixture.quoteRequest) } } }),
    prisma.quoteOffer.count({ where: { id: { in: ids(fixture.offer) } } }),
    prisma.conversation.count({ where: { id: { in: ids(fixture.conversation) } } }),
    prisma.budgetCategory.count({ where: { id: { in: ids(output.budgetCategory) } } }),
    prisma.weddingCost.count({ where: { id: { in: ids(output.cost) } } }),
    prisma.costPayment.count({ where: { id: { in: ids(output.costPayment) } } }),
    prisma.paymentSchedule.count({ where: { id: { in: ids(output.paymentSchedule) } } }),
    prisma.planProviderLink.count({ where: { id: { in: ids(output.planProviderLink) } } }),
    prisma.chatMessage.count({ where: { id: { in: ids(output.chatMessage) } } }),
    prisma.chatAttachment.count({ where: { id: { in: ids(output.chatAttachment) } } }),
    prisma.conversationEvent.count({ where: { id: { in: ids(output.conversationEvent) } } }),
    prisma.conversationParticipant.count({ where: { id: { in: ids(fixture.participant) } } }),
    prisma.notification.count({ where: { id: { in: ids(output.notification) } } }),
    prisma.outboxEvent.count({ where: { id: { in: ids(output.outboxEvent) } } }),
    prisma.sharedMember.count({ where: { id: { in: ids(fixture.sharedMember) } } }),
    prisma.conversationReport.count({ where: { conversationId: { in: ids(fixture.conversation) } } }),
  ];
  if ((await Promise.all(checks)).some(Boolean)) {
    throw new Error(`Phase 0 fixture cleanup left rows for ${fixture.scope}.`);
  }
}

async function createOperationOutputs(prisma, fixture) {
  return prisma.$transaction(async (tx) => {
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
    const paymentSchedule = await tx.paymentSchedule.create({
      data: { weddingCostId: cost.id, amount: 10, dueDate: new Date(Date.now() + 86_400_000) },
    });
    const costPayment = await tx.costPayment.create({ data: { weddingCostId: cost.id, amount: 5 } });
    await tx.weddingCost.update({
      where: { id: cost.id },
      data: { paidAmount: 5, status: 'PARTIALLY_PAID' },
    });
    const planProviderLink = await tx.planProviderLink.create({
    data: {
      weddingPlanId: fixture.plan.id,
      providerId: fixture.provider.id,
      quoteRequestId: fixture.quoteRequest.id,
      quoteOfferId: fixture.offer.id,
    },
    });
    const conversationEvent = await tx.conversationEvent.create({
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
    const chatAttachment = await tx.chatAttachment.create({
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
    const outboxEvent = await tx.outboxEvent.create({
      data: {
        type: 'PHASE0_FIXTURE',
        aggregateType: 'notification',
        aggregateId: notification.id,
        payload: { scope: fixture.scope },
      },
    });
    return {
      budgetCategory: category, cost, costPayment, paymentSchedule, planProviderLink,
      conversationEvent, chatMessage: message, chatAttachment, notification, outboxEvent,
    };
  });
}

async function main() {
  assertManagedSmokeEnvironment(process.env);
  const prisma = new PrismaClient();
  try {
    for (const createFixture of [createSuperAdminPairFixture, createOtpAttemptFixture]) {
      let completedFixture;
      await withFixture(
        (environment) => createFixture(prisma, environment),
        async (fixture) => { completedFixture = fixture; },
      );
      await assertClean(prisma, completedFixture);
    }
    for (const createFixture of [createQuoteDecisionFixture, createPermissionRevocationFixture]) {
      let completedFixture;
      await withFixture(
        (environment) => createFixture(prisma, environment),
        async (fixture) => {
          fixture.operationOutputs = await createOperationOutputs(prisma, fixture);
          completedFixture = fixture;
        },
      );
      await assertClean(prisma, completedFixture);
    }
    console.log('PASS - Phase 0 PostgreSQL fixtures create operation outputs and clean them in finally.');
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}

module.exports = {
  REQUIRED_OPERATION_OUTPUT_KEYS,
  assertClean,
  createOperationOutputs,
  main,
};
