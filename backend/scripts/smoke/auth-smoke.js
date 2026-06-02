#!/usr/bin/env node
'use strict';

/**
 * Auth Smoke Test
 * Tests: POST /auth/register, POST /auth/login, GET /auth/me
 * Confirms passwordHash is never returned.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const TEST_PHONE = `+9671${timestamp.toString().slice(-7)}`;
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
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
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

async function run() {
  console.log('\nAuth Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  // 1. Register
  let registerToken = null;
  let registeredUser = null;
  {
    const res = await request('POST', '/auth/register', {
      name: 'Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    check('register returns user object', typeof res.body?.user === 'object');
    check('register does not expose passwordHash', !('passwordHash' in (res.body?.user ?? {})));
    check('register user has id', typeof res.body?.user?.id === 'string');
    check('register user has name', res.body?.user?.name === 'Smoke User');
    check('register user has USER role', res.body?.user?.role === 'USER');
    check('register user has ACTIVE status', res.body?.user?.status === 'ACTIVE');
    registeredUser = res.body?.user;
    registerToken = res.body?.accessToken;
  }

  // 2. Login
  let loginToken = null;
  let loginUser = null;
  {
    const res = await request('POST', '/auth/login', {
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /auth/login - HTTP 200', res.status === 200);
    check('login returns accessToken', typeof res.body?.accessToken === 'string');
    check('login returns user object', typeof res.body?.user === 'object');
    check('login does not expose passwordHash', !('passwordHash' in (res.body?.user ?? {})));
    check('login user id matches registered user', res.body?.user?.id === registeredUser?.id);
    check('login user role matches registered user', res.body?.user?.role === registeredUser?.role);
    loginUser = res.body?.user;
    loginToken = res.body?.accessToken;
  }

  // 3. Wrong password rejected
  {
    const res = await request('POST', '/auth/login', {
      phone: TEST_PHONE,
      password: 'wrongpassword',
    });
    check('login with wrong password returns 401', res.status === 401);
  }

  // 4. GET /auth/me without token
  {
    const res = await request('GET', '/auth/me');
    check('GET /auth/me without token returns 401', res.status === 401);
  }

  // 5. GET /auth/me with token
  {
    const token = loginToken ?? registerToken;
    const res = await request('GET', '/auth/me', null, token);
    check('GET /auth/me with token - HTTP 200', res.status === 200);
    check('GET /auth/me does not expose passwordHash', !('passwordHash' in (res.body ?? {})));
    check('GET /auth/me returns correct phone', res.body?.phone === TEST_PHONE);
    check('GET /auth/me user id matches login user', res.body?.id === loginUser?.id);
    check('GET /auth/me role matches login user', res.body?.role === loginUser?.role);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Auth smoke error:', err.message);
  process.exit(1);
});
