#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');
const { eraseFixtureAccount } = require('./account-grace');

/**
 * Planning assistant smoke (V1 checklist 4.12), through the HTTP stack and a
 * real database, against a local stand-in for the Claude API (the runner
 * points ANTHROPIC_BASE_URL at it; no real key, no real call). It proves:
 * consent is required; only the plan's owner and partner may ask; what the
 * model receives is the plan as the asker sees it (never the other side's
 * private costs or tasks); the daily limit holds; a busy model gives the
 * question back; and the usage rows leave with the account.
 */

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const MODEL_PORT = Number(process.env.SMOKE_ASSISTANT_MODEL_PORT);
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

// The stand-in for the Claude API: records each request; answers, or says
// it is overloaded while `overloaded` is set.
const modelCalls = [];
let overloaded = false;
function startModelStandIn() {
  const server = http.createServer((req, res) => {
    let raw = '';
    req.on('data', (chunk) => { raw += chunk; });
    req.on('end', () => {
      const body = raw ? JSON.parse(raw) : {};
      modelCalls.push({ path: req.url, headers: req.headers, body });
      res.setHeader('Content-Type', 'application/json');
      if (overloaded) {
        res.statusCode = 529;
        res.end(JSON.stringify({ type: 'error', error: { type: 'overloaded_error', message: 'Overloaded' } }));
        return;
      }
      res.end(JSON.stringify({
        id: `msg_${modelCalls.length}`,
        type: 'message',
        role: 'assistant',
        model: body.model,
        content: [{ type: 'text', text: 'خطة تجريبية من المساعد' }],
        stop_reason: 'end_turn',
        stop_sequence: null,
        usage: {
          input_tokens: 1200,
          output_tokens: 300,
          cache_read_input_tokens: 0,
          cache_creation_input_tokens: 0,
        },
      }));
    });
  });
  return new Promise((resolve) => server.listen(MODEL_PORT, '127.0.0.1', () => resolve(server)));
}

async function register(name, value) {
  const response = await registerVerified(request, { name, phone: value, password: TEST_PASSWORD });
  check(`${name} registration succeeds`, response.status === 201);
  return { token: response.body?.accessToken, userId: response.body?.user?.id };
}

const ALL_PERMISSIONS = {
  canViewMoney: true,
  canManageMoney: true,
  canManageTasks: true,
  canManageGuests: true,
  canManageProviders: true,
};

async function join(planId, owner, member, role) {
  const invite = await request('POST', `/api/v1/wedding-plans/${planId}/invites`, {
    userId: member.userId, role, expiresInDays: 7, ...ALL_PERMISSIONS,
  }, owner.token);
  const accepted = await request('POST', `/api/v1/invites/${invite.body?.token}/accept`, null, member.token);
  check(`${role} joins the plan`, accepted.status === 201);
}

const lastUserText = () => {
  const call = modelCalls[modelCalls.length - 1];
  const content = call?.body?.messages?.[0]?.content;
  return typeof content === 'string' ? content : '';
};

async function run() {
  console.log('Planning Assistant Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  if (!Number.isInteger(MODEL_PORT) || MODEL_PORT <= 0) {
    throw new Error('SMOKE_ASSISTANT_MODEL_PORT is not set by the smoke runner');
  }
  const modelServer = await startModelStandIn();

  const owner = await register('Assistant owner', phone(71));
  const bride = await register('Assistant bride', phone(72));
  const family = await register('Assistant family', phone(73));
  try {
    const plan = await request('POST', '/api/v1/wedding-plans', { title: 'Assistant plan', city: 'صنعاء' }, owner.token);
    const planId = plan.body?.id;
    const clientId = randomUUID();
    const budget = await request('PUT', `/api/v1/wedding-plans/${planId}/money-budget`, {
      totalBudget: '20000', currency: 'YER',
      categories: [{ clientId, name: 'Hall', allocatedAmount: '9000' }],
    }, owner.token);
    const categoryId = budget.body?.idMap?.[clientId];
    await request('POST', `/api/v1/wedding-plans/${planId}/costs`, { budgetCategoryId: categoryId, title: 'Owner hall', totalAmount: '3000' }, owner.token);
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, { title: 'Book the hall' }, owner.token);
    await join(planId, owner, bride, 'BRIDE');
    await join(planId, owner, family, 'FAMILY');
    await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: categoryId, title: 'Bride secret gift', totalAmount: '700', isPrivate: true,
    }, bride.token);
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, { title: 'Bride secret errand', isPrivate: true }, bride.token);

    const path = `/api/v1/wedding-plans/${planId}/assistant`;
    const ownerStatus = await request('GET', path, null, owner.token);
    check(
      'the owner sees the assistant on, with today\'s questions',
      ownerStatus.status === 200 && ownerStatus.body?.enabled === true && ownerStatus.body?.allowed === true
        && ownerStatus.body?.dailyLimit === 2 && ownerStatus.body?.remainingToday === 2,
    );
    const familyStatus = await request('GET', path, null, family.token);
    check('a relative is told the assistant is not theirs', familyStatus.status === 200 && familyStatus.body?.allowed === false);
    const familyAsk = await request('POST', `${path}/questions`, { kind: 'PLAN', consent: true }, family.token);
    check('a relative cannot ask', familyAsk.status === 403 && familyAsk.body?.code === 'ASSISTANT_OWNER_OR_PARTNER_ONLY');
    const noConsent = await request('POST', `${path}/questions`, { kind: 'PLAN', consent: false }, owner.token);
    check('nothing is sent without consent', noConsent.status === 400 && noConsent.body?.code === 'ASSISTANT_CONSENT_REQUIRED' && modelCalls.length === 0);
    const badKind = await request('POST', `${path}/questions`, { kind: 'WEATHER', consent: true }, owner.token);
    check('an unknown request kind is refused', badKind.status === 400 && modelCalls.length === 0);

    const first = await request('POST', `${path}/questions`, { kind: 'BUDGET_SPLIT', consent: true }, owner.token);
    check('the owner gets an answer', first.status === 200 && first.body?.answer === 'خطة تجريبية من المساعد' && first.body?.declined === false);
    check('the answer counts one question', first.body?.remainingToday === 1);
    const call = modelCalls[0];
    check('the model is the configured one', call?.body?.model === 'claude-opus-5-5' && call?.path === '/v1/messages?beta=true');
    check('the safety fallback is on', String(call?.headers?.['anthropic-beta'] ?? '').includes('server-side-fallback-2026-07-01') && call?.body?.fallbacks === 'default');
    check('the rules are sent as the system prompt', JSON.stringify(call?.body?.system ?? '').includes('لا تخترع أسعارًا'));
    const ownerText = lastUserText();
    check('the model sees the owner\'s plan', ownerText.includes('بند Hall') && ownerText.includes('Book the hall') && ownerText.includes('المدينة: صنعاء'));
    check('the model never sees the partner\'s private cost or task', !ownerText.includes('Bride secret gift') && !ownerText.includes('Bride secret errand'));
    check('the owner\'s figures leave the private cost out', ownerText.includes('الملتزم به من ميزانية العرس: 3000.00'));

    const second = await request('POST', `${path}/questions`, { kind: 'QUESTION', question: 'كم أخصص للتصوير؟', consent: true }, owner.token);
    check('a second question is answered', second.status === 200 && second.body?.remainingToday === 0);
    check('the user\'s own question reaches the model', lastUserText().includes('كم أخصص للتصوير؟'));
    const callsBefore = modelCalls.length;
    const third = await request('POST', `${path}/questions`, { kind: 'PLAN', consent: true }, owner.token);
    check('the daily limit holds', third.status === 429 && third.body?.code === 'ASSISTANT_DAILY_LIMIT' && modelCalls.length === callsBefore);

    const brideAsk = await request('POST', `${path}/questions`, { kind: 'FORGOTTEN', consent: true }, bride.token);
    check('the partner gets an answer', brideAsk.status === 200 && brideAsk.body?.remainingToday === 1);
    const brideText = lastUserText();
    check('the partner\'s own private cost and task reach her answer', brideText.includes('الملتزم به من ميزانية العرس: 3700.00') && brideText.includes('Bride secret errand'));

    overloaded = true;
    const busy = await request('POST', `${path}/questions`, { kind: 'CHEAPER', consent: true }, bride.token);
    overloaded = false;
    check('a busy model is said plainly', busy.status === 503 && busy.body?.code === 'ASSISTANT_BUSY');
    const brideStatus = await request('GET', path, null, bride.token);
    check('the busy question is given back', brideStatus.body?.remainingToday === 1);
  } finally {
    for (const [label, account] of [['family', family], ['bride', bride], ['owner', owner]]) {
      if (!account.token) continue;
      check(
        `${label} fixture account is cleaned (with its assistant usage)`,
        await eraseFixtureAccount(request, account.token),
      );
    }
    modelServer.close();
  }

  console.log(`Overall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Planning assistant smoke error:', error.message);
  process.exit(1);
});
