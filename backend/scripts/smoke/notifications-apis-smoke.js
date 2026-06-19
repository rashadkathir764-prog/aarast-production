#!/usr/bin/env node
'use strict';

/**
 * Internal Notifications APIs Smoke Test
 * Covers /api/v1 notifications, get-by-id, read state, ownership,
 * invite notifications, and quote offer notifications.
 */

if (process.env.SMOKE_DATABASE_URL) {
  process.env.DATABASE_URL = process.env.SMOKE_DATABASE_URL;
}

const http = require('http');
const { PrismaClient, ProviderStatus } = require('@prisma/client');

const prisma = new PrismaClient();
const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const OWNER_PHONE = `+96763${timestamp.toString().slice(-6)}`;
const INVITEE_PHONE = `+96764${timestamp.toString().slice(-6)}`;
const PROVIDER_PHONE = `+96765${timestamp.toString().slice(-6)}`;
const CUSTOMER_PHONE = `+96766${timestamp.toString().slice(-6)}`;
const OUTSIDER_PHONE = `+96767${timestamp.toString().slice(-6)}`;
const TEST_PASSWORD = 'SmokeTest123!';

let passed = 0;
let failed = 0;

function check(label, condition) {
  if (condition) {
    console.log(`PASS - ${label}`);
    passed++;
  } else {
    console.log(`FAIL - ${label}`);
    failed++;
  }
}

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const bodyStr = body ? JSON.stringify(body) : undefined;
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
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

function hasPasswordHash(value) {
  return JSON.stringify(value).includes('passwordHash');
}

async function ensureReferenceData() {
  const city = await prisma.city.upsert({
    where: {
      nameAr_countryCode: {
        nameAr: 'Phase9 Smoke City',
        countryCode: 'YE',
      },
    },
    update: { isActive: true },
    create: {
      nameAr: 'Phase9 Smoke City',
      nameEn: 'Phase9 Smoke City',
      countryCode: 'YE',
      isActive: true,
      sortOrder: 9,
    },
  });

  const category = await prisma.providerCategory.upsert({
    where: { slug: 'phase9-smoke-category' },
    update: { isActive: true },
    create: {
      nameAr: 'Phase9 Smoke Category',
      nameEn: 'Phase9 Smoke Category',
      slug: 'phase9-smoke-category',
      icon: 'bell',
      isActive: true,
      sortOrder: 9,
    },
  });

  return { city, category };
}

async function register(name, phone) {
  const res = await request('POST', '/auth/register', {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  check(`${name} register - HTTP 201`, res.status === 201);
  check(`${name} register returns token`, typeof res.body?.accessToken === 'string');
  check(`${name} register has user id`, typeof res.body?.user?.id === 'string');
  check(`${name} register does not expose passwordHash`, !hasPasswordHash(res.body));
  return { token: res.body?.accessToken, user: res.body?.user };
}

async function run() {
  console.log('\nInternal Notifications APIs Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Invitee phone: ${INVITEE_PHONE}`);
  console.log(`Provider phone: ${PROVIDER_PHONE}`);
  console.log(`Customer phone: ${CUSTOMER_PHONE}`);
  console.log(`Outsider phone: ${OUTSIDER_PHONE}\n`);

  const reference = await ensureReferenceData();
  const owner = await register('Phase9 Owner', OWNER_PHONE);
  const invitee = await register('Phase9 Invitee', INVITEE_PHONE);
  const providerUser = await register('Phase9 Provider', PROVIDER_PHONE);
  const customer = await register('Phase9 Customer', CUSTOMER_PHONE);
  const outsider = await register('Phase9 Outsider', OUTSIDER_PHONE);

  let ownerPlanId = null;
  let inviteToken = null;
  let inviteNotificationId = null;
  let acceptedNotificationId = null;
  let providerId = null;
  let serviceId = null;
  let quotePlanId = null;
  let quoteOfferNotificationId = null;

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Phase9 Invite Plan',
      city: 'Sanaa',
    }, owner.token);
    check('owner creates plan - HTTP 201', res.status === 201);
    ownerPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${ownerPlanId}/invites`, {
      userId: invitee.user.id,
      role: 'HELPER',
    }, owner.token);
    check('owner creates invite - HTTP 201', res.status === 201);
    check('invite token returned', typeof res.body?.token === 'string');
    inviteToken = res.body?.token;
  }

  {
    const res = await request('GET', '/api/v1/notifications', null, invitee.token);
    check('invitee notifications list - HTTP 200', res.status === 200);
    const notification = Array.isArray(res.body)
      ? res.body.find((item) => item.type === 'SHARING_INVITATION' && item.weddingPlanId === ownerPlanId)
      : null;
    check('invite notification created', typeof notification?.id === 'string');
    check('invite notification does not expose passwordHash', !hasPasswordHash(res.body));
    inviteNotificationId = notification?.id;
  }

  {
    const res = await request('GET', '/api/v1/notifications/unread-count', null, invitee.token);
    check('invitee unread count - HTTP 200', res.status === 200);
    check('invitee unread count is positive', res.body?.count >= 1);
  }

  {
    const res = await request('GET', `/api/v1/notifications/${inviteNotificationId}`, null, invitee.token);
    check('GET /api/v1/notifications/:id - HTTP 200', res.status === 200);
    check('get notification id matches', res.body?.id === inviteNotificationId);
  }

  {
    const res = await request('GET', `/api/v1/notifications/${inviteNotificationId}`, null, outsider.token);
    check('outsider cannot read invitee notification', res.status === 404);
  }

  {
    const res = await request('PATCH', `/api/v1/notifications/${inviteNotificationId}/read`, null, invitee.token);
    check('mark notification read - HTTP 200', res.status === 200);
    check('mark read sets readAt', typeof res.body?.readAt === 'string');
  }

  {
    const res = await request('POST', `/api/v1/invites/${inviteToken}/accept`, null, invitee.token);
    check('invitee accepts invite - HTTP 201', res.status === 201);
  }

  {
    const res = await request('GET', '/api/v1/notifications', null, owner.token);
    check('owner notifications list - HTTP 200', res.status === 200);
    const notification = Array.isArray(res.body)
      ? res.body.find((item) => item.type === 'SHARING_INVITE_ACCEPTED' && item.weddingPlanId === ownerPlanId)
      : null;
    check('invite accepted notification created', typeof notification?.id === 'string');
    acceptedNotificationId = notification?.id;
  }

  {
    const res = await request('GET', `/api/v1/notifications/${acceptedNotificationId}`, null, owner.token);
    check('owner reads accepted invite notification - HTTP 200', res.status === 200);
    check('accepted notification type matches', res.body?.type === 'SHARING_INVITE_ACCEPTED');
  }

  {
    const res = await request('POST', '/api/v1/provider/profile', {
      businessName: 'Phase9 Provider Business',
      phone: PROVIDER_PHONE,
      cityId: reference.city.id,
      categoryIds: [reference.category.id],
      description: 'Phase9 provider',
    }, providerUser.token);
    check('provider creates profile - HTTP 201', res.status === 201);
    providerId = res.body?.id;
  }

  {
    const res = await request('POST', '/api/v1/provider/services', {
      categoryId: reference.category.id,
      title: 'Phase9 Service',
      basePrice: '150000.00',
      cityId: reference.city.id,
    }, providerUser.token);
    check('provider creates service - HTTP 201', res.status === 201);
    serviceId = res.body?.id;
  }

  await prisma.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.ACTIVE },
  });

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Phase9 Quote Plan',
      city: 'Sanaa',
    }, customer.token);
    check('customer creates quote plan - HTTP 201', res.status === 201);
    quotePlanId = res.body?.id;
  }

  let quoteId = null;
  {
    const res = await request('POST', `/api/v1/wedding-plans/${quotePlanId}/quote-requests`, {
      providerId,
      serviceId,
      message: 'Need Phase9 offer notification',
    }, customer.token);
    check('customer creates quote - HTTP 201', res.status === 201);
    quoteId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/provider/quote-requests/${quoteId}/offers`, {
      title: 'Phase9 Offer',
      message: 'Phase9 offer notification body',
      amount: '180000.00',
    }, providerUser.token);
    check('provider creates quote offer - HTTP 201', res.status === 201);
  }

  {
    const res = await request('GET', `/api/v1/notifications?weddingPlanId=${quotePlanId}`, null, customer.token);
    check('customer plan notifications - HTTP 200', res.status === 200);
    const notification = Array.isArray(res.body)
      ? res.body.find((item) => item.type === 'QUOTE_OFFER_RECEIVED' && item.weddingPlanId === quotePlanId)
      : null;
    check('quote offer notification created', typeof notification?.id === 'string');
    check('quote offer notification has safe data', notification?.data?.quoteRequestId === quoteId);
    quoteOfferNotificationId = notification?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/notifications/${quoteOfferNotificationId}/read`, null, customer.token);
    check('customer marks quote notification read - HTTP 200', res.status === 200);
  }

  {
    const res = await request('PATCH', `/api/v1/notifications/read-all?weddingPlanId=${quotePlanId}`, null, customer.token);
    check('read all plan notifications - HTTP 200', res.status === 200);
    check('read all returns updated count', typeof res.body?.updated === 'number');
  }

  {
    const res = await request('GET', `/api/v1/notifications/unread-count?weddingPlanId=${quotePlanId}`, null, customer.token);
    check('plan unread count after read-all - HTTP 200', res.status === 200);
    check('plan unread count is zero', res.body?.count === 0);
  }

  {
    const res = await request('GET', '/api/v1/notifications');
    check('notifications without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run()
  .catch((err) => {
    console.error('Notifications APIs smoke error:', err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
