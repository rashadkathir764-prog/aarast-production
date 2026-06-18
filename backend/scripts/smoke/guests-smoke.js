#!/usr/bin/env node
'use strict';

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3124';
const timestamp = Date.now();
const TEST_PHONE = `+96774${timestamp.toString().slice(-6)}`;
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
    });

    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

function hasPasswordHash(value) {
  return JSON.stringify(value).includes('passwordHash');
}

async function run() {
  console.log('\nGuests Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let accessToken = null;
  let planId = null;
  let guestId = null;
  let secondGuestId = null;

  {
    const res = await request('POST', '/auth/register', {
      name: 'Guests Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    accessToken = res.body?.accessToken;
  }

  {
    const res = await request('POST', '/wedding-plans', {
      title: 'Guests Smoke Plan',
      city: 'Aden',
      weddingDate: '2026-12-20T00:00:00.000Z',
      estimatedBudget: '800000',
    }, accessToken);
    check('POST /wedding-plans - HTTP 201', res.status === 201);
    planId = res.body?.id;
  }

  {
    const res = await request('GET', `/wedding-plans/${planId}/guests`, null, accessToken);
    check('GET /wedding-plans/:id/guests - HTTP 200', res.status === 200);
    check('initial guests response is array', Array.isArray(res.body));
  }

  {
    const res = await request('POST', `/wedding-plans/${planId}/guests`, {
      name: 'Smoke Guest',
      phone: '+967700000001',
      side: 'FAMILY',
      status: 'INVITED',
      seatsCount: 2,
      notes: 'Smoke note',
    }, accessToken);
    check('POST /wedding-plans/:id/guests - HTTP 201', res.status === 201);
    check('created guest has id', typeof res.body?.id === 'string');
    check('created guest persists submitted name', res.body?.name === 'Smoke Guest');
    check('created guest stores normalized phone', res.body?.phone === '+967700000001');
    check('created guest does not expose passwordHash', !hasPasswordHash(res.body));
    guestId = res.body?.id;
  }

  {
    const res = await request('POST', `/wedding-plans/${planId}/guests`, {
      name: '  Smoke   Guest  ',
      phone: '00967700000001',
      side: 'FAMILY',
      status: 'INVITED',
    }, accessToken);
    check('duplicate guest create returns 409', res.status === 409);
    check(
      'duplicate guest create returns clear message',
      res.body?.message === 'هذا الضيف مضاف مسبقًا',
    );
  }

  {
    const res = await request('POST', `/wedding-plans/${planId}/guests`, {
      name: 'Smoke Guest',
      phone: '+967700000002',
      side: 'FAMILY',
      status: 'INVITED',
    }, accessToken);
    check('same guest name with different phone returns 201', res.status === 201);
    check('same guest name different phone has id', typeof res.body?.id === 'string');
    secondGuestId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/guests/${secondGuestId}`, {
      phone: '700000001',
    }, accessToken);
    check('duplicate guest update returns 409', res.status === 409);
    check(
      'duplicate guest update returns clear message',
      res.body?.message === 'هذا الضيف مضاف مسبقًا',
    );
  }

  {
    const res = await request('PATCH', `/guests/${guestId}`, {
      status: 'CONFIRMED',
      seatsCount: 3,
    }, accessToken);
    check('PATCH /guests/:id - HTTP 200', res.status === 200);
    check('updated guest status changed', res.body?.status === 'CONFIRMED');
    check('updated guest seats changed', res.body?.seatsCount === 3);
  }

  {
    const res = await request('GET', `/wedding-plans/${planId}/guests`, null, accessToken);
    check('GET guests after update - HTTP 200', res.status === 200);
    check(
      'list includes updated guest',
      Array.isArray(res.body) &&
        res.body.some((guest) => guest.id === guestId && guest.status === 'CONFIRMED'),
    );
  }

  {
    const res = await request('DELETE', `/guests/${guestId}`, null, accessToken);
    check('DELETE /guests/:id - HTTP 200', res.status === 200);
    check('delete response marks deleted', res.body?.deleted === true);
  }

  if (secondGuestId) {
    const res = await request('DELETE', `/guests/${secondGuestId}`, null, accessToken);
    check('DELETE second guest - HTTP 200', res.status === 200);
    check('second guest delete response marks deleted', res.body?.deleted === true);
  }

  {
    const res = await request('GET', `/wedding-plans/${planId}/guests`, null, accessToken);
    check('GET guests after delete - HTTP 200', res.status === 200);
    check(
      'deleted guests are removed',
      Array.isArray(res.body) &&
        !res.body.some((guest) => guest.id === guestId || guest.id === secondGuestId),
    );
  }

  {
    const res = await request('GET', `/wedding-plans/${planId}/guests`);
    check('GET guests without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Guests smoke error:', err.message);
  process.exit(1);
});
