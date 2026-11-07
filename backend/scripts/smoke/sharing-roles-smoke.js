#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const { registerVerified } = require('./verified-registration');

/**
 * Sharing Roles APIs Smoke Test
 * Covers /api/v1 members, invite tokens, role permissions, and revoke flow.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-4)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+96750${suffix}`;
const EDITOR_PHONE = `+96751${suffix}`;
const HELPER_PHONE = `+96752${suffix}`;
const OUTSIDER_PHONE = `+96753${suffix}`;
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

async function register(name, phone) {
  const res = await registerVerified(request, {
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
  console.log('\nSharing Roles APIs Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Editor phone: ${EDITOR_PHONE}`);
  console.log(`Helper phone: ${HELPER_PHONE}`);
  console.log(`Outsider phone: ${OUTSIDER_PHONE}\n`);

  const owner = await register('Roles Owner', OWNER_PHONE);
  const editor = await register('Roles Editor', EDITOR_PHONE);
  const helper = await register('Roles Helper', HELPER_PHONE);
  const outsider = await register('Roles Outsider', OUTSIDER_PHONE);

  let planId = null;
  let editorInviteToken = null;
  let helperInviteToken = null;
  let editorMemberId = null;
  let helperMemberId = null;

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Sharing Roles Plan',
      city: 'Sanaa',
      estimatedBudget: '500000.00',
    }, owner.token);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    check('created plan has id', typeof res.body?.id === 'string');
    planId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/permissions/me`, null, owner.token);
    check('owner permissions - HTTP 200', res.status === 200);
    check('owner role is OWNER', res.body?.role === 'OWNER');
    check('owner can manage members', res.body?.canManageMembers === true);
    check('owner permissions do not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/invites`, {
      // RA-BE-33: an invite goes by number.
      phone: editor.user.phone,
      role: 'EDITOR',
      expiresInDays: 7,
    }, owner.token);
    check('owner creates editor invite - HTTP 201', res.status === 201);
    check('editor invite has token', typeof res.body?.token === 'string');
    check('editor invite status is PENDING', res.body?.status === 'PENDING');
    check('editor invite role is EDITOR', res.body?.role === 'EDITOR');
    check('editor invite does not expose passwordHash', !hasPasswordHash(res.body));
    editorInviteToken = res.body?.token;
  }

  {
    const res = await request('GET', `/api/v1/invites/${editorInviteToken}`);
    check('invite preview without token returns 401', res.status === 401);
  }

  {
    const res = await request('GET', `/api/v1/invites/${editorInviteToken}`, null, outsider.token);
    check('wrong user cannot preview targeted invite', res.status === 404);
  }

  {
    const res = await request('GET', `/api/v1/invites/${editorInviteToken}`, null, editor.token);
    check('targeted invite preview - HTTP 200', res.status === 200);
    check('targeted invite preview has plan title', res.body?.weddingPlan?.title === 'Sharing Roles Plan');
    check('targeted invite preview status is PENDING', res.body?.status === 'PENDING');
    check('targeted invite preview does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/invites/${editorInviteToken}/accept`, null, outsider.token);
    check('wrong user cannot accept targeted invite', res.status === 404);
  }

  {
    const res = await request('POST', `/api/v1/invites/${editorInviteToken}/accept`, null, editor.token);
    check('editor accepts invite - HTTP 201', res.status === 201);
    check('accepted invite status is ACCEPTED', res.body?.invite?.status === 'ACCEPTED');
    check('accepted member role is EDITOR', res.body?.member?.role === 'EDITOR');
    check('accepted member has id', typeof res.body?.member?.id === 'string');
    check('accept response does not expose passwordHash', !hasPasswordHash(res.body));
    editorMemberId = res.body?.member?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/permissions/me`, null, editor.token);
    check('editor permissions - HTTP 200', res.status === 200);
    check('editor can manage plan', res.body?.canManagePlan === true);
    check('editor can manage tasks', res.body?.canManageTasks === true);
    check('editor cannot view money by default', res.body?.canViewMoney === false);
    check('editor cannot manage money by default', res.body?.canManageMoney === false);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/members`, null, owner.token);
    check('owner lists /api/v1 members - HTTP 200', res.status === 200);
    check('member list includes virtual owner', Array.isArray(res.body) && res.body.some((member) => member.role === 'OWNER' && member.isOwner === true));
    check('member list includes editor', Array.isArray(res.body) && res.body.some((member) => member.id === editorMemberId));
    check('member list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/api/v1/wedding-plans/${planId}/members/${editorMemberId}`, {
      role: 'FINANCE_MANAGER',
    }, owner.token);
    check('owner updates editor to finance manager - HTTP 200', res.status === 200);
    check('finance role updated', res.body?.role === 'FINANCE_MANAGER');
    check('role-only update preserves stored money read denial', res.body?.canViewMoney === false);
    check('role-only update preserves stored money write denial', res.body?.canManageMoney === false);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Role Only Must Stay Denied',
      allocatedAmount: '100000.00',
    }, editor.token);
    // RA-BE-40: a member's refused write says why (403); 404 «the plan was
    // not found» told a member their plan was gone.
    check(
      'role-only finance update cannot create a budget category',
      res.status === 403 && res.body?.code === 'SECTION_PERMISSION_MISSING',
    );
  }

  {
    const res = await request('PATCH', `/api/v1/wedding-plans/${planId}/members/${editorMemberId}`, {
      canViewMoney: true,
      canManageMoney: true,
    }, owner.token);
    check('owner explicitly grants finance permissions - HTTP 200', res.status === 200);
    check('explicit finance read permission is stored', res.body?.canViewMoney === true);
    check('explicit finance write permission is stored', res.body?.canManageMoney === true);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Explicit Finance Grant',
      allocatedAmount: '100000.00',
    }, editor.token);
    check('explicitly authorized finance manager can create a budget category', res.status === 201);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/invites`, {
      phone: HELPER_PHONE,
      role: 'HELPER',
    }, owner.token);
    check('owner creates helper invite by phone - HTTP 201', res.status === 201);
    check('helper invite has token', typeof res.body?.token === 'string');
    check('helper invite role is HELPER', res.body?.role === 'HELPER');
    helperInviteToken = res.body?.token;
  }

  {
    const res = await request('POST', `/api/v1/invites/${helperInviteToken}/accept`, null, helper.token);
    check('helper accepts invite - HTTP 201', res.status === 201);
    check('helper member role is HELPER', res.body?.member?.role === 'HELPER');
    helperMemberId = res.body?.member?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/permissions/me`, null, helper.token);
    check('helper permissions - HTTP 200', res.status === 200);
    check('helper can manage guests', res.body?.canManageGuests === true);
    check('helper cannot manage plan', res.body?.canManagePlan === false);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/guests`, {
      name: 'Helper Managed Guest',
      phone: '+967700200001',
    }, helper.token);
    check('helper can create guest', res.status === 201);
  }

  {
    const res = await request('PATCH', `/api/v1/wedding-plans/${planId}`, {
      title: 'Helper Should Not Rename',
    }, helper.token);
    // RA-BE-40: refused with its reason, as above.
    check(
      'helper cannot update plan',
      res.status === 403 && res.body?.code === 'SECTION_PERMISSION_MISSING',
    );
  }

  {
    const res = await request('DELETE', `/api/v1/wedding-plans/${planId}/members/owner:${owner.user.id}`, null, owner.token);
    check('owner cannot remove last owner', res.status === 400);
  }

  {
    const res = await request('DELETE', `/api/v1/wedding-plans/${planId}/members/${helperMemberId}`, null, owner.token);
    check('owner revokes helper - HTTP 200', res.status === 200);
    check('helper revoke returns id', res.body?.id === helperMemberId);
  }

  {
    const res = await request('DELETE', `/api/v1/wedding-plans/${planId}/members/${editorMemberId}`, null, owner.token);
    check('owner revokes finance member - HTTP 200', res.status === 200);
    check('finance revoke returns id', res.body?.id === editorMemberId);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/permissions/me`, null, editor.token);
    check('revoked member cannot read permissions', res.status === 404);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/members`);
    check('members without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Sharing roles smoke error:', err.message);
  process.exit(1);
});
