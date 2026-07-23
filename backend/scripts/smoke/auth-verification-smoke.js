#!/usr/bin/env node
'use strict';

const http = require('node:http');
const { assertManagedSmokeEnvironment } = require('./smoke-utils');

assertManagedSmokeEnvironment(process.env);

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const suffix = `${Date.now().toString().slice(-7)}${Math.floor(Math.random() * 9)}`;
const TEST_PHONE = `+9677${suffix}`;
const TEST_PASSWORD = 'VerifiedSmoke123!';

let passed = 0;
let failed = 0;

function check(label, condition) {
  if (condition) {
    console.log(`PASS - ${label}`);
    passed += 1;
  } else {
    console.log(`FAIL - ${label}`);
    failed += 1;
  }
}

function request(method, path, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body ? JSON.stringify(body) : undefined;
    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers: { 'Content-Type': 'application/json' },
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
    if (payload) req.write(payload);
    req.end();
  });
}

async function run() {
  console.log('\nVerified Registration Security Smoke');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  const details = {
    name: 'Verified Registration Smoke',
    phone: TEST_PHONE,
    password: TEST_PASSWORD,
  };
  const pending = await request('POST', '/api/v1/auth/register', {
    name: details.name,
    phone: details.phone,
  });
  check('registration request is accepted as pending', pending.status === 201);
  check('pending response is explicit', pending.body?.registrationPending === true);
  check('pending response has no access token', pending.body?.accessToken === undefined);
  check('pending response has no refresh token', pending.body?.refreshToken === undefined);
  check('pending response has no user', pending.body?.user === undefined);

  const beforeVerification = await request('POST', '/api/v1/auth/login', {
    phone: TEST_PHONE,
    password: TEST_PASSWORD,
  });
  check('pending phone cannot log in', beforeVerification.status === 401);

  const wrong = await request('POST', '/api/v1/auth/register/complete', {
    ...details,
    otpCode: '999999',
  });
  check('wrong registration OTP is rejected', wrong.status === 400);
  check('wrong OTP returns no access token', wrong.body?.accessToken === undefined);

  const code = process.env.SMOKE_OTP_CODE ?? pending.body?.code;
  if (typeof code !== 'string') {
    throw new Error(
      'Security smoke needs SMOKE_OTP_CODE or a local dev OTP response',
    );
  }

  const completed = await request('POST', '/api/v1/auth/register/complete', {
    ...details,
    otpCode: code,
  });
  check('verified registration completes', completed.status === 201);
  check('verified registration returns access token', typeof completed.body?.accessToken === 'string');
  check('verified registration returns refresh token', typeof completed.body?.refreshToken === 'string');
  check('created user is phone verified', Boolean(completed.body?.user?.phoneVerifiedAt));

  const concurrentPhone = `+9676${suffix}`;
  const concurrentDetails = { ...details, phone: concurrentPhone };
  const concurrentPending = await request(
    'POST',
    '/api/v1/auth/register',
    {
      name: concurrentDetails.name,
      phone: concurrentDetails.phone,
    },
  );
  const concurrentRegistrationCode =
    process.env.SMOKE_OTP_CODE ?? concurrentPending.body?.code;
  if (typeof concurrentRegistrationCode !== 'string') {
    throw new Error(
      'Concurrent registration smoke needs SMOKE_OTP_CODE or a local dev OTP response',
    );
  }
  const concurrentRegistrations = await Promise.all([
    request('POST', '/api/v1/auth/register/complete', {
      ...concurrentDetails,
      otpCode: concurrentRegistrationCode,
    }),
    request('POST', '/api/v1/auth/register/complete', {
      ...concurrentDetails,
      otpCode: concurrentRegistrationCode,
    }),
  ]);
  check(
    'concurrent registration creates one account',
    concurrentRegistrations.filter((result) => result.status === 201).length === 1,
  );
  check(
    'concurrent registration rejects the replay without HTTP 500',
    concurrentRegistrations.filter((result) =>
      result.status === 400 || result.status === 409,
    ).length === 1,
  );

  const loginOtp = await request('POST', '/api/v1/auth/otp/request', {
    phone: TEST_PHONE,
    purpose: 'LOGIN',
  });
  const loginCode = process.env.SMOKE_OTP_CODE ?? loginOtp.body?.code;
  if (typeof loginCode !== 'string') {
    throw new Error(
      'Concurrency smoke needs SMOKE_OTP_CODE or a local dev OTP response',
    );
  }

  const concurrent = await Promise.all([
    request('POST', '/api/v1/auth/otp/verify', {
      phone: TEST_PHONE,
      purpose: 'LOGIN',
      code: loginCode,
    }),
    request('POST', '/api/v1/auth/otp/verify', {
      phone: TEST_PHONE,
      purpose: 'LOGIN',
      code: loginCode,
    }),
  ]);
  check(
    'concurrent OTP consumption has one success',
    concurrent.filter((result) => result.status === 200).length === 1,
  );
  check(
    'concurrent OTP consumption rejects the replay',
    concurrent.filter((result) => result.status === 400).length === 1,
  );

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Verified registration smoke error:', error.message);
  process.exit(1);
});
