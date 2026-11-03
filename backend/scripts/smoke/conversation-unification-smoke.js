#!/usr/bin/env node
'use strict';

const crypto = require('crypto');
const http = require('http');
const path = require('path');
const { PrismaClient, ProviderStatus } = require('@prisma/client');
const { configureSmokeDatabaseUrl } = require('./smoke-utils');
const { registerVerified } = require('./verified-registration');

const socketIoRoot = path.resolve(path.dirname(require.resolve('socket.io')), '..');
const { io } = require(path.join(socketIoRoot, 'client-dist', 'socket.io.js'));

configureSmokeDatabaseUrl();

const prisma = new PrismaClient();
const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const suffix = `${Date.now().toString().slice(-6)}${Math.floor(Math.random() * 9)}`;
const marker = `conversation-unification-${suffix}`;
const password = 'SmokeTest123!';
const phones = [`+96770${suffix}`, `+96771${suffix}`, `+96772${suffix}`, `+96773${suffix}`];
const fixture = {
  userIds: [],
  planIds: [],
  providerIds: [],
  serviceIds: [],
  quoteIds: [],
  offerIds: [],
  conversationIds: [],
  costIds: [],
  memberIds: [],
  cityId: null,
  categoryId: null,
};

let passed = 0;
let failed = 0;

function check(label, condition, detail) {
  if (condition) {
    console.log(`PASS - ${label}`);
    passed += 1;
    return;
  }
  failed += 1;
  const suffixText = detail ? ` (${detail})` : '';
  throw new Error(`${label}${suffixText}`);
}

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === null || body === undefined ? undefined : JSON.stringify(body);
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    if (payload) headers['Content-Length'] = Buffer.byteLength(payload);
    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers,
        timeout: 15_000,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, body: data ? JSON.parse(data) : null });
          } catch {
            resolve({ status: res.statusCode, body: data });
          }
        });
      },
    );
    req.on('timeout', () => req.destroy(new Error(`${method} ${path} timed out`)));
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function responseCode(response) {
  return typeof response.body === 'object' && response.body
    ? response.body.code ?? response.body.error ?? response.body.message
    : response.body;
}

async function expectStatus(label, response, status) {
  check(label, response.status === status, `HTTP ${response.status}; ${responseCode(response)}`);
  return response.body;
}

async function register(name, phone) {
  const response = await registerVerified(request, { name, phone, password });
  const body = await expectStatus(`${name} registration`, response, 201);
  check(`${name} returns access token`, typeof body?.accessToken === 'string');
  check(`${name} returns user id`, typeof body?.user?.id === 'string');
  fixture.userIds.push(body.user.id);
  return { token: body.accessToken, user: body.user };
}

function futureIso(days) {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
}

class SocketIoProbe {
  constructor(token) {
    this.token = token;
    this.socket = null;
    this.events = [];
    this.waiters = [];
  }

  async connect() {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.close();
        reject(new Error('Socket.IO connection timed out'));
      }, 10_000);
      this.socket = io(`${BASE_URL}/chat`, {
        auth: { token: this.token },
        transports: ['websocket'],
        reconnection: false,
        timeout: 10_000,
      });
      this.socket.on('connect_error', (error) => {
        clearTimeout(timer);
        this.close();
        reject(error);
      });
      this.socket.on('disconnect', () => {
        for (const waiter of this.waiters.splice(0)) {
          clearTimeout(waiter.timer);
          waiter.reject(new Error('Socket closed before expected event'));
        }
      });
      this.socket.onAny((name, payload) => {
        this.events.push({ name, payload });
        if (name === 'chat:ready') {
          clearTimeout(timer);
          resolve();
        }
        for (const waiter of [...this.waiters]) {
          if (waiter.name === name && waiter.predicate(payload)) {
            clearTimeout(waiter.timer);
            this.waiters.splice(this.waiters.indexOf(waiter), 1);
            waiter.resolve(payload);
          }
        }
      });
    });
  }

  emitWithAck(name, payload) {
    return new Promise((resolve, reject) => {
      this.socket.timeout(10_000).emit(name, payload, (error, response) => {
        if (error) reject(new Error(`${name} acknowledgement timed out`));
        else resolve(response);
      });
    });
  }

  waitFor(name, predicate = () => true) {
    const existing = this.events.find((event) => event.name === name && predicate(event.payload));
    if (existing) return Promise.resolve(existing.payload);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const index = this.waiters.findIndex((waiter) => waiter.resolve === resolve);
        if (index >= 0) this.waiters.splice(index, 1);
        reject(new Error(`${name} event timed out`));
      }, 10_000);
      this.waiters.push({ name, predicate, resolve, reject, timer });
    });
  }

  close() {
    this.socket?.disconnect();
  }
}

async function counts() {
  const [
    users,
    plans,
    providers,
    services,
    conversations,
    participants,
    events,
    messages,
    quotes,
    offers,
    links,
    costs,
    notifications,
    outbox,
  ] = await Promise.all([
    prisma.user.count(),
    prisma.weddingPlan.count(),
    prisma.provider.count(),
    prisma.providerService.count(),
    prisma.conversation.count(),
    prisma.conversationParticipant.count(),
    prisma.conversationEvent.count(),
    prisma.chatMessage.count(),
    prisma.quoteRequest.count(),
    prisma.quoteOffer.count(),
    prisma.planProviderLink.count(),
    prisma.weddingCost.count(),
    prisma.notification.count(),
    prisma.outboxEvent.count(),
  ]);
  return { users, plans, providers, services, conversations, participants, events, messages, quotes, offers, links, costs, notifications, outbox };
}

function otpSubjectHash(scope, subject) {
  const pepper = process.env.AUTH_LOGIN_THROTTLE_PEPPER?.trim()
    || 'aarast-local-login-throttle-pepper-v1';
  return crypto.createHmac('sha256', pepper)
    .update(`otp-dispatch-v1:${scope}:${subject}`, 'utf8')
    .digest('hex');
}

async function cleanupFixture() {
  const userIds = [...new Set(fixture.userIds)];
  const planIds = [...new Set(fixture.planIds)];
  const providerIds = [...new Set(fixture.providerIds)];
  const quoteIds = [...new Set(fixture.quoteIds)];
  const conversationIds = [...new Set(fixture.conversationIds)];

  const [notificationRows, messageRows, offerRows, costRows, linkRows] = await Promise.all([
    userIds.length || planIds.length
      ? prisma.notification.findMany({
          where: { OR: [{ userId: { in: userIds } }, { weddingPlanId: { in: planIds } }] },
          select: { id: true },
        })
      : [],
    conversationIds.length
      ? prisma.chatMessage.findMany({ where: { conversationId: { in: conversationIds } }, select: { id: true } })
      : [],
    quoteIds.length
      ? prisma.quoteOffer.findMany({ where: { quoteRequestId: { in: quoteIds } }, select: { id: true } })
      : [],
    planIds.length
      ? prisma.weddingCost.findMany({ where: { weddingPlanId: { in: planIds } }, select: { id: true } })
      : [],
    planIds.length || providerIds.length
      ? prisma.planProviderLink.findMany({
          where: { OR: [{ weddingPlanId: { in: planIds } }, { providerId: { in: providerIds } }] },
          select: { id: true },
        })
      : [],
  ]);
  const aggregateIds = [...new Set([
    ...userIds,
    ...planIds,
    ...providerIds,
    ...quoteIds,
    ...conversationIds,
    ...notificationRows.map((row) => row.id),
    ...messageRows.map((row) => row.id),
    ...offerRows.map((row) => row.id),
    ...costRows.map((row) => row.id),
    ...linkRows.map((row) => row.id),
  ])];

  await prisma.$transaction(async (tx) => {
    const tenureEndedAt = new Date();
    if (planIds.length) {
      await tx.contributorTenure.updateMany({
        where: {
          endedAt: null,
          historyScope: { weddingPlanId: { in: planIds } },
        },
        data: {
          endedAt: tenureEndedAt,
          endReason: 'PLAN_DELETED',
          sharedMemberId: null,
        },
      });
      await tx.contributorHistoryScope.updateMany({
        where: { weddingPlanId: { in: planIds } },
        data: {
          status: 'DELETED',
          deletedAt: tenureEndedAt,
        },
      });
    }
    if (aggregateIds.length) await tx.outboxEvent.deleteMany({ where: { aggregateId: { in: aggregateIds } } });
    if (userIds.length || planIds.length) {
      await tx.notification.deleteMany({
        where: { OR: [{ userId: { in: userIds } }, { weddingPlanId: { in: planIds } }] },
      });
    }
    if (userIds.length) await tx.idempotencyKey.deleteMany({ where: { userId: { in: userIds } } });
    if (planIds.length) {
      const costIds = (await tx.weddingCost.findMany({
        where: { weddingPlanId: { in: planIds } }, select: { id: true },
      })).map((row) => row.id);
      if (costIds.length) {
        await tx.costPayment.deleteMany({ where: { weddingCostId: { in: costIds } } });
        await tx.paymentSchedule.deleteMany({ where: { weddingCostId: { in: costIds } } });
      }
      await tx.weddingCost.deleteMany({ where: { weddingPlanId: { in: planIds } } });
      await tx.planProviderLink.deleteMany({ where: { weddingPlanId: { in: planIds } } });
    }
    if (quoteIds.length) await tx.quoteRequest.deleteMany({ where: { id: { in: quoteIds } } });
    if (conversationIds.length) await tx.conversation.deleteMany({ where: { id: { in: conversationIds } } });
    if (planIds.length) {
      await tx.sharedMember.deleteMany({ where: { weddingPlanId: { in: planIds } } });
      await tx.planInvite.deleteMany({ where: { weddingPlanId: { in: planIds } } });
      await tx.guest.deleteMany({ where: { weddingPlanId: { in: planIds } } });
      await tx.guestGroup.deleteMany({ where: { weddingPlanId: { in: planIds } } });
      await tx.weddingTask.deleteMany({ where: { weddingPlanId: { in: planIds } } });
      await tx.budgetCategory.deleteMany({ where: { weddingPlanId: { in: planIds } } });
      await tx.weddingPlan.deleteMany({ where: { id: { in: planIds } } });
    }
    if (providerIds.length) {
      await tx.providerService.deleteMany({ where: { providerId: { in: providerIds } } });
      await tx.provider.deleteMany({ where: { id: { in: providerIds } } });
    }
    if (userIds.length) {
      await tx.mediaUploadTicket.deleteMany({ where: { userId: { in: userIds } } });
      await tx.user.deleteMany({ where: { id: { in: userIds } } });
    }
    await tx.otpCode.deleteMany({ where: { phone: { in: phones } } });
    const phoneScopes = ['PHONE_COOLDOWN', 'PHONE_HOUR', 'PHONE_DAY'];
    await tx.otpDispatchQuota.deleteMany({
      where: {
        OR: phones.flatMap((phone) => phoneScopes.map((scope) => ({
          scope,
          subjectHash: otpSubjectHash(scope, phone),
        }))),
      },
    });
    if (fixture.categoryId) await tx.providerCategory.deleteMany({ where: { id: fixture.categoryId } });
    if (fixture.cityId) await tx.city.deleteMany({ where: { id: fixture.cityId } });
  });
}

async function run() {
  console.log('\nConversation Unification Live Smoke');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Fixture marker: ${marker}`);
  const before = await counts();

  const health = await request('GET', '/ready');
  await expectStatus('Backend readiness', health, 200);

  const city = await prisma.city.create({
    data: { nameAr: marker, nameEn: marker, countryCode: 'YE', isActive: true, sortOrder: 999 },
  });
  const category = await prisma.providerCategory.create({
    data: { nameAr: marker, nameEn: marker, slug: marker, icon: 'chat', isActive: true, sortOrder: 999 },
  });
  fixture.cityId = city.id;
  fixture.categoryId = category.id;

  const owner = await register('Conversation Smoke Owner', phones[0]);
  const providerUser = await register('Conversation Smoke Provider', phones[1]);
  const member = await register('Conversation Smoke Member', phones[2]);
  const lateProviderUser = await register('Conversation Smoke Late Provider', phones[3]);

  const onboarding = await request('POST', '/api/v1/onboarding/complete', {
    path: 'USER',
    persona: 'GROOM',
    location: { governorate: 'Sanaa', city: 'Sanaa' },
    weddingDate: futureIso(120),
    priorities: ['providers'],
    estimatedBudget: '1500000',
    currency: 'YER',
    selectedCategories: ['Venue'],
  }, owner.token);
  const onboardingBody = await expectStatus('Create primary wedding plan', onboarding, 201);
  const planOneId = onboardingBody?.activeWeddingPlan?.id;
  check('Primary plan id exists', typeof planOneId === 'string');
  fixture.planIds.push(planOneId);

  const planTwo = await request('POST', '/api/v1/wedding-plans', {
    title: `Second ${marker}`,
    city: 'Sanaa',
    estimatedBudget: '900000',
    currency: 'YER',
  }, owner.token);
  const planTwoBody = await expectStatus('Create second wedding plan', planTwo, 201);
  check('Second plan id exists', typeof planTwoBody?.id === 'string');
  fixture.planIds.push(planTwoBody.id);

  const providerApply = await request('POST', '/api/v1/provider/apply', {
    businessName: `Provider ${marker}`,
    phone: phones[1],
    cityId: city.id,
    categoryIds: [category.id],
    description: 'Isolated conversation unification smoke provider.',
    services: [{ title: `Service ${marker}`, basePrice: '100000' }],
  }, providerUser.token);
  const providerBody = await expectStatus('Create provider profile', providerApply, 201);
  const providerId = providerBody?.id;
  check('Provider id exists', typeof providerId === 'string');
  fixture.providerIds.push(providerId);

  const pendingService = await request(
    'POST',
    '/api/v1/provider/me/services',
    {
      categoryId: category.id,
      title: `Pending service ${marker}`,
      basePrice: '200000',
      priceUnit: 'event',
      cityId: city.id,
    },
    providerUser.token,
  );
  // B-10 (D48, D49): he joined with one priced service; while it is active,
  // a second one waits for approval.
  check(
    'PENDING provider cannot create a second conversation service',
    pendingService.status === 403 &&
      responseCode(pendingService) === 'PROVIDER_JOINING_SERVICE_ONLY',
  );
  const pendingServices = await prisma.providerService.findMany({
    where: { providerId },
    select: { title: true },
  });
  check(
    'PENDING provider service denial writes nothing',
    pendingServices.length === 1 && pendingServices[0].title === `Service ${marker}`,
  );

  await prisma.provider.update({ where: { id: providerId }, data: { status: ProviderStatus.ACTIVE } });

  const serviceResponses = await Promise.all([1, 2].map((number) => request(
    'POST',
    '/api/v1/provider/me/services',
    {
      categoryId: category.id,
      title: `Service ${number} ${marker}`,
      basePrice: String(200000 + number * 50000),
      priceUnit: 'event',
      cityId: city.id,
    },
    providerUser.token,
  )));
  for (const [index, response] of serviceResponses.entries()) {
    const body = await expectStatus(`Create provider service ${index + 1}`, response, 201);
    check(`Provider service ${index + 1} id exists`, typeof body?.id === 'string');
    fixture.serviceIds.push(body.id);
  }

  const memberCreate = await request('POST', `/api/v1/wedding-plans/${planOneId}/members`, {
    userId: member.user.id,
    // D52 (J2-05): «يشوف بس» manages no providers; a helper may.
    role: 'HELPER',
    canManageProviders: true,
  }, owner.token);
  const memberBody = await expectStatus('Grant member canManageProviders', memberCreate, 201);
  check('Shared member id exists', typeof memberBody?.id === 'string');
  fixture.memberIds.push(memberBody.id);

  const quoteResponses = await Promise.all(fixture.serviceIds.map((serviceId, index) => request(
    'POST',
    `/api/v1/wedding-plans/${planOneId}/quote-requests`,
    {
      providerId,
      serviceId,
      cityId: city.id,
      guestCount: 100 + index,
      message: `Concurrent plan request ${index + 1} ${marker}`,
      budgetMin: String(180000 + index * 10000),
      budgetMax: String(350000 + index * 10000),
    },
    owner.token,
  )));
  for (const [index, response] of quoteResponses.entries()) {
    const body = await expectStatus(`Create concurrent plan quote ${index + 1}`, response, 201);
    check(`Plan quote ${index + 1} id exists`, typeof body?.id === 'string');
    fixture.quoteIds.push(body.id);
  }

  const conversationResponses = await Promise.all(fixture.quoteIds.slice(0, 2).map((quoteId) => request(
    'GET', `/api/v1/quote-requests/${quoteId}/conversation`, null, owner.token,
  )));
  const conversationBodies = [];
  for (const [index, response] of conversationResponses.entries()) {
    conversationBodies.push(await expectStatus(`Read plan conversation ${index + 1}`, response, 200));
  }
  const planConversationId = conversationBodies[0]?.id;
  check('Both plan requests reuse one conversation', planConversationId === conversationBodies[1]?.id);
  check('Plan conversation scope is PLAN', conversationBodies[0]?.scope === 'PLAN');
  check('Plan conversation exposes two requests', conversationBodies[0]?.quoteRequestCount === 2);
  fixture.conversationIds.push(planConversationId);
  const planConversationCount = await prisma.conversation.count({ where: { weddingPlanId: planOneId, providerId } });
  check('Database has one PLAN conversation for plan and provider', planConversationCount === 1);

  const inbox = await request('GET', '/api/v1/conversations?limit=50', null, owner.token);
  const inboxBody = await expectStatus('Read owner conversation inbox', inbox, 200);
  check('Inbox contains one row for reused conversation', inboxBody.items.filter((item) => item.id === planConversationId).length === 1);
  const requestList = await request('GET', `/api/v1/conversations/${planConversationId}/quote-requests`, null, owner.token);
  const requestListBody = await expectStatus('Read conversation quote requests', requestList, 200);
  check('Conversation quote request list has two entries', requestListBody.items.length === 2);

  const privateOwnerMessage = `Owner message ${marker}`;
  const ownerMessage = await request('POST', `/api/v1/conversations/${planConversationId}/messages`, {
    body: privateOwnerMessage,
  }, owner.token);
  const ownerMessageBody = await expectStatus('Owner sends conversation message', ownerMessage, 201);
  check('Owner message is persisted', typeof ownerMessageBody?.id === 'string');

  const providerChatNotification = await prisma.notification.findFirst({
    where: {
      userId: providerUser.user.id,
      type: 'CHAT_MESSAGE_RECEIVED',
      entityType: 'conversation',
      entityId: planConversationId,
      data: {
        path: ['messageId'],
        equals: ownerMessageBody.id,
      },
    },
    orderBy: { createdAt: 'desc' },
  });
  check(
    'Owner message creates a durable provider CHAT notification',
    typeof providerChatNotification?.id === 'string',
  );

  const activeProviderNotifications = await request(
    'GET',
    '/api/v1/notifications?limit=50',
    null,
    providerUser.token,
  );
  const activeProviderNotificationsBody = await expectStatus(
    'ACTIVE provider reads notification inbox',
    activeProviderNotifications,
    200,
  );
  const activeProviderChatNotification = activeProviderNotificationsBody?.items?.find(
    (notification) => notification.id === providerChatNotification.id,
  );
  check(
    'ACTIVE provider inbox includes the real CHAT notification',
    typeof activeProviderChatNotification?.id === 'string',
  );
  check(
    'Provider CHAT notification declares PROVIDER recipient audience',
    activeProviderChatNotification?.data?.recipientAudience === 'PROVIDER',
  );
  const providerChatNotificationPayload = JSON.stringify({
    title: activeProviderChatNotification?.title,
    body: activeProviderChatNotification?.body,
    data: activeProviderChatNotification?.data,
  });
  check(
    'Provider CHAT notification omits customer name, phone, and message body',
    ![
      owner.user.name,
      owner.user.phone,
      privateOwnerMessage,
    ].some(
      (privateValue) =>
        typeof privateValue === 'string' &&
        privateValue.length > 0 &&
        providerChatNotificationPayload.includes(privateValue),
    ),
  );

  const providerConversation = await request('GET', `/api/v1/conversations/${planConversationId}`, null, providerUser.token);
  const providerConversationBody = await expectStatus('Provider reads PLAN conversation', providerConversation, 200);
  check('Provider joined state is true', providerConversationBody?.providerJoined === true);

  const offer = await request('POST', `/api/v1/provider/me/quote-requests/${fixture.quoteIds[0]}/offers`, {
    title: `Offer ${marker}`,
    message: `Offer body ${marker}`,
    amount: '325000',
    currency: 'YER',
    validUntil: futureIso(30),
  }, providerUser.token);
  const offerBody = await expectStatus('Provider creates quote offer', offer, 201);
  check('Quote offer id exists', typeof offerBody?.id === 'string');
  fixture.offerIds.push(offerBody.id);

  const memberTimeline = await request('GET', `/api/v1/conversations/${planConversationId}/timeline?limit=50`, null, member.token);
  const memberTimelineBody = await expectStatus('Authorized member reads complete timeline', memberTimeline, 200);
  check('Member sees prior owner message', memberTimelineBody.items.some((item) => item.kind === 'MESSAGE' && item.message?.id === ownerMessageBody.id));
  check('Timeline contains offer-received system event', memberTimelineBody.items.some((item) => item.kind === 'EVENT' && item.event?.type === 'QUOTE_OFFER_RECEIVED'));

  const mute = await request('PATCH', `/api/v1/conversations/${planConversationId}/mute`, { enabled: true }, member.token);
  await expectStatus('Member mutes only their conversation membership', mute, 200);
  const participantStates = await prisma.conversationParticipant.findMany({
    where: { conversationId: planConversationId, userId: { in: [owner.user.id, member.user.id] } },
    select: { userId: true, mutedAt: true },
  });
  check('Member mute is personal', participantStates.find((item) => item.userId === member.user.id)?.mutedAt instanceof Date
    && participantStates.find((item) => item.userId === owner.user.id)?.mutedAt === null);
  await expectStatus('Member unmutes their membership', await request(
    'PATCH', `/api/v1/conversations/${planConversationId}/mute`, { enabled: false }, member.token,
  ), 200);

  const probe = new SocketIoProbe(member.token);
  await probe.connect();
  const joinAck = await probe.emitWithAck('conversation:join', { conversationId: planConversationId });
  check('Member joins conversation Socket.IO room', joinAck?.joined === true);
  const revokedEvent = probe.waitFor(
    'conversation:permission-revoked',
    (payload) => payload?.conversationId === planConversationId,
  );
  const revoke = await request('PATCH', `/api/v1/wedding-plans/${planOneId}/members/${memberBody.id}`, {
    role: 'HELPER',
    canManageProviders: false,
  }, owner.token);
  const revokedMemberBody = await expectStatus('Owner revokes canManageProviders', revoke, 200);
  check(
    'Explicit provider revocation overrides HELPER role default',
    revokedMemberBody?.role === 'HELPER' &&
      revokedMemberBody?.canManageProviders === false,
  );
  const revokedPayload = await revokedEvent;
  check('Socket receives immediate permission-revoked event', revokedPayload?.conversationId === planConversationId);
  const revokedRest = await request('GET', `/api/v1/conversations/${planConversationId}`, null, member.token);
  check('Revoked member loses REST access immediately', revokedRest.status === 404, `HTTP ${revokedRest.status}`);
  const revokedProviderMutation = await request(
    'POST',
    `/api/v1/wedding-plans/${planOneId}/quote-requests`,
    {
      providerId,
      serviceId: fixture.serviceIds[0],
      cityId: city.id,
      guestCount: 111,
      message: `Denied helper request ${marker}`,
      budgetMin: '180000',
      budgetMax: '350000',
    },
    member.token,
  );
  check(
    'Revoked HELPER also loses provider-management API authority',
    revokedProviderMutation.status === 404,
    `HTTP ${revokedProviderMutation.status}`,
  );
  const revokedParticipant = await prisma.conversationParticipant.findUnique({
    where: { conversationId_userId: { conversationId: planConversationId, userId: member.user.id } },
    select: { revokedAt: true },
  });
  check('Revoked member participant is marked revoked', revokedParticipant?.revokedAt instanceof Date);
  probe.close();

  await expectStatus('Customer blocks conversation side', await request(
    'PATCH', `/api/v1/conversations/${planConversationId}/block`, { enabled: true }, owner.token,
  ), 200);
  const blockedSend = await request('POST', `/api/v1/conversations/${planConversationId}/messages`, {
    body: `Blocked provider message ${marker}`,
  }, providerUser.token);
  check('Blocked conversation rejects provider message', blockedSend.status === 409, `HTTP ${blockedSend.status}`);
  await expectStatus('Customer unblocks conversation side', await request(
    'PATCH', `/api/v1/conversations/${planConversationId}/block`, { enabled: false }, owner.token,
  ), 200);

  const secondPlanQuote = await request('POST', `/api/v1/wedding-plans/${planTwoBody.id}/quote-requests`, {
    providerId,
    serviceId: fixture.serviceIds[0],
    cityId: city.id,
    message: `Second plan request ${marker}`,
  }, owner.token);
  const secondPlanQuoteBody = await expectStatus('Create quote for second plan', secondPlanQuote, 201);
  fixture.quoteIds.push(secondPlanQuoteBody.id);
  const secondPlanConversation = await request('GET', `/api/v1/quote-requests/${secondPlanQuoteBody.id}/conversation`, null, owner.token);
  const secondPlanConversationBody = await expectStatus('Read second plan conversation', secondPlanConversation, 200);
  check('Second plan gets a different PLAN conversation', secondPlanConversationBody.id !== planConversationId && secondPlanConversationBody.scope === 'PLAN');
  fixture.conversationIds.push(secondPlanConversationBody.id);

  const accountQuote = await request('POST', `/api/v1/providers/${providerId}/quote-requests`, {
    serviceId: fixture.serviceIds[0],
    cityId: city.id,
    message: `Account request ${marker}`,
  }, owner.token);
  const accountQuoteBody = await expectStatus('Create request without wedding plan', accountQuote, 201);
  fixture.quoteIds.push(accountQuoteBody.id);
  const accountConversation = await request('GET', `/api/v1/quote-requests/${accountQuoteBody.id}/conversation`, null, owner.token);
  const accountConversationBody = await expectStatus('Read ACCOUNT conversation', accountConversation, 200);
  check('Planless request gets distinct ACCOUNT conversation', accountConversationBody.scope === 'ACCOUNT'
    && accountConversationBody.weddingPlan === null
    && accountConversationBody.id !== planConversationId);
  fixture.conversationIds.push(accountConversationBody.id);

  const repeatedAccountQuote = await request('POST', `/api/v1/providers/${providerId}/quote-requests`, {
    serviceId: fixture.serviceIds[1],
    cityId: city.id,
    message: `Second account request ${marker}`,
  }, owner.token);
  const repeatedAccountQuoteBody = await expectStatus('Create second ACCOUNT request for same requester', repeatedAccountQuote, 201);
  fixture.quoteIds.push(repeatedAccountQuoteBody.id);
  const repeatedAccountConversation = await request(
    'GET', `/api/v1/quote-requests/${repeatedAccountQuoteBody.id}/conversation`, null, owner.token,
  );
  const repeatedAccountConversationBody = await expectStatus(
    'Read reused ACCOUNT conversation', repeatedAccountConversation, 200,
  );
  check('Same requester and provider reuse one ACCOUNT conversation', repeatedAccountConversationBody.id === accountConversationBody.id);

  const otherRequesterAccountQuote = await request('POST', `/api/v1/providers/${providerId}/quote-requests`, {
    serviceId: fixture.serviceIds[0],
    cityId: city.id,
    message: `Other requester account request ${marker}`,
  }, member.token);
  const otherRequesterAccountQuoteBody = await expectStatus(
    'Create ACCOUNT request for another requester', otherRequesterAccountQuote, 201,
  );
  fixture.quoteIds.push(otherRequesterAccountQuoteBody.id);
  const otherRequesterAccountConversation = await request(
    'GET', `/api/v1/quote-requests/${otherRequesterAccountQuoteBody.id}/conversation`, null, member.token,
  );
  const otherRequesterAccountConversationBody = await expectStatus(
    'Read other requester ACCOUNT conversation', otherRequesterAccountConversation, 200,
  );
  check('Different requesters get different ACCOUNT conversations',
    otherRequesterAccountConversationBody.id !== accountConversationBody.id
      && otherRequesterAccountConversationBody.scope === 'ACCOUNT');
  fixture.conversationIds.push(otherRequesterAccountConversationBody.id);

  const catalogProvider = await prisma.provider.create({
    data: {
      cityId: city.id,
      primaryCategoryId: category.id,
      businessName: `Catalog ${marker}`,
      phone: `+96774${suffix}`,
      description: 'Catalog provider without a user account.',
      status: ProviderStatus.ACTIVE,
    },
  });
  fixture.providerIds.push(catalogProvider.id);
  const catalogService = await prisma.providerService.create({
    data: {
      providerId: catalogProvider.id,
      categoryId: category.id,
      cityId: city.id,
      title: `Catalog service ${marker}`,
      basePrice: '150000',
      priceUnit: 'event',
      isActive: true,
    },
  });
  fixture.serviceIds.push(catalogService.id);
  const catalogQuoteRequest = () => request('POST', `/api/v1/providers/${catalogProvider.id}/quote-requests`, {
    serviceId: catalogService.id,
    cityId: city.id,
    message: `Catalog request ${marker}`,
  }, owner.token);
  // V1 4.18: a listing nobody claimed takes no quote request.
  const unclaimedQuote = await catalogQuoteRequest();
  check(
    'Unclaimed provider refuses a quote request',
    unclaimedQuote.status === 409 && responseCode(unclaimedQuote) === 'PROVIDER_NOT_CLAIMED',
  );
  check(
    'Unclaimed provider refusal writes nothing',
    await prisma.quoteRequest.count({ where: { providerId: catalogProvider.id } }) === 0
      && await prisma.conversation.count({ where: { providerId: catalogProvider.id } }) === 0,
  );
  // A provider can still lose its User after a request: its owner deletes
  // the account (Provider.user is SetNull). The request is sent while the
  // listing is owned, then the owner link goes the way account deletion
  // takes it, and the account that claims the listing later joins the same
  // conversation.
  await prisma.provider.update({ where: { id: catalogProvider.id }, data: { userId: lateProviderUser.user.id } });
  const catalogQuote = await catalogQuoteRequest();
  const catalogQuoteBody = await expectStatus('Create quote while the provider has a User', catalogQuote, 201);
  fixture.quoteIds.push(catalogQuoteBody.id);
  await prisma.provider.update({ where: { id: catalogProvider.id }, data: { userId: null } });
  const catalogConversation = await request('GET', `/api/v1/quote-requests/${catalogQuoteBody.id}/conversation`, null, owner.token);
  const catalogConversationBody = await expectStatus('Read pre-link catalog conversation', catalogConversation, 200);
  check('Provider without User is not falsely joined', catalogConversationBody.providerJoined === false && catalogConversationBody.canSend === false);
  fixture.conversationIds.push(catalogConversationBody.id);
  const catalogConversationDirect = await expectStatus(
    'Open provider-not-joined conversation directly',
    await request('GET', `/api/v1/conversations/${catalogConversationBody.id}`, null, owner.token),
    200,
  );
  check(
    'Direct conversation keeps read-only provider state',
    catalogConversationDirect.id === catalogConversationBody.id
      && catalogConversationDirect.providerJoined === false
      && catalogConversationDirect.canSend === false,
  );
  const catalogTimeline = await expectStatus(
    'Read provider-not-joined conversation timeline',
    await request('GET', `/api/v1/conversations/${catalogConversationBody.id}/timeline`, null, owner.token),
    200,
  );
  check(
    'Provider-not-joined timeline includes the quote event',
    Array.isArray(catalogTimeline.items)
      && catalogTimeline.items.some((item) => item?.event?.quoteRequestId === catalogQuoteBody.id),
  );
  const catalogConversationQuotes = await expectStatus(
    'Read provider-not-joined conversation quote requests',
    await request('GET', `/api/v1/conversations/${catalogConversationBody.id}/quote-requests`, null, owner.token),
    200,
  );
  check(
    'Provider-not-joined conversation includes its quote request',
    Array.isArray(catalogConversationQuotes.items)
      && catalogConversationQuotes.items.some((item) => item?.id === catalogQuoteBody.id),
  );
  const catalogReadReceipt = await expectStatus(
    'Mark provider-not-joined conversation read',
    await request('PATCH', `/api/v1/conversations/${catalogConversationBody.id}/read`, null, owner.token),
    200,
  );
  check(
    'Provider-not-joined read receipt keeps the resolved conversation id',
    catalogReadReceipt.conversationId === catalogConversationBody.id,
  );
  const catalogProbe = new SocketIoProbe(owner.token);
  await catalogProbe.connect();
  const catalogJoinAck = await catalogProbe.emitWithAck(
    'conversation:join',
    { conversationId: catalogConversationBody.id },
  );
  check('Owner joins provider-not-joined conversation Socket.IO room', catalogJoinAck?.joined === true);
  catalogProbe.close();
  const preLinkSend = await request('POST', `/api/v1/conversations/${catalogConversationBody.id}/messages`, {
    body: `Must not send ${marker}`,
  }, owner.token);
  check('Messaging is blocked until provider has a User', preLinkSend.status === 409 && responseCode(preLinkSend) === 'PROVIDER_NOT_JOINED');
  await prisma.provider.update({ where: { id: catalogProvider.id }, data: { userId: lateProviderUser.user.id } });
  const linkedProviderConversation = await request('GET', `/api/v1/conversations/${catalogConversationBody.id}`, null, lateProviderUser.token);
  const linkedProviderBody = await expectStatus('Newly linked provider reads existing conversation', linkedProviderConversation, 200);
  check('Linking provider does not create a new conversation', linkedProviderBody.id === catalogConversationBody.id && linkedProviderBody.providerJoined === true);
  await expectStatus('Newly linked provider can send after joining', await request(
    'POST', `/api/v1/conversations/${catalogConversationBody.id}/messages`, { body: `Joined ${marker}` }, lateProviderUser.token,
  ), 201);

  const accept = await request('PATCH', `/api/v1/quote-offers/${offerBody.id}/accept`, null, owner.token);
  const acceptBody = await expectStatus('Accept quote offer', accept, 200);
  check('Acceptance reports automatic cost creation', acceptBody?.automaticCostCreated === true);
  check('Acceptance returns weddingCost and costSuggestion.costId', typeof acceptBody?.weddingCost?.id === 'string'
    && acceptBody?.costSuggestion?.costId === acceptBody.weddingCost.id);
  fixture.costIds.push(acceptBody.weddingCost.id);
  const acceptAgain = await request('PATCH', `/api/v1/quote-offers/${offerBody.id}/accept`, null, owner.token);
  const acceptAgainBody = await expectStatus('Repeat offer acceptance idempotently', acceptAgain, 200);
  check('Repeated acceptance returns the existing cost', acceptAgainBody?.weddingCost?.id === acceptBody.weddingCost.id
    && acceptAgainBody?.costSuggestion?.costId === acceptBody.weddingCost.id);

  const evidence = await prisma.$transaction(async (tx) => {
    const quote = await tx.quoteRequest.findUnique({ where: { id: fixture.quoteIds[0] } });
    const acceptedOffer = await tx.quoteOffer.findUnique({ where: { id: offerBody.id } });
    const link = await tx.planProviderLink.findUnique({
      where: { weddingPlanId_providerId: { weddingPlanId: planOneId, providerId } },
    });
    const costs = await tx.weddingCost.findMany({ where: { quoteOfferId: offerBody.id } });
    const conversations = await tx.conversation.findMany({ where: { weddingPlanId: planOneId, providerId } });
    return { quote, acceptedOffer, link, costs, conversations };
  });
  check('Accepted QuoteRequest is persisted', evidence.quote?.status === 'ACCEPTED');
  check('Accepted QuoteOffer is persisted', evidence.acceptedOffer?.status === 'ACCEPTED');
  check('PlanProviderLink is persisted', evidence.link?.quoteOfferId === offerBody.id);
  check('Exactly one WeddingCost is linked to offer', evidence.costs.length === 1);
  check('WeddingCost starts with paidAmount zero', evidence.costs[0]?.paidAmount?.toString() === '0');
  check('Offer acceptance did not duplicate PLAN conversation', evidence.conversations.length === 1 && evidence.conversations[0].id === planConversationId);

  await prisma.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.SUSPENDED },
  });
  const suspendedProviderNotifications = await request(
    'GET',
    '/api/v1/notifications?limit=50',
    null,
    providerUser.token,
  );
  const suspendedProviderNotificationsBody = await expectStatus(
    'SUSPENDED provider reads filtered notification inbox',
    suspendedProviderNotifications,
    200,
  );
  check(
    'SUSPENDED provider inbox hides the provider CHAT notification',
    suspendedProviderNotificationsBody?.items?.every(
      (notification) => notification.id !== providerChatNotification.id,
    ) === true,
  );
  const suspendedProviderDirectNotification = await request(
    'GET',
    `/api/v1/notifications/${providerChatNotification.id}`,
    null,
    providerUser.token,
  );
  check(
    'SUSPENDED provider cannot open the hidden CHAT notification',
    suspendedProviderDirectNotification.status === 403 &&
      responseCode(suspendedProviderDirectNotification) === 'PROVIDER_NOT_ACTIVE',
    `HTTP ${suspendedProviderDirectNotification.status}; ${responseCode(suspendedProviderDirectNotification)}`,
  );

  const liveSummary = {
    primaryPlanId: planOneId,
    primaryProviderId: providerId,
    primaryConversationId: planConversationId,
    primaryQuoteIds: fixture.quoteIds.slice(0, 2),
    acceptedOfferId: offerBody.id,
    weddingCostId: acceptBody.weddingCost.id,
    secondPlanConversationId: secondPlanConversationBody.id,
    accountConversationId: accountConversationBody.id,
    lateLinkedConversationId: catalogConversationBody.id,
  };
  console.log(`EVIDENCE - ${JSON.stringify(liveSummary)}`);

  await cleanupFixture();
  const after = await counts();
  check('Fixture cleanup restores tracked row counts', JSON.stringify(after) === JSON.stringify(before),
    `before=${JSON.stringify(before)} after=${JSON.stringify(after)}`);
  console.log(`CLEANUP - restored counts ${JSON.stringify(after)}`);
}

async function main() {
  let error = null;
  try {
    await run();
  } catch (caught) {
    error = caught;
    console.error(`ERROR - ${caught instanceof Error ? caught.message : String(caught)}`);
    try {
      await cleanupFixture();
      console.log('CLEANUP - isolated fixture cleanup completed after failure');
    } catch (cleanupError) {
      console.error(`CLEANUP ERROR - ${cleanupError instanceof Error ? cleanupError.message : String(cleanupError)}`);
    }
  } finally {
    await prisma.$disconnect();
  }
  console.log(`RESULT - ${passed} passed, ${failed + (error && failed === 0 ? 1 : 0)} failed`);
  if (error || failed > 0) process.exitCode = 1;
}

void main();
