#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const { registerVerified } = require('./verified-registration');

/**
 * UX-B3/C1/C2/C3 backend support smoke test.
 * Covers compact dashboard separation, app role/persona, structured/legacy
 * location compatibility, and shared phone normalization behavior.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now().toString();
const OWNER_LOCAL = `7${timestamp.slice(-8)}`;
const INVITEE_LOCAL = `6${timestamp.slice(-8)}`;
const OWNER_PHONE = `+967${OWNER_LOCAL}`;
const INVITEE_PHONE = `+967${INVITEE_LOCAL}`;
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
        res.on('data', (chunk) => {
          data += chunk;
        });
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

function toArabicDigits(value) {
  return value.replace(/[0-9]/g, (digit) =>
    String.fromCharCode(0x0660 + Number(digit)),
  );
}

function hasFullDashboardCollections(value) {
  return [
    'costs',
    'costPayments',
    'paymentSchedules',
    'tasks',
    'guests',
    'providers',
  ].some((key) =>
    Object.prototype.hasOwnProperty.call(value ?? {}, key),
  );
}

async function register(name, phone) {
  const response = await registerVerified(request, {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  check(`${name} register - HTTP 201`, response.status === 201);
  return {
    token: response.body?.accessToken,
    user: response.body?.user,
  };
}

async function run() {
  console.log('\nUX-B3/C1/C2/C3 Backend Support Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}\n`);

  const owner = await register(
    'UX Backend Owner',
    toArabicDigits(`0${OWNER_LOCAL}`),
  );
  check('registration normalizes Arabic phone digits', owner.user?.phone === OWNER_PHONE);
  check('new user defaults to WEDDING_USER app role', owner.user?.appRole === 'WEDDING_USER');
  check('new user remains valid without persona', owner.user?.persona === null);

  const invitee = await register('UX Backend Invitee', INVITEE_PHONE);

  {
    const res = await request(
      'PATCH',
      '/api/v1/users/me',
      { persona: 'BRIDE' },
      owner.token,
    );
    check('valid persona update - HTTP 200', res.status === 200);
    check('profile keeps server-owned app role', res.body?.appRole === 'WEDDING_USER');
    check('profile returns persona', res.body?.persona === 'BRIDE');
  }

  {
    const res = await request(
      'PATCH',
      '/api/v1/users/me',
      { persona: 'NOT_A_PERSONA' },
      owner.token,
    );
    check('invalid persona rejected', res.status === 400);
  }

  {
    const res = await request(
      'PATCH',
      '/api/v1/users/me',
      { appRole: 'NOT_AN_APP_ROLE' },
      owner.token,
    );
    check('invalid app role rejected', res.status === 400);
  }

  let planId = null;
  let legacyPlanId = null;

  {
    const res = await request(
      'POST',
      '/api/v1/wedding-plans',
      {
        title: 'Structured Location Plan',
        persona: 'BRIDE',
        priorities: ['budget', 'tasks'],
        location: {
          governorate: ' صنعاء ',
          cityOrDistrict: ' أمانة العاصمة ',
          areaOrNeighborhood: ' حدة ',
          street: ' شارع صفر ',
          detailedAddress: ' بجوار المعلم ',
        },
      },
      owner.token,
    );
    check('structured plan create - HTTP 201', res.status === 201);
    check('structured plan derives legacy city', res.body?.city === 'أمانة العاصمة');
    check('structured plan returns canonical location', res.body?.location?.cityOrDistrict === 'أمانة العاصمة');
    check('structured plan returns legacy location keys', res.body?.location?.district === 'حدة');
    check('structured plan returns persona', res.body?.persona === 'BRIDE');
    planId = res.body?.id;
  }

  {
    const res = await request(
      'PATCH',
      `/api/v1/wedding-plans/${planId}`,
      {
        persona: 'HELPER',
        location: {
          governorate: 'عدن',
          cityOrDistrict: 'خور مكسر',
          areaOrNeighborhood: 'العريش',
          street: 'الخط البحري',
          detailedAddress: 'قرب الجولة',
        },
      },
      owner.token,
    );
    check('structured plan update - HTTP 200', res.status === 200);
    check('plan update changes persona', res.body?.persona === 'HELPER');
    check('plan update changes city compatibility field', res.body?.city === 'خور مكسر');
    check('plan update returns detailed address', res.body?.location?.detailedAddress === 'قرب الجولة');
  }

  {
    const res = await request(
      'PATCH',
      `/api/v1/wedding-plans/${planId}`,
      {
        location: {
          governorate: 'عدن',
          cityOrDistrict: 'خور مكسر',
          detailedAddress: 'x'.repeat(501),
        },
      },
      owner.token,
    );
    check('oversized location rejected', res.status === 400);
  }

  {
    const res = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}`,
      null,
      owner.token,
    );
    check('plan detail read - HTTP 200', res.status === 200);
    check('plan detail contains full plan metadata', Array.isArray(res.body?.priorities));
    check('plan detail contains structured location', res.body?.location?.governorate === 'عدن');
  }

  {
    const res = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/dashboard-summary`,
      null,
      owner.token,
    );
    check('dashboard summary - HTTP 200', res.status === 200);
    check('dashboard includes compact location metadata', res.body?.location?.cityOrDistrict === 'خور مكسر');
    check('dashboard does not duplicate full domain collections', !hasFullDashboardCollections(res.body));
  }

  {
    const res = await request(
      'PATCH',
      '/api/v1/users/me',
      { appRole: 'PROVIDER' },
      owner.token,
    );
    check('public profile cannot switch app role', res.status === 400);
  }

  {
    const res = await request('GET', '/api/v1/me', null, owner.token);
    check('rejected profile update keeps app role unchanged', res.body?.appRole === 'WEDDING_USER');
  }

  {
    const res = await request('GET', '/api/v1/contexts', null, owner.token);
    const ownerContext = Array.isArray(res.body)
      ? res.body.find((item) => item?.contextKey === `plan:${planId}:owner`)
      : null;
    check('available contexts - HTTP 200', res.status === 200);
    check('available contexts include the owned plan', ownerContext?.role === 'OWNER');
    check('owner context exposes trusted permissions', ownerContext?.permissions?.canManageMoney === true);
  }

  {
    const res = await request(
      'POST',
      '/api/v1/contexts/validate',
      { contextKey: `plan:${planId}:owner` },
      owner.token,
    );
    check('owned context validation - HTTP 201', res.status === 201);
    check('owned context validation returns canonical key', res.body?.contextKey === `plan:${planId}:owner`);
    check('owned context validation returns server plan title', res.body?.displayName === 'Structured Location Plan');
  }

  {
    const res = await request(
      'POST',
      '/api/v1/wedding-plans',
      {
        title: 'Legacy City Plan',
        city: 'تعز',
      },
      owner.token,
    );
    check('rejected app role update does not block wedding plan flow', res.status === 201);
    legacyPlanId = res.body?.id;
  }

  {
    const res = await request(
      'GET',
      `/api/v1/wedding-plans/${legacyPlanId}`,
      null,
      owner.token,
    );
    check('legacy plan read - HTTP 200', res.status === 200);
    check('legacy city maps into structured response', res.body?.location?.cityOrDistrict === 'تعز');
  }

  const guestPhone = '+967777758200';

  {
    const res = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/guests`,
      {
        name: 'Arabic Phone Guest',
        phone: toArabicDigits('0777758200'),
      },
      owner.token,
    );
    check('guest Arabic phone create - HTTP 201', res.status === 201);
    check('guest phone stored canonically', res.body?.phone === guestPhone);
  }

  {
    const res = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/guests`,
      {
        name: 'Duplicate Normalized Guest',
        phone: '00967777758200',
      },
      owner.token,
    );
    check('duplicate normalized guest phone rejected in same plan', res.status === 409);
  }

  {
    const res = await request(
      'POST',
      `/api/v1/wedding-plans/${legacyPlanId}/guests`,
      {
        name: 'Same Phone Other Plan',
        phone: guestPhone,
      },
      owner.token,
    );
    check('same normalized guest phone allowed in another plan', res.status === 201);
  }

  {
    const res = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/invites`,
      {
        phone: toArabicDigits(`00967${INVITEE_LOCAL}`),
        role: 'HELPER',
      },
      owner.token,
    );
    check('participant invite phone normalization - HTTP 201', res.status === 201);
    check('participant invite stores canonical phone', res.body?.phone === INVITEE_PHONE);
    check('participant invite links registered user', res.body?.inviteeUserId === invitee.user?.id);
  }

  {
    const res = await request(
      'PATCH',
      `/api/v1/wedding-plans/${legacyPlanId}/archive`,
      null,
      owner.token,
    );
    check('archive active plan - HTTP 200', res.status === 200);
  }

  {
    const res = await request(
      'GET',
      '/api/v1/wedding-plans/active',
      null,
      owner.token,
    );
    check('invalid active plan returns HTTP 200', res.status === 200);
    check(
      'invalid active plan returns no body/null without fallback',
      res.body === null || res.body === '',
    );
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('UX backend support smoke error:', error.message);
  process.exit(1);
});
