'use strict';

const { createHash } = require('crypto');
const {
  assertManagedSmokeEnvironment,
} = require('../../scripts/smoke/smoke-utils');

function fixtureScope(label, environment = process.env) {
  if (!/^[a-z][a-z0-9-]{2,32}$/.test(label)) {
    throw new Error('Phase 0 fixture label must be a short lowercase identifier.');
  }
  const { runId } = assertManagedSmokeEnvironment(environment);
  return `phase0-${runId}-${label}`;
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

async function cleanupUsers(prisma, userIds) {
  await prisma.adminLoginChallenge.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.refreshToken.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.user.deleteMany({ where: { id: { in: userIds } } });
}

async function createSuperAdminPairFixture(prisma, environment = process.env) {
  const scope = fixtureScope('super-admins', environment);
  const [actingAdmin, peerAdmin] = await Promise.all([
    prisma.user.create({ data: userData(scope, 'acting-admin', { role: 'ADMIN', adminRole: 'SUPER_ADMIN' }) }),
    prisma.user.create({ data: userData(scope, 'peer-admin', { role: 'ADMIN', adminRole: 'SUPER_ADMIN' }) }),
  ]);
  return {
    scope,
    actingAdmin,
    peerAdmin,
    cleanup: () => cleanupUsers(prisma, [actingAdmin.id, peerAdmin.id]),
  };
}

async function createOtpAttemptFixture(prisma, environment = process.env) {
  const scope = fixtureScope('otp-ceiling', environment);
  const user = await prisma.user.create({ data: userData(scope, 'otp-user') });
  const otp = await prisma.otpCode.create({
    data: {
      phone: user.phone,
      codeHash: 'phase0-test-otp-hash',
      purpose: 'LOGIN',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      maxAttempts: 5,
    },
  });
  return {
    scope,
    user,
    otp,
    cleanup: async () => {
      await prisma.otpCode.deleteMany({ where: { id: otp.id } });
      await cleanupUsers(prisma, [user.id]);
    },
  };
}

async function createQuoteDecisionFixture(prisma, environment = process.env) {
  const scope = fixtureScope('quote-decision', environment);
  const owner = await prisma.user.create({ data: userData(scope, 'plan-owner') });
  const providerUser = await prisma.user.create({
    data: userData(scope, 'provider-user', { role: 'PROVIDER', appRole: 'PROVIDER' }),
  });
  const city = await prisma.city.create({ data: { nameAr: `Phase 0 ${scope}`, countryCode: 'YE' } });
  const category = await prisma.providerCategory.create({
    data: { nameAr: `Phase 0 ${scope}`, slug: scope },
  });
  const provider = await prisma.provider.create({
    data: {
      userId: providerUser.id,
      cityId: city.id,
      primaryCategoryId: category.id,
      businessName: `Phase 0 ${scope}`,
      phone: fixturePhone(scope, 'provider-business'),
      status: 'ACTIVE',
    },
  });
  const service = await prisma.providerService.create({
    data: {
      providerId: provider.id,
      categoryId: category.id,
      cityId: city.id,
      title: `Phase 0 ${scope}`,
      basePrice: 100,
    },
  });
  const plan = await prisma.weddingPlan.create({
    data: { ownerUserId: owner.id, title: `Phase 0 ${scope}` },
  });
  const conversation = await prisma.conversation.create({
    data: {
      scope: 'PLAN',
      weddingPlanId: plan.id,
      providerId: provider.id,
      createdByUserId: owner.id,
    },
  });
  const quoteRequest = await prisma.quoteRequest.create({
    data: {
      userId: owner.id,
      weddingPlanId: plan.id,
      providerId: provider.id,
      serviceId: service.id,
      cityId: city.id,
      conversationId: conversation.id,
      status: 'RESPONDED',
    },
  });
  const offer = await prisma.quoteOffer.create({
    data: {
      quoteRequestId: quoteRequest.id,
      providerId: provider.id,
      title: `Phase 0 ${scope}`,
      amount: 100,
      status: 'PENDING',
    },
  });
  return {
    scope,
    owner,
    providerUser,
    city,
    category,
    provider,
    service,
    plan,
    conversation,
    quoteRequest,
    offer,
    cleanup: async () => {
      await prisma.quoteOffer.deleteMany({ where: { id: offer.id } });
      await prisma.quoteRequest.deleteMany({ where: { id: quoteRequest.id } });
      await prisma.conversationParticipant.deleteMany({ where: { conversationId: conversation.id } });
      await prisma.conversation.deleteMany({ where: { id: conversation.id } });
      await prisma.weddingPlan.deleteMany({ where: { id: plan.id } });
      await prisma.providerService.deleteMany({ where: { id: service.id } });
      await prisma.provider.deleteMany({ where: { id: provider.id } });
      await prisma.providerCategory.deleteMany({ where: { id: category.id } });
      await prisma.city.deleteMany({ where: { id: city.id } });
      await cleanupUsers(prisma, [owner.id, providerUser.id]);
    },
  };
}

async function createPermissionRevocationFixture(prisma, environment = process.env) {
  const quote = await createQuoteDecisionFixture(prisma, environment);
  const member = await prisma.user.create({ data: userData(quote.scope, 'provider-member') });
  const sharedMember = await prisma.sharedMember.create({
    data: {
      weddingPlanId: quote.plan.id,
      userId: member.id,
      role: 'MANAGER',
      canManageProviders: true,
    },
  });
  const participant = await prisma.conversationParticipant.create({
    data: { conversationId: quote.conversation.id, userId: member.id },
  });
  return {
    ...quote,
    member,
    sharedMember,
    participant,
    cleanup: async () => {
      await prisma.conversationParticipant.deleteMany({ where: { id: participant.id } });
      await prisma.sharedMember.deleteMany({ where: { id: sharedMember.id } });
      await cleanupUsers(prisma, [member.id]);
      await quote.cleanup();
    },
  };
}

async function runConcurrentlyAfterBarrier(operations) {
  if (!Array.isArray(operations) || operations.length < 2 || operations.some((item) => typeof item !== 'function')) {
    throw new Error('Provide at least two concurrent fixture operations.');
  }
  let arrived = 0;
  let release;
  const barrier = new Promise((resolve) => { release = resolve; });
  return Promise.all(operations.map(async (operation) => {
    arrived += 1;
    if (arrived === operations.length) release();
    await barrier;
    return operation();
  }));
}

module.exports = {
  createOtpAttemptFixture,
  createPermissionRevocationFixture,
  createQuoteDecisionFixture,
  createSuperAdminPairFixture,
  fixtureScope,
  runConcurrentlyAfterBarrier,
};
