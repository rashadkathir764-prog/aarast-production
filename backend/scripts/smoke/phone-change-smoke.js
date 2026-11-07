#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { registerVerified } = require('./verified-registration');
const { eraseFixtureAccount } = require('./account-grace');

/**
 * Phone change smoke (V1 checklist 4.14), through the HTTP stack: a code
 * goes to the new number, a number another account uses is refused, the
 * right code moves the account, every old session ends, and the account
 * signs in with the new number only.
 */

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const TEST_PASSWORD = 'SmokeTest123!';
const phoneSeed = Number(`${Date.now()}`.slice(-8));

let passed = 0;
let failed = 0;

function phone(offset) {
  return `+9677${String((phoneSeed + offset) % 100000000).padStart(8, '0')}`;
}

function check(label, condition) {
  if (condition) {
    passed++;
    console.log(`PASS - ${label}`);
  } else {
    failed++;
    console.log(`FAIL - ${label}`);
  }
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
      { hostname: url.hostname, port: url.port, path: `${url.pathname}${url.search}`, method, headers },
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
  const response = await registerVerified(request, { name, phone: value, password: TEST_PASSWORD });
  check(`${name} registration succeeds`, response.status === 201);
  return response.body?.accessToken;
}

async function run() {
  console.log('\nPhone Change Smoke Report');
  console.log(`Target: ${BASE_URL}\n`);

  const oldPhone = phone(41);
  const takenPhone = phone(42);
  const newPhone = phone(43);
  let movedToken = await register('Phone mover', oldPhone);
  const otherToken = await register('Phone holder', takenPhone);
  try {
    // RA-BE-21: the request said «PHONE_IN_USE» before any code, so a session
    // learnt whether any number has an account for the price of a call. A
    // taken number is now asked like any other; only whoever holds it (and
    // reads its code) hears that it is taken, at the confirm.
    const taken = await request('POST', '/api/v1/auth/phone-change/request', { phone: takenPhone }, movedToken);
    const unknown = await request('POST', '/api/v1/auth/phone-change/request', { phone: phone(44) }, movedToken);
    check(
      'a taken number is asked like any other, its code sent',
      taken.status === 200 && unknown.status === 200 && taken.body?.phone === takenPhone,
    );
    const takenCode = process.env.SMOKE_OTP_CODE ?? taken.body?.code;
    const takenConfirm = await request('POST', '/api/v1/auth/phone-change/confirm', { phone: takenPhone, code: takenCode }, movedToken);
    check(
      'its code then says the number is taken, and moves nothing',
      takenConfirm.status === 409 && takenConfirm.body?.code === 'PHONE_IN_USE',
    );

    const same = await request('POST', '/api/v1/auth/phone-change/request', { phone: oldPhone }, movedToken);
    check('the account\'s own number is refused', same.status === 400 && same.body?.code === 'PHONE_UNCHANGED');

    const requested = await request('POST', '/api/v1/auth/phone-change/request', { phone: newPhone }, movedToken);
    check('a code goes to the new number', requested.status === 200 && requested.body?.phone === newPhone);
    const code = process.env.SMOKE_OTP_CODE ?? requested.body?.code;

    const wrong = await request('POST', '/api/v1/auth/phone-change/confirm', { phone: newPhone, code: '000000' === code ? '111111' : '000000' }, movedToken);
    check('a wrong code changes nothing', wrong.status >= 400 && wrong.status < 500);

    const confirmed = await request('POST', '/api/v1/auth/phone-change/confirm', { phone: newPhone, code }, movedToken);
    check('the right code moves the account', confirmed.status === 200 && confirmed.body?.changed === true);

    const oldSession = await request('GET', '/api/v1/auth/me', null, movedToken);
    check('every old session ends', oldSession.status === 401);

    const oldLogin = await request('POST', '/api/v1/auth/login', { phone: oldPhone, password: TEST_PASSWORD });
    check('the old number no longer signs in', oldLogin.status === 401 || oldLogin.status === 400);

    const newLogin = await request('POST', '/api/v1/auth/login', { phone: newPhone, password: TEST_PASSWORD });
    check('the new number signs in with the same password', newLogin.status === 200 && typeof newLogin.body?.accessToken === 'string');
    movedToken = newLogin.body?.accessToken ?? movedToken;
    check('the account now shows the new number', newLogin.body?.user?.phone === newPhone);
  } finally {
    for (const [label, token] of [['mover', movedToken], ['holder', otherToken]]) {
      if (!token) continue;
      check(`${label} fixture account is cleaned`, await eraseFixtureAccount(request, token));
    }
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Phone change smoke error:', error.message);
  process.exit(1);
});
