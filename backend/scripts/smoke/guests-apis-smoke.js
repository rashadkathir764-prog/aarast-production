#!/usr/bin/env node
'use strict';

/**
 * Guests APIs Smoke Test
 * Covers /api/v1 guests, groups, bulk import, statuses, summary, and guards.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+9679${suffix}`;
const OUTSIDER_PHONE = `+9671${suffix}`;
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

    const options = {
      hostname: url.hostname,
      port: url.port,
      path: `${url.pathname}${url.search}`,
      method,
      headers,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

function hasPasswordHash(value) {
  return JSON.stringify(value).includes('passwordHash');
}

async function registerUser(name, phone) {
  const res = await request('POST', '/auth/register', {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  check(`${name} register - HTTP 201`, res.status === 201);
  check(`${name} register returns token`, typeof res.body?.accessToken === 'string');
  check(`${name} register does not expose passwordHash`, !hasPasswordHash(res.body));
  return { token: res.body?.accessToken, userId: res.body?.user?.id };
}

async function run() {
  console.log('\nGuests APIs Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Outsider phone: ${OUTSIDER_PHONE}\n`);

  const owner = await registerUser('Guests Owner', OWNER_PHONE);
  const outsider = await registerUser('Guests Outsider', OUTSIDER_PHONE);

  let planId = null;
  let groupId = null;
  let guestId = null;
  let bulkGuestId = null;

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Guests APIs Plan',
      city: 'Sanaa',
    }, owner.token);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    planId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/guest-groups`, {
      name: 'Family',
      notes: 'Family side',
      sortOrder: 1,
    }, owner.token);
    check('POST /api/v1 guest group - HTTP 201', res.status === 201);
    check('guest group has id', typeof res.body?.id === 'string');
    groupId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/guest-groups`, null, owner.token);
    check('GET /api/v1 guest groups - HTTP 200', res.status === 200);
    check('guest groups include created group', Array.isArray(res.body) && res.body.some((group) => group.id === groupId));
  }

  {
    const res = await request('PATCH', `/api/v1/guest-groups/${groupId}`, {
      name: 'Main Family',
    }, owner.token);
    check('PATCH /api/v1/guest-groups/:id - HTTP 200', res.status === 200);
    check('guest group updated', res.body?.name === 'Main Family');
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/guests`, {
      name: 'Confirmed Guest',
      phone: '+967700100001',
      groupId,
      side: 'GROOM',
      invitationStatus: 'SENT',
      attendanceStatus: 'CONFIRMED',
      seatsCount: 3,
      companionsCount: 2,
    }, owner.token);
    check('POST /api/v1 guest - HTTP 201', res.status === 201);
    check('guest has id', typeof res.body?.id === 'string');
    check('guest has groupId', res.body?.groupId === groupId);
    check('guest attendance status saved', res.body?.attendanceStatus === 'CONFIRMED');
    guestId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/guests/${guestId}`, null, owner.token);
    check('GET /api/v1/guests/:id - HTTP 200', res.status === 200);
    check('guest get-by-id matches', res.body?.id === guestId);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/guests`, {
      name: 'Duplicate Phone Different Name',
      phone: '+967700100001',
    }, owner.token);
    check('duplicate phone inside plan returns 409', res.status === 409);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/guests/bulk`, {
      items: [
        {
          name: 'Declined Guest',
          phone: '+967700100002',
          groupId,
          side: 'BRIDE',
          attendanceStatus: 'DECLINED',
          invitationStatus: 'DELIVERED',
          seatsCount: 1,
        },
        {
          name: 'Pending Guest',
          side: 'FRIEND',
          attendanceStatus: 'PENDING',
          invitationStatus: 'NOT_SENT',
          seatsCount: 1,
        },
      ],
    }, owner.token);
    check('POST /api/v1 guests bulk - HTTP 201', res.status === 201);
    check('bulk creates two guests', Array.isArray(res.body?.created) && res.body.created.length === 2);
    bulkGuestId = res.body?.created?.[0]?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/guests/${bulkGuestId}`, {
      notes: 'Updated bulk guest',
      companionsCount: 1,
    }, owner.token);
    check('PATCH /api/v1/guests/:id - HTTP 200', res.status === 200);
    check('guest companions updated', res.body?.companionsCount === 1);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/guests/summary`, null, owner.token);
    check('GET /api/v1 guests summary - HTTP 200', res.status === 200);
    check('summary totalGuests is real', res.body?.totalGuests === 3);
    check('summary confirmedGuests is real', res.body?.confirmedGuests === 1);
    check('summary confirmed alias is stable', res.body?.confirmed === 1);
    check('summary declinedGuests is real', res.body?.declinedGuests === 1);
    check('summary notAttending alias is stable', res.body?.notAttending === 1);
    check('summary pendingGuests is real', res.body?.pendingGuests === 1);
    check('summary waiting alias is stable', res.body?.waiting === 1);
    check('summary missingPhoneCount is real', res.body?.missingPhoneCount === 1);
    check('summary incompleteGuestsCount is real', res.body?.incompleteGuestsCount === 1);
    check('summary groupsCount is real', res.body?.groupsCount === 1);
    check('summary seatsTotal is real', res.body?.seatsTotal === 5);
    check('summary expectedSeatsCount alias is stable', res.body?.expectedSeatsCount === 5);
    check('summary companionsTotal is real', res.body?.companionsTotal === 3);
    check('summary bySideForSuper includes unknown bucket', res.body?.bySideForSuper?.unknown === 1);
    check('summary byGroup includes created group', res.body?.byGroup?.['Main Family'] === 2);
    check('summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/guests`, null, outsider.token);
    check('outsider cannot list guests', res.status === 404);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/guests`);
    check('guests without token returns 401', res.status === 401);
  }

  {
    const res = await request('DELETE', `/api/v1/guests/${guestId}`, null, owner.token);
    check('DELETE /api/v1/guests/:id - HTTP 200', res.status === 200);
  }

  {
    const res = await request('DELETE', `/api/v1/guest-groups/${groupId}`, null, owner.token);
    check('DELETE /api/v1/guest-groups/:id - HTTP 200', res.status === 200);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Guests APIs smoke error:', err.message);
  process.exit(1);
});
