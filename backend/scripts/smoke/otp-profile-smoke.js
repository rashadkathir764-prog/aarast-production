#!/usr/bin/env node
'use strict';

/**
 * OTP + Profile Smoke Test
 * Tests: OTP request/verify, wrong and consumed OTP rejection, profile update,
 * and user settings defaults/update.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const TEST_PHONE = `+9675${suffix}`;
const TEST_EMAIL = `otp-smoke-${timestamp}@example.test`;
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

function hasPasswordHash(value) {
  return JSON.stringify(value).includes('passwordHash');
}

async function run() {
  console.log('\nOTP + Profile Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let token = null;
  let code = null;

  {
    const res = await request('POST', '/auth/register', {
      name: 'OTP Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /auth/register - HTTP 201', res.status === 201);
    check('register returns token', typeof res.body?.accessToken === 'string');
    check('register does not expose passwordHash', !hasPasswordHash(res.body));
    token = res.body?.accessToken;
  }

  {
    const res = await request('POST', '/auth/otp/request', {
      phone: TEST_PHONE,
      purpose: 'VERIFY_PHONE',
    });
    check('POST /auth/otp/request - HTTP 200', res.status === 200);
    check('otp request returns expiry', typeof res.body?.expiresAt === 'string');
    check('local smoke receives OTP code', typeof res.body?.code === 'string');
    code = res.body?.code;
  }

  {
    const res = await request('POST', '/auth/otp/verify', {
      phone: TEST_PHONE,
      purpose: 'VERIFY_PHONE',
      code: '000000',
    });
    check('wrong OTP is rejected', res.status === 400);
  }

  {
    const res = await request('POST', '/auth/otp/verify', {
      phone: TEST_PHONE,
      purpose: 'VERIFY_PHONE',
      code,
    });
    check('POST /auth/otp/verify - HTTP 200', res.status === 200);
    check('OTP verify returns verified true', res.body?.verified === true);
    check('OTP verify marks user phone verified', Boolean(res.body?.user?.phoneVerifiedAt));
    check('OTP verify does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', '/auth/otp/verify', {
      phone: TEST_PHONE,
      purpose: 'VERIFY_PHONE',
      code,
    });
    check('consumed OTP is rejected', res.status === 400);
  }

  {
    const res = await request('GET', '/auth/me', null, token);
    check('GET /auth/me - HTTP 200', res.status === 200);
    check('GET /auth/me includes phoneVerifiedAt', Boolean(res.body?.phoneVerifiedAt));
    check('GET /auth/me does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', '/users/me', {
      name: 'Updated OTP Smoke User',
      email: TEST_EMAIL,
      avatarUrl: 'https://example.test/avatar.png',
      locale: 'ar',
    }, token);
    check('PATCH /users/me - HTTP 200', res.status === 200);
    check('profile name updated', res.body?.name === 'Updated OTP Smoke User');
    check('profile email updated', res.body?.email === TEST_EMAIL);
    check('profile does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', '/users/me/settings', null, token);
    check('GET /users/me/settings - HTTP 200', res.status === 200);
    check('settings default pushEnabled true', res.body?.pushEnabled === true);
    check('settings default smsEnabled false', res.body?.smsEnabled === false);
  }

  {
    const res = await request('PATCH', '/users/me/settings', {
      smsEnabled: true,
      whatsappEnabled: true,
      emailEnabled: true,
    }, token);
    check('PATCH /users/me/settings - HTTP 200', res.status === 200);
    check('settings smsEnabled updated', res.body?.smsEnabled === true);
    check('settings whatsappEnabled updated', res.body?.whatsappEnabled === true);
    check('settings emailEnabled updated', res.body?.emailEnabled === true);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('OTP + profile smoke error:', err.message);
  process.exit(1);
});
