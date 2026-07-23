#!/usr/bin/env node
'use strict';

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');
const { configureSmokeDatabaseUrl } = require('./smoke-utils');

configureSmokeDatabaseUrl();

const { PrismaClient, ProviderStatus } = require('@prisma/client');

const prisma = new PrismaClient();
const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const MANAGED_SMOKE = process.env.AARAST_SMOKE_MANAGED === '1';
const TEST_PASSWORD = 'SmokeTest123!';
const marker = `quote-stability-${Date.now()}`;
const phoneSeed = Number(`${Date.now()}`.slice(-8));

let passed = 0;
let failed = 0;

function phone(offset) {
  return `+9676${String((phoneSeed + offset) % 100000000).padStart(8, '0')}`;
}

function eventDate(days) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  date.setUTCHours(12, 0, 0, 0);
  return date.toISOString();
}

function check(label, condition) {
  if (condition) {
    passed += 1;
    console.log(`PASS - ${label}`);
  } else {
    failed += 1;
    console.log(`FAIL - ${label}`);
  }
}

function errorCode(response) {
  return response.body?.code ?? response.body?.message?.code ?? null;
}

function request(method, path, body, token, requestId) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === undefined || body === null ? null : JSON.stringify(body);
    const headers = { Accept: 'application/json' };
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload);
    }
    if (token) headers.Authorization = `Bearer ${token}`;
    if (requestId) headers['X-Client-Request-Id'] = requestId;

    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers,
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

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function register(name, value) {
  const response = await registerVerified(request, {
    name,
    phone: value,
    password: TEST_PASSWORD,
  });
  check(`${name} registration succeeds`, response.status === 201);
  check(`${name} registration returns a token`, typeof response.body?.accessToken === 'string');
  return {
    token: response.body?.accessToken,
    userId: response.body?.user?.id,
  };
}

async function createPlanQuote({ planId, providerId, serviceId, cityId, token, days, key, message }) {
  return request(
    'POST',
    `/api/v1/wedding-plans/${planId}/quote-requests`,
    {
      providerId,
      serviceId,
      cityId,
      eventDate: eventDate(days),
      guestCount: 120,
      message,
      budgetMin: '200000',
      budgetMax: '400000',
    },
    token,
    key,
  );
}

async function cleanupAccount(label, token) {
  if (!token) return;
  const response = await request('DELETE', '/api/v1/users/me', null, token);
  check(`${label} fixture account is cleaned`, response.status === 200 && response.body?.deleted === true);
}

async function run() {
  console.log('\nQuote Stability Live Smoke');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Fixture marker: ${marker}\n`);

  const accounts = [];
  const evidence = {};

  try {
    const [city, category] = await Promise.all([
      prisma.city.findFirst({ where: { isActive: true }, orderBy: { sortOrder: 'asc' } }),
      prisma.providerCategory.findFirst({ where: { isActive: true }, orderBy: { sortOrder: 'asc' } }),
    ]);
    if (!city || !category) throw new Error('An active city and provider category are required');

    const providerAccount = await register(`${marker}-provider`, phone(11));
    const requester = await register(`${marker}-requester`, phone(12));
    accounts.push(['requester', requester.token], ['provider', providerAccount.token]);
    if (!providerAccount.token || !providerAccount.userId || !requester.token || !requester.userId) {
      throw new Error('Fixture account registration failed');
    }

    const providerResponse = await request(
      'POST',
      '/api/v1/provider/apply',
      {
        businessName: `${marker}-business`,
        phone: phone(11),
        cityId: city.id,
        categoryIds: [category.id],
        description: marker,
      },
      providerAccount.token,
    );
    check('isolated provider is created', providerResponse.status === 201 && typeof providerResponse.body?.id === 'string');
    const providerId = providerResponse.body?.id;
    if (!providerId) throw new Error('Provider setup failed');

    const serviceResponse = await request(
      'POST',
      '/api/v1/provider/me/services',
      {
        categoryId: category.id,
        cityId: city.id,
        title: `${marker}-service`,
        description: marker,
        basePrice: '250000',
        priceUnit: 'event',
      },
      providerAccount.token,
    );
    check('isolated provider service is created', serviceResponse.status === 201 && typeof serviceResponse.body?.id === 'string');
    const serviceId = serviceResponse.body?.id;
    if (!serviceId) throw new Error('Provider service setup failed');

    await prisma.provider.update({ where: { id: providerId }, data: { status: ProviderStatus.ACTIVE } });

    const planResponse = await request(
      'POST',
      '/api/v1/wedding-plans',
      { title: `${marker}-plan`, city: city.nameEn ?? city.nameAr, estimatedBudget: '1000000' },
      requester.token,
    );
    check('isolated wedding plan is created', planResponse.status === 201 && typeof planResponse.body?.id === 'string');
    const planId = planResponse.body?.id;
    if (!planId) throw new Error('Wedding plan setup failed');

    const firstKey = randomUUID();
    const firstInput = {
      planId,
      providerId,
      serviceId,
      cityId: city.id,
      token: requester.token,
      days: 30,
      key: firstKey,
      message: `${marker}-first`,
    };
    const first = await createPlanQuote(firstInput);
    check('first quote request is created', first.status === 201 && typeof first.body?.id === 'string');
    const firstQuoteId = first.body?.id;
    if (!firstQuoteId) throw new Error('First quote request setup failed');

    const firstNotifications = await prisma.notification.findMany({
      where: { entityType: 'quote_request', entityId: firstQuoteId },
      select: { id: true },
    });
    const firstOutboxCount = await prisma.outboxEvent.count({
      where: { aggregateType: 'notification', aggregateId: { in: firstNotifications.map((item) => item.id) } },
    });
    const replay = await createPlanQuote(firstInput);
    const replayNotifications = await prisma.notification.findMany({
      where: { entityType: 'quote_request', entityId: firstQuoteId },
      select: { id: true },
    });
    const replayOutboxCount = await prisma.outboxEvent.count({
      where: { aggregateType: 'notification', aggregateId: { in: replayNotifications.map((item) => item.id) } },
    });
    check('same idempotency key replays the same quote request', replay.status === 201 && replay.body?.id === firstQuoteId);
    check('idempotent replay does not duplicate notifications', replayNotifications.length === firstNotifications.length);
    check('idempotent replay does not duplicate outbox events', replayOutboxCount === firstOutboxCount);

    const duplicate = await createPlanQuote({
      ...firstInput,
      key: randomUUID(),
      message: `${marker}-same-domain-different-message`,
    });
    check('new key cannot bypass the active-domain guard', duplicate.status === 409 && errorCode(duplicate) === 'ACTIVE_QUOTE_REQUEST_EXISTS');
    check('active-domain conflict returns the existing request id', duplicate.body?.quoteRequestId === firstQuoteId);
    check(
      'active-domain identity has exactly one database row',
      (await prisma.quoteRequest.count({
        where: {
          userId: requester.userId,
          providerId,
          weddingPlanId: planId,
          serviceId,
          cityId: city.id,
          eventDate: new Date(eventDate(30)),
        },
      })) === 1,
    );

    const providerRejected = await request(
      'PATCH',
      `/api/v1/provider/me/quote-requests/${firstQuoteId}/status`,
      { status: 'REJECTED' },
      providerAccount.token,
      randomUUID(),
    );
    check('provider can reject the request', providerRejected.status === 200 && providerRejected.body?.status === 'REJECTED');
    const providerRejectionNotification = await prisma.notification.findFirst({
      where: {
        userId: requester.userId,
        entityType: 'quote_request',
        entityId: firstQuoteId,
        type: 'QUOTE_REJECTED',
      },
    });
    check(
      'provider rejection notifies the requester with the correct route',
      providerRejectionNotification?.routeTarget?.includes(firstQuoteId) === true,
    );

    const offerCycle = await createPlanQuote({
      ...firstInput,
      days: 31,
      key: randomUUID(),
      message: `${marker}-requester-reject-cycle`,
    });
    check('a new request is allowed after the prior terminal cycle', offerCycle.status === 201 && typeof offerCycle.body?.id === 'string');
    const offerCycleId = offerCycle.body?.id;
    if (!offerCycleId) throw new Error('Offer rejection cycle setup failed');
    const offerToReject = await request(
      'POST',
      `/api/v1/provider/me/quote-requests/${offerCycleId}/offers`,
      { message: `${marker}-offer-to-reject`, amount: '300000', validUntil: eventDate(10) },
      providerAccount.token,
      randomUUID(),
    );
    check('provider submits an offer', offerToReject.status === 201 && typeof offerToReject.body?.id === 'string');
    const rejectedOfferId = offerToReject.body?.id;
    if (!rejectedOfferId) throw new Error('Rejectable offer setup failed');
    const requesterRejected = await request(
      'PATCH',
      `/api/v1/quote-offers/${rejectedOfferId}/reject`,
      null,
      requester.token,
      randomUUID(),
    );
    check('requester rejects the provider offer', requesterRejected.status === 200 && requesterRejected.body?.status === 'REJECTED');
    const requesterRejectionNotification = await prisma.notification.findFirst({
      where: {
        userId: providerAccount.userId,
        entityType: 'quote_request',
        entityId: offerCycleId,
        type: 'QUOTE_REJECTED',
      },
    });
    const wrongRequesterNotificationCount = await prisma.notification.count({
      where: {
        userId: requester.userId,
        entityType: 'quote_request',
        entityId: offerCycleId,
        type: 'QUOTE_REJECTED',
      },
    });
    check('requester rejection notifies the provider account', requesterRejectionNotification?.routeTarget === '/provider/dashboard');
    check('requester rejection does not notify the actor', wrongRequesterNotificationCount === 0);

    const expiredCycle = await createPlanQuote({
      ...firstInput,
      days: 32,
      key: randomUUID(),
      message: `${marker}-expired-cycle`,
    });
    check('expired-offer cycle request is created', expiredCycle.status === 201 && typeof expiredCycle.body?.id === 'string');
    const expiredQuoteId = expiredCycle.body?.id;
    if (!expiredQuoteId) throw new Error('Expired offer cycle setup failed');
    const expiredOffer = await request(
      'POST',
      `/api/v1/provider/me/quote-requests/${expiredQuoteId}/offers`,
      { message: `${marker}-expired-offer`, amount: '310000', validUntil: eventDate(-1) },
      providerAccount.token,
      randomUUID(),
    );
    check(
      'expired offer is derived as non-actionable',
      expiredOffer.status === 201 && expiredOffer.body?.isExpired === true && expiredOffer.body?.isActionable === false,
    );
    const expiredAccept = await request(
      'PATCH',
      `/api/v1/quote-offers/${expiredOffer.body?.id}/accept`,
      null,
      requester.token,
      randomUUID(),
    );
    check('backend rejects acceptance of an expired offer', expiredAccept.status === 409 && errorCode(expiredAccept) === 'QUOTE_OFFER_EXPIRED');

    const concurrencyCycle = await createPlanQuote({
      ...firstInput,
      days: 33,
      key: randomUUID(),
      message: `${marker}-concurrency-cycle`,
    });
    check('concurrency cycle request is created', concurrencyCycle.status === 201 && typeof concurrencyCycle.body?.id === 'string');
    const concurrencyQuoteId = concurrencyCycle.body?.id;
    if (!concurrencyQuoteId) throw new Error('Concurrency cycle setup failed');
    const concurrentResults = await Promise.all([
      request(
        'POST',
        `/api/v1/provider/me/quote-requests/${concurrencyQuoteId}/offers`,
        { message: `${marker}-race-a`, amount: '320000', validUntil: eventDate(10) },
        providerAccount.token,
        randomUUID(),
      ),
      request(
        'POST',
        `/api/v1/provider/me/quote-requests/${concurrencyQuoteId}/offers`,
        { message: `${marker}-race-b`, amount: '321000', validUntil: eventDate(10) },
        providerAccount.token,
        randomUUID(),
      ),
    ]);
    const createdOffers = concurrentResults.filter((item) => item.status === 201);
    const rejectedOffers = concurrentResults.filter((item) => item.status === 409);
    check('concurrent provider writes create exactly one offer', createdOffers.length === 1 && rejectedOffers.length === 1);
    check('concurrent loser receives HTTP 409', rejectedOffers[0]?.status === 409);
    check('database contains exactly one offer for the concurrent cycle', (await prisma.quoteOffer.count({ where: { quoteRequestId: concurrencyQuoteId } })) === 1);
    await request(
      'PATCH',
      `/api/v1/quote-offers/${createdOffers[0]?.body?.id}/reject`,
      null,
      requester.token,
      randomUUID(),
    );

    const acceptedCycle = await createPlanQuote({
      ...firstInput,
      days: 34,
      key: randomUUID(),
      message: `${marker}-accepted-cycle`,
    });
    check('accepted-offer cycle request is created', acceptedCycle.status === 201 && typeof acceptedCycle.body?.id === 'string');
    const acceptedQuoteId = acceptedCycle.body?.id;
    if (!acceptedQuoteId) throw new Error('Accepted offer cycle setup failed');
    const validOffer = await request(
      'POST',
      `/api/v1/provider/me/quote-requests/${acceptedQuoteId}/offers`,
      { message: `${marker}-valid-offer`, amount: '350000', validUntil: eventDate(10) },
      providerAccount.token,
      randomUUID(),
    );
    check('valid offer is actionable', validOffer.status === 201 && validOffer.body?.isExpired === false && validOffer.body?.isActionable === true);
    const validOfferId = validOffer.body?.id;
    if (!validOfferId) throw new Error('Valid offer setup failed');
    const accepted = await request(
      'PATCH',
      `/api/v1/quote-offers/${validOfferId}/accept`,
      null,
      requester.token,
      randomUUID(),
    );
    check('valid offer is accepted', accepted.status === 200 && accepted.body?.offer?.status === 'ACCEPTED');
    check('accept response declares automatic cost creation', accepted.body?.automaticCostCreated === true);
    check('accept response returns the wedding cost and cost id', accepted.body?.weddingCost?.id === accepted.body?.costSuggestion?.costId);

    const [acceptedQuote, acceptedOffer, link, costs, payments, schedules, tasks] = await Promise.all([
      prisma.quoteRequest.findUnique({ where: { id: acceptedQuoteId } }),
      prisma.quoteOffer.findUnique({ where: { id: validOfferId } }),
      prisma.planProviderLink.findFirst({ where: { quoteOfferId: validOfferId } }),
      prisma.weddingCost.findMany({ where: { quoteOfferId: validOfferId } }),
      prisma.costPayment.count({ where: { weddingCost: { quoteOfferId: validOfferId } } }),
      prisma.paymentSchedule.count({ where: { weddingCost: { quoteOfferId: validOfferId } } }),
      prisma.weddingTask.count({ where: { weddingPlanId: planId } }),
    ]);
    check('accepted request and offer are persisted as ACCEPTED', acceptedQuote?.status === 'ACCEPTED' && acceptedOffer?.status === 'ACCEPTED');
    check('accepted offer creates its plan-provider link', link?.weddingPlanId === planId && link.providerId === providerId);
    check(
      'accepted offer creates exactly one zero-paid wedding cost',
      costs.length === 1 && costs[0].totalAmount.toString() === '350000' && costs[0].paidAmount.toString() === '0',
    );
    check('accept creates no payment, schedule, or task', payments === 0 && schedules === 0 && tasks === 0);

    evidence.providerId = providerId;
    evidence.planId = planId;
    evidence.firstQuoteId = firstQuoteId;
    evidence.acceptedQuoteId = acceptedQuoteId;
    evidence.acceptedOfferId = validOfferId;
    evidence.weddingCostId = costs[0]?.id;
    evidence.idempotentNotificationCount = replayNotifications.length;
    evidence.idempotentOutboxCount = replayOutboxCount;
    evidence.concurrentOfferCount = await prisma.quoteOffer.count({ where: { quoteRequestId: concurrencyQuoteId } });
  } finally {
    if (MANAGED_SMOKE) {
      console.log('INFO - fixture cleanup is owned by the managed isolated smoke runner');
    } else {
      for (const [label, token] of accounts) {
        try {
          await cleanupAccount(label, token);
        } catch (error) {
          check(`${label} fixture account cleanup completes`, false);
          console.error(`Cleanup warning (${label}): ${error.message}`);
        }
      }

      if (evidence.planId || evidence.providerId) {
        const [remainingPlan, remainingProvider] = await Promise.all([
          evidence.planId ? prisma.weddingPlan.count({ where: { id: evidence.planId } }) : 0,
          evidence.providerId ? prisma.provider.count({ where: { id: evidence.providerId } }) : 0,
        ]);
        check('isolated plan and provider rows are removed after cleanup', remainingPlan === 0 && remainingProvider === 0);
      }
    }
  }

  console.log(`\nEvidence: ${JSON.stringify(evidence)}`);
  console.log(`Overall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exitCode = 1;
}

run()
  .catch((error) => {
    console.error(`Quote stability smoke error: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
