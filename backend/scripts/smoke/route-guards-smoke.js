#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const fs = require('fs');
const http = require('http');
const path = require('path');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');
const { eraseFixtureAccount } = require('./account-grace');

/**
 * RA-BE-07: every server route, from the routes table docs-sync generates
 * from the controllers (docs/backend/API_CONTRACT.md, kept current by the
 * docs-sync --check gate), through the HTTP stack on an isolated database:
 * - a guarded route (🔒) refuses a request without a session: 401;
 * - an account outside a plan gets no 2xx from any route of that plan;
 * - an application account gets no 2xx from an admin route;
 * - no route answers a malformed id or token with a server error (5xx),
 *   since the phone's queue retries 5xx as if it were a passing fault; the
 *   malformed value carries a NUL (`%00`), which PostgreSQL cannot store
 *   (RA-BE-13);
 * - a NUL inside the text of a write is removed, and the write is kept.
 * Routes without a parameter are only asked without a session: with one,
 * a route like account deletion would act on the fixture account itself.
 */

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const TEST_PASSWORD = 'SmokeTest123!';
const phoneSeed = Number(`${Date.now()}`.slice(-8));
const CONTRACT = path.resolve(__dirname, '..', '..', '..', 'docs', 'backend', 'API_CONTRACT.md');

let passed = 0;
let failed = 0;
const failures = [];

function phone(offset) {
  return `+9677${String((phoneSeed + offset) % 100000000).padStart(8, '0')}`;
}

function check(label, condition) {
  if (condition) {
    passed++;
  } else {
    failed++;
    failures.push(label);
    console.log(`FAIL - ${label}`);
  }
}

// One benchmark-range client address per request: the walk is ~900
// requests and must not read the global per-address limit as a refusal.
let clientCounter = 0;
function nextClientIp() {
  clientCounter++;
  return `198.19.${Math.floor(clientCounter / 250) % 250}.${(clientCounter % 250) + 1}`;
}

function request(method, routePath, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(routePath, BASE_URL);
    const payload = body === undefined || body === null ? null : JSON.stringify(body);
    const headers = { Accept: 'application/json', 'X-Forwarded-For': nextClientIp() };
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload);
    }
    if (token) headers.Authorization = `Bearer ${token}`;
    const req = http.request(
      { hostname: url.hostname, port: url.port, path: `${url.pathname}${url.search}`, method, headers },
      (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          let parsed = null;
          try { parsed = data ? JSON.parse(data) : null; } catch { parsed = data; }
          resolve({ status: res.statusCode ?? 0, body: parsed });
        });
      },
    );
    req.on('error', reject);
    req.setTimeout(30_000, () => req.destroy(new Error(`timeout ${method} ${routePath}`)));
    if (payload) req.write(payload);
    req.end();
  });
}

/** The generated routes table: method, path, guarded. */
function readRoutes() {
  const rows = fs.readFileSync(CONTRACT, 'utf8').split(/\r?\n/);
  const routes = [];
  for (const row of rows) {
    const match = /^\| (GET|POST|PUT|PATCH|DELETE) \| `([^`]+)` \| `[^`]*` \| (🔒)? \|$/u.exec(row.trim());
    if (match) routes.push({ method: match[1], path: match[2], guarded: match[3] === '🔒' });
  }
  return routes;
}

const PLAN_PARAMS = new Set(['weddingPlanId', 'planId']);

function fill(routePath, values) {
  return routePath.replace(/:([A-Za-z]+)/g, (_, name) => encodeURIComponent(values(name)));
}

function hasParams(routePath) {
  return /:[A-Za-z]+/.test(routePath);
}

async function register(name, value) {
  const response = await registerVerified(request, { name, phone: value, password: TEST_PASSWORD });
  check(`${name} registration succeeds`, response.status === 201);
  return { token: response.body?.accessToken, userId: response.body?.user?.id };
}

async function run() {
  console.log('Route Guards Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  const routes = readRoutes();
  check('the routes table lists the server routes', routes.length > 250);
  console.log(`Routes: ${routes.length} (${routes.filter((route) => route.guarded).length} guarded)`);

  const owner = await register('Route owner', phone(81));
  const outsider = await register('Route outsider', phone(82));
  try {
    const plan = await request('POST', '/api/v1/wedding-plans', { title: 'Route guard plan', city: 'صنعاء' }, owner.token);
    check('the owner makes a plan', plan.status === 201 && typeof plan.body?.id === 'string');
    const planId = plan.body?.id;

    // Controls: the refusals below mean what they say only if a public
    // route answers without a session, the plan exists for its owner, and
    // the outsider's own session is good.
    const publicRead = await request('GET', '/api/v1/cities', null, null);
    check('control: a public route answers without a session', publicRead.status === 200);
    const ownerRead = await request('GET', `/api/v1/wedding-plans/${planId}`, null, owner.token);
    check('control: the owner reads the plan', ownerRead.status === 200);
    const outsiderSelf = await request('GET', '/api/v1/users/me/settings', null, outsider.token);
    check('control: the outsider session is good', outsiderSelf.status === 200);

    const outsiderStatuses = new Map();
    let unauthenticated = 0;
    let outsiderProbes = 0;
    let adminProbes = 0;
    let malformedProbes = 0;
    for (const route of routes) {
      const label = `${route.method} ${route.path}`;
      const body = route.method === 'GET' || route.method === 'DELETE' ? null : {};

      if (route.guarded) {
        const anonymous = await request(route.method, fill(route.path, () => randomUUID()), body, null);
        check(`${label} refuses a request without a session (401, got ${anonymous.status})`, anonymous.status === 401);
        unauthenticated++;
      }
      if (!hasParams(route.path)) continue;

      const isPlanRoute = /:(weddingPlanId|planId)\b/.test(route.path);
      if (isPlanRoute && route.guarded) {
        const foreign = await request(
          route.method,
          fill(route.path, (name) => (PLAN_PARAMS.has(name) ? planId : randomUUID())),
          body,
          outsider.token,
        );
        check(
          `${label} gives an outsider nothing of another's plan (got ${foreign.status})`,
          foreign.status >= 400 && foreign.status < 500,
        );
        outsiderStatuses.set(foreign.status, (outsiderStatuses.get(foreign.status) ?? 0) + 1);
        outsiderProbes++;
      }
      if (route.path.startsWith('/admin/')) {
        const asApp = await request(route.method, fill(route.path, () => randomUUID()), body, outsider.token);
        check(
          `${label} refuses an application account (got ${asApp.status})`,
          asApp.status === 401 || asApp.status === 403,
        );
        adminProbes++;
        continue;
      }
      const malformed = await request(
        route.method,
        fill(route.path, () => "not-an-id'%\u0000"),
        body,
        route.guarded ? outsider.token : null,
      );
      check(
        `${label} answers a malformed id without a server error (got ${malformed.status})`,
        malformed.status > 0 && malformed.status < 500,
      );
      malformedProbes++;
    }
    console.log(
      `Probes: ${unauthenticated} without a session, ${outsiderProbes} outsider, ${adminProbes} admin, ${malformedProbes} malformed`,
    );
    console.log(
      `Outsider refusals by status: ${[...outsiderStatuses].map(([status, count]) => `${status}×${count}`).join(', ')}`,
    );

    // RA-BE-13: the owner's own writes, with a NUL inside the text a phone
    // could carry (a pasted name, a contact). Each is kept, without it.
    const guest = await request('POST', `/api/v1/wedding-plans/${planId}/guests`, { name: 'Ahmed\u0000 Ali', notes: 'x\u0000y' }, owner.token);
    check(`a guest with a NUL in its name is kept (got ${guest.status})`, guest.status === 201);
    check('the guest name is stored without the NUL', guest.body?.name === 'Ahmed Ali' && guest.body?.notes === 'xy');
    const task = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, { title: 'مهمة\u0000 أولى' }, owner.token);
    check(`a task with a NUL in its title is kept (got ${task.status})`, task.status === 201 && task.body?.title === 'مهمة أولى');
    const renamed = await request('PATCH', `/api/v1/wedding-plans/${planId}`, { title: 'عرس\u0000 تجربة' }, owner.token);
    check(`a plan title with a NUL is kept (got ${renamed.status})`, renamed.status === 200 && renamed.body?.title === 'عرس تجربة');
    const search = await request('GET', `/api/v1/wedding-plans/${planId}/guests?search=${encodeURIComponent('Ahmed\u0000')}`, null, owner.token);
    check(`a search with a NUL answers without a server error (got ${search.status})`, search.status > 0 && search.status < 500);

    // RA-BE-14: a number past the database column's range is refused by
    // validation (400), not by the database (500).
    const group = await request('POST', `/api/v1/wedding-plans/${planId}/guest-groups`, { name: 'مجموعة', sortOrder: 3000000000 }, owner.token);
    check(`an oversized group order is a 400 (got ${group.status})`, group.status === 400);
    const deepPage = await request('GET', `/api/v1/wedding-plans/${planId}/guests?skip=100000000000000000000`, null, owner.token);
    check(`an oversized page offset is a 400 (got ${deepPage.status})`, deepPage.status === 400);
    const step = task.body?.id
      ? await request('POST', `/api/v1/tasks/${task.body.id}/checklist`, { title: 'خطوة', sortOrder: 3000000000 }, owner.token)
      : { status: 0 };
    check(`an oversized step order is a 400 (got ${step.status})`, step.status === 400);
  } finally {
    for (const [label, account] of [['outsider', outsider], ['owner', owner]]) {
      if (!account.token) continue;
      check(`${label} fixture account is cleaned`, await eraseFixtureAccount(request, account.token));
    }
  }

  console.log(`Overall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Route guards smoke error:', error.message);
  process.exit(1);
});
