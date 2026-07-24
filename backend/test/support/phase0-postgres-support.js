'use strict';

const { createHash, randomBytes } = require('crypto');
const { assertManagedSmokeEnvironment } = require('../../scripts/smoke/smoke-utils');

// Reusable managed-PostgreSQL support for Phase 0 and later RED tests.

function fixtureScope(label, environment = process.env, nonce = randomBytes(6).toString('hex')) {
  if (!/^[a-z][a-z0-9-]{2,32}$/.test(label)) {
    throw new Error('Phase 0 fixture label must be a short lowercase identifier.');
  }
  const { runId } = assertManagedSmokeEnvironment(environment);
  return `phase0-${runId}-${label}-${nonce}`;
}

function fixtureEmail(scope, label) {
  return `${label}.${scope}@phase0.invalid`;
}

function fixturePhone(scope, label) {
  const digits = createHash('sha256')
    .update(`${scope}:${label}`)
    .digest('hex')
    .split('')
    .map((character) => String(parseInt(character, 16) % 10))
    .join('');
  return `+9677${digits.slice(0, 7)}`;
}

function userData(scope, label, overrides = {}) {
  return {
    name: `Phase 0 ${label}`,
    phone: fixturePhone(scope, label),
    appEmail: fixtureEmail(scope, label),
    passwordHash: 'phase0-test-fixture-not-a-credential',
    phoneVerifiedAt: new Date(),
    ...overrides,
  };
}

async function inTransaction(prisma, callback) {
  return prisma.$transaction(callback);
}

async function cleanupUsers(tx, userIds) {
  const users = await tx.user.findMany({
    where: { id: { in: userIds } },
    select: { phone: true },
  });
  const phones = users.map((user) => user.phone).filter(Boolean);
  await tx.adminLoginChallenge.deleteMany({ where: { userId: { in: userIds } } });
  await tx.adminPasswordResetChallenge.deleteMany({ where: { userId: { in: userIds } } });
  await tx.refreshToken.deleteMany({ where: { userId: { in: userIds } } });
  if (phones.length) await tx.otpCode.deleteMany({ where: { phone: { in: phones } } });
  await tx.user.deleteMany({ where: { id: { in: userIds } } });
}

async function createSuperAdminPairFixture(prisma, environment = process.env) {
  const scope = fixtureScope('super-admins', environment);
  const created = await inTransaction(prisma, async (tx) => {
    const [actingAdmin, peerAdmin] = await Promise.all([
      tx.user.create({ data: userData(scope, 'acting-admin', { role: 'ADMIN', adminRole: 'SUPER_ADMIN' }) }),
      tx.user.create({ data: userData(scope, 'peer-admin', { role: 'ADMIN', adminRole: 'SUPER_ADMIN' }) }),
    ]);
    return { scope, actingAdmin, peerAdmin };
  });
  return {
    ...created,
    cleanup: () => inTransaction(prisma, (tx) => cleanupUsers(tx, [created.actingAdmin.id, created.peerAdmin.id])),
  };
}

async function createOtpAttemptFixture(prisma, environment = process.env) {
  const scope = fixtureScope('otp-ceiling', environment);
  const created = await inTransaction(prisma, async (tx) => {
    const user = await tx.user.create({ data: userData(scope, 'otp-user') });
    const otp = await tx.otpCode.create({
      data: {
        phone: user.phone,
        codeHash: 'phase0-test-otp-hash',
        purpose: 'LOGIN',
        expiresAt: new Date(Date.now() + 5 * 60 * 1000),
        maxAttempts: 5,
      },
    });
    return { scope, user, otp };
  });
  return {
    ...created,
    cleanup: () => inTransaction(prisma, async (tx) => {
      await tx.otpCode.deleteMany({ where: { id: created.otp.id } });
      await cleanupUsers(tx, [created.user.id]);
    }),
  };
}

async function createQuoteDecisionFixture(prisma, environment = process.env) {
  const scope = fixtureScope('quote-decision', environment);
  const created = await inTransaction(prisma, (tx) => createQuoteDecisionRows(tx, scope));
  return { ...created, cleanup: () => cleanupQuoteFixtureGraph(prisma, created) };
}

async function createPermissionRevocationFixture(prisma, environment = process.env) {
  const scope = fixtureScope('permission-revocation', environment);
  const created = await inTransaction(prisma, async (tx) => {
    const quote = await createQuoteDecisionRows(tx, scope);
    const member = await tx.user.create({ data: userData(scope, 'provider-member') });
    const sharedMember = await tx.sharedMember.create({
      data: {
        weddingPlanId: quote.plan.id,
        userId: member.id,
        role: 'MANAGER',
        canManageProviders: true,
      },
    });
    const participant = await tx.conversationParticipant.create({
      data: { conversationId: quote.conversation.id, userId: member.id },
    });
    return { ...quote, member, sharedMember, participant };
  });
  return {
    ...created,
    cleanup: () => cleanupQuoteFixtureGraph(prisma, created),
  };
}

async function createQuoteDecisionRows(tx, scope) {
  const owner = await tx.user.create({ data: userData(scope, 'plan-owner') });
  const providerUser = await tx.user.create({
    data: userData(scope, 'provider-user', { role: 'PROVIDER', appRole: 'PROVIDER' }),
  });
  const city = await tx.city.create({ data: { nameAr: `Phase 0 ${scope}`, countryCode: 'YE' } });
  const category = await tx.providerCategory.create({ data: { nameAr: `Phase 0 ${scope}`, slug: scope } });
  const provider = await tx.provider.create({
    data: {
      userId: providerUser.id, cityId: city.id, primaryCategoryId: category.id,
      businessName: `Phase 0 ${scope}`, phone: fixturePhone(scope, 'provider-business'), status: 'ACTIVE',
    },
  });
  const service = await tx.providerService.create({
    data: { providerId: provider.id, categoryId: category.id, cityId: city.id, title: `Phase 0 ${scope}`, basePrice: 100 },
  });
  const plan = await tx.weddingPlan.create({ data: { ownerUserId: owner.id, title: `Phase 0 ${scope}` } });
  const conversation = await tx.conversation.create({
    data: { scope: 'PLAN', weddingPlanId: plan.id, providerId: provider.id, createdByUserId: owner.id },
  });
  const quoteRequest = await tx.quoteRequest.create({
    data: {
      userId: owner.id, weddingPlanId: plan.id, providerId: provider.id, serviceId: service.id,
      cityId: city.id, conversationId: conversation.id, status: 'RESPONDED',
    },
  });
  const offer = await tx.quoteOffer.create({
    data: { quoteRequestId: quoteRequest.id, providerId: provider.id, title: `Phase 0 ${scope}`, amount: 100, status: 'PENDING' },
  });
  return { scope, owner, providerUser, city, category, provider, service, plan, conversation, quoteRequest, offer };
}

async function cleanupQuoteFixtureGraph(prisma, fixture) {
  return inTransaction(prisma, async (tx) => {
    const userIds = [fixture.owner.id, fixture.providerUser.id, fixture.member?.id].filter(Boolean);
    const costs = await tx.weddingCost.findMany({
      where: { weddingPlanId: fixture.plan.id },
      select: { id: true },
    });
    const costIds = costs.map((cost) => cost.id);
    const messages = await tx.chatMessage.findMany({
      where: { conversationId: fixture.conversation.id },
      select: { id: true },
    });
    const messageIds = messages.map((message) => message.id);
    const events = await tx.conversationEvent.findMany({
      where: { conversationId: fixture.conversation.id },
      select: { id: true },
    });
    const notifications = await tx.notification.findMany({
      where: { userId: { in: userIds } },
      select: { id: true },
    });
    const notificationIds = notifications.map((notification) => notification.id);
    const aggregateIds = [
      fixture.plan.id, fixture.provider.id, fixture.conversation.id,
      fixture.quoteRequest.id, fixture.offer.id, ...costIds, ...messageIds,
      ...events.map((event) => event.id), ...notificationIds,
    ];

    await tx.chatAttachment.deleteMany({ where: { messageId: { in: messageIds } } });
    await tx.chatMessage.deleteMany({ where: { conversationId: fixture.conversation.id } });
    await tx.conversationReport.deleteMany({ where: { conversationId: fixture.conversation.id } });
    await tx.conversationEvent.deleteMany({ where: { conversationId: fixture.conversation.id } });
    await tx.outboxEvent.deleteMany({
      where: {
        OR: [
          { aggregateId: { in: aggregateIds } },
          { aggregateType: 'notification', aggregateId: { in: notificationIds } },
        ],
      },
    });
    await tx.notification.deleteMany({ where: { userId: { in: userIds } } });
    await tx.planProviderLink.deleteMany({
      where: { weddingPlanId: fixture.plan.id, providerId: fixture.provider.id },
    });
    await tx.$executeRaw`
      SELECT set_config('aarast.allow_ledger_purge', 'on', true)
    `;
    await tx.costPayment.deleteMany({ where: { weddingCostId: { in: costIds } } });
    await tx.paymentSchedule.deleteMany({ where: { weddingCostId: { in: costIds } } });
    await tx.weddingCost.deleteMany({ where: { id: { in: costIds } } });
    await tx.quoteOffer.deleteMany({ where: { quoteRequestId: fixture.quoteRequest.id } });
    await tx.quoteRequest.deleteMany({ where: { id: fixture.quoteRequest.id } });
    await tx.conversationParticipant.deleteMany({ where: { conversationId: fixture.conversation.id } });
    await tx.conversation.deleteMany({ where: { id: fixture.conversation.id } });
    await tx.sharedMember.deleteMany({ where: { weddingPlanId: fixture.plan.id } });
    await tx.budgetCategory.deleteMany({ where: { weddingPlanId: fixture.plan.id } });
    await tx.weddingPlan.deleteMany({ where: { id: fixture.plan.id } });
    await tx.providerService.deleteMany({ where: { id: fixture.service.id } });
    await tx.provider.deleteMany({ where: { id: fixture.provider.id } });
    await tx.providerCategory.deleteMany({ where: { id: fixture.category.id } });
    await tx.city.deleteMany({ where: { id: fixture.city.id } });
    await cleanupUsers(tx, userIds);
  });
}

async function withFixture(createFixture, callback, environment = process.env) {
  assertManagedSmokeEnvironment(environment);
  let fixture;
  try {
    fixture = await createFixture(environment);
    return await callback(fixture);
  } finally {
    if (fixture?.cleanup) await fixture.cleanup();
  }
}

async function runConcurrentlyAfterBarrier(operations, { onAllArrived } = {}) {
  if (!Array.isArray(operations) || operations.length < 2 || operations.some((item) => typeof item !== 'function')) {
    throw new Error('Provide at least two concurrent fixture operations.');
  }
  let arrived = 0;
  let release;
  const barrier = new Promise((resolve) => { release = resolve; });
  const results = await Promise.allSettled(operations.map(async (operation) => {
    arrived += 1;
    if (arrived === operations.length) {
      onAllArrived?.({ arrived, total: operations.length });
      release();
    }
    await barrier;
    return operation();
  }));
  const failures = results.filter((result) => result.status === 'rejected').map((result) => result.reason);
  if (failures.length === 1) throw failures[0];
  if (failures.length > 1) throw new AggregateError(failures, 'Multiple concurrent fixture operations failed.');
  return results.map((result) => result.value);
}

module.exports = {
  cleanupQuoteFixtureGraph,
  cleanupUsers,
  createOtpAttemptFixture,
  createPermissionRevocationFixture,
  createQuoteDecisionFixture,
  createSuperAdminPairFixture,
  fixtureScope,
  runConcurrentlyAfterBarrier,
  withFixture,
};
