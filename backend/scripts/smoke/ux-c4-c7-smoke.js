#!/usr/bin/env node
'use strict';

const { configureSmokeDatabaseUrl } = require('./smoke-utils');

configureSmokeDatabaseUrl();

const { registerVerified } = require('./verified-registration');

const http = require('http');
const {
  PrismaClient,
  ProviderStatus,
} = require('@prisma/client');

const prisma = new PrismaClient();
const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const stamp = `${timestamp.toString().slice(-4)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+96773${stamp}`;
const INVITEE_PHONE = `+96774${stamp}`;
const PROVIDER_PHONE = `+96775${stamp}`;
const PENDING_PHONE = `+96776${stamp}`;
const PASSWORD = 'SmokeTest123!';
let passed = 0;
let failed = 0;

function check(label, condition) {
  console.log(`${condition ? 'PASS' : 'FAIL'} - ${label}`);
  condition ? passed++ : failed++;
}

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === undefined ? undefined : JSON.stringify(body);
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
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
            resolve({ status: res.statusCode, body: JSON.parse(data) });
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

async function register(name, phone) {
  const response = await registerVerified(request, {
    name,
    phone,
    password: PASSWORD,
  });
  check(`${name} register`, response.status === 201);
  return {
    token: response.body?.accessToken,
    user: response.body?.user,
  };
}

async function run() {
  console.log('\nUX-C4/C5/C6/C7 Integration Smoke Report');
  console.log(`Target: ${BASE_URL}\n`);

  const owner = await register('C4-C7 Owner', OWNER_PHONE);
  const invitee = await register('C4-C7 Invitee', INVITEE_PHONE);
  const providerUser = await register('C4-C7 Provider', PROVIDER_PHONE);

  const city = await prisma.city.upsert({
    where: {
      nameAr_countryCode: {
        nameAr: 'C4-C7 Smoke City',
        countryCode: 'YE',
      },
    },
    update: { isActive: true },
    create: {
      nameAr: 'C4-C7 Smoke City',
      nameEn: 'C4-C7 Smoke City',
      countryCode: 'YE',
      isActive: true,
    },
  });
  const category = await prisma.providerCategory.upsert({
    where: { slug: 'c4-c7-smoke' },
    update: { isActive: true },
    create: {
      nameAr: 'C4-C7 Smoke',
      nameEn: 'C4-C7 Smoke',
      slug: 'c4-c7-smoke',
      isActive: true,
    },
  });

  const providerResponse = await request(
    'POST',
    '/api/v1/provider/apply',
    {
      businessName: 'C4-C7 Provider',
      phone: PROVIDER_PHONE,
      cityId: city.id,
      categoryIds: [category.id],
    },
    providerUser.token,
  );
  check('provider profile created', providerResponse.status === 201);
  const providerId = providerResponse.body?.id;
  await prisma.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.ACTIVE },
  });

  const planResponse = await request(
    'POST',
    '/api/v1/wedding-plans',
    {
      title: 'C4-C7 Live Truth Plan',
      estimatedBudget: '900000',
      location: {
        governorate: 'صنعاء',
        cityOrDistrict: 'أمانة العاصمة',
        areaOrNeighborhood: 'حدة',
      },
    },
    owner.token,
  );
  check('structured plan created', planResponse.status === 201);
  const planId = planResponse.body?.id;

  const quoteResponse = await request(
    'POST',
    `/api/v1/wedding-plans/${planId}/quote-requests`,
    {
      providerId,
      cityId: city.id,
      contactName: owner.user?.name,
      contactPhone: OWNER_PHONE,
      location: {
        governorate: 'صنعاء',
        cityOrDistrict: 'أمانة العاصمة',
        areaOrNeighborhood: 'حدة',
      },
      message: 'C4-C7 real quote request',
    },
    owner.token,
  );
  check('quote request submitted', quoteResponse.status === 201);
  check(
    'quote lifecycle is pending provider',
    quoteResponse.body?.lifecycleStatus === 'PENDING_PROVIDER',
  );
  check(
    'quote stores structured location',
    quoteResponse.body?.location?.cityOrDistrict === 'أمانة العاصمة',
  );
  check(
    'quote stores normalized contact phone',
    quoteResponse.body?.contactNormalizedPhone === OWNER_PHONE,
  );
  const quoteId = quoteResponse.body?.id;

  const offerResponse = await request(
    'POST',
    `/api/v1/provider/me/quote-requests/${quoteId}/offers`,
    {
      message: 'C4-C7 real provider offer',
      amount: '250000',
    },
    providerUser.token,
  );
  check('provider creates real offer', offerResponse.status === 201);
  const offerId = offerResponse.body?.id;

  const quoteDetail = await request(
    'GET',
    `/api/v1/quote-requests/${quoteId}`,
    undefined,
    owner.token,
  );
  check(
    'received lifecycle requires real offer',
    quoteDetail.body?.lifecycleStatus === 'RECEIVED',
  );

  const costsBefore = await prisma.weddingCost.count({
    where: { weddingPlanId: planId },
  });
  const acceptResponse = await request(
    'PATCH',
    `/api/v1/quote-offers/${offerId}/accept`,
    {},
    owner.token,
  );
  check('received quote accepted', acceptResponse.status === 200);
  check(
    'accepted quote creates plan provider link',
    acceptResponse.body?.planProviderLink?.providerId === providerId,
  );
  check(
    'accepted quote response declares no automatic cost',
    acceptResponse.body?.automaticCostCreated === false,
  );
  check(
    'accepted quote response includes next actions',
    Array.isArray(acceptResponse.body?.nextActions) &&
      acceptResponse.body.nextActions.includes('createCost') &&
      acceptResponse.body.nextActions.includes('createFollowUpTask') &&
      acceptResponse.body.nextActions.includes('viewAcceptedProvider'),
  );
  check(
    'accepted quote response suggests explicit cost creation',
    acceptResponse.body?.costSuggestion?.recommendedAction === 'CREATE_COST',
  );
  check(
    'accept creates no automatic cost',
    (await prisma.weddingCost.count({ where: { weddingPlanId: planId } })) ===
      costsBefore,
  );

  const inviteResponse = await request(
    'POST',
    `/api/v1/wedding-plans/${planId}/invites`,
    { userId: invitee.user.id, role: 'HELPER' },
    owner.token,
  );
  check('participant invite created', inviteResponse.status === 201);
  const declineResponse = await request(
    'POST',
    `/api/v1/invites/${inviteResponse.body?.token}/decline`,
    {},
    invitee.token,
  );
  check(
    'participant can decline invite',
    declineResponse.status === 201 &&
      declineResponse.body?.status === 'DECLINED',
  );

  const pendingInvite = await request(
    'POST',
    `/api/v1/wedding-plans/${planId}/invites`,
    { phone: PENDING_PHONE, role: 'FAMILY' },
    owner.token,
  );
  check('pending phone invite created', pendingInvite.status === 201);
  const duplicateInvite = await request(
    'POST',
    `/api/v1/wedding-plans/${planId}/invites`,
    { phone: PENDING_PHONE, role: 'FAMILY' },
    owner.token,
  );
  check('duplicate pending invite rejected', duplicateInvite.status === 409);

  const ownerNotifications = await request(
    'GET',
    `/api/v1/notifications?weddingPlanId=${planId}`,
    undefined,
    owner.token,
  );
  const declinedNotification = ownerNotifications.body?.items?.find?.(
    (item) => item.type === 'SHARING_INVITE_DECLINED',
  );
  check('decline creates routed notification', Boolean(
    declinedNotification?.id &&
      declinedNotification?.routeTarget ===
        `/wedding-plans/${planId}/sharing`,
  ));
  const archiveResponse = await request(
    'PATCH',
    `/api/v1/notifications/${declinedNotification?.id}/archive`,
    {},
    owner.token,
  );
  check(
    'notification archive sets archivedAt',
    archiveResponse.status === 200 &&
      typeof archiveResponse.body?.archivedAt === 'string',
  );

  const dashboard = await request(
    'GET',
    `/api/v1/wedding-plans/${planId}/dashboard-summary`,
    undefined,
    owner.token,
  );
  check('dashboard live truth loads', dashboard.status === 200);
  check('dashboard accepted provider count is real', dashboard.body?.acceptedProviders === 1);
  check('dashboard pending invites count is real', dashboard.body?.pendingInvites === 1);
  check(
    'dashboard returns at most three next actions',
    Array.isArray(dashboard.body?.nextBestActions) &&
      dashboard.body.nextBestActions.length <= 3,
  );
  check(
    'dashboard notification summary is compact',
    typeof dashboard.body?.notificationSummary?.unread === 'number' &&
      dashboard.body?.notifications === undefined,
  );

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exitCode = 1;
}

run()
  .catch((error) => {
    console.error('UX-C4/C5/C6/C7 smoke error:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
