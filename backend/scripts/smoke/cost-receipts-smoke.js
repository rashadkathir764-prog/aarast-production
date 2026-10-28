#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const { configureSmokeDatabaseUrl } = require('./smoke-utils');

configureSmokeDatabaseUrl();

const http = require('http');
const { randomUUID } = require('crypto');
const { PrismaClient } = require('@prisma/client');
const { registerVerified } = require('./verified-registration');
const {
  isPendingDeletion,
  purgePendingAccounts,
  requestAccountDeletion,
} = require('./account-grace');
const { uploadVerifiedImage } = require('./verified-media-upload');

/**
 * Cost receipts smoke (V1 checklist 4.4), through the HTTP stack with real
 * private media: a receipt photo is uploaded, attached to a cost, read
 * through a short-lived signed URL only by those who see the cost, keeps
 * the cost from being deleted, and its file is scheduled for deletion when
 * the receipt (or the owner's account) is deleted.
 */

const prisma = new PrismaClient();
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
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers,
      },
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
  const response = await registerVerified(request, {
    name,
    phone: value,
    password: TEST_PASSWORD,
  });
  check(`${name} registration succeeds`, response.status === 201);
  return { token: response.body?.accessToken, userId: response.body?.user?.id };
}

async function uploadReceipt(token) {
  const { verify } = await uploadVerifiedImage({ request, token, purpose: 'cost-receipt' });
  return verify;
}

async function run() {
  console.log('\nCost Receipts Smoke Report');
  console.log(`Target: ${BASE_URL}\n`);

  const owner = await register('Receipt owner', phone(31));
  const stranger = await register('Receipt stranger', phone(32));
  let ownerDeleted = false;
  try {
    const plan = await request('POST', '/api/v1/wedding-plans', { title: 'Receipts plan', city: 'Sanaa' }, owner.token);
    const planId = plan.body?.id;
    const categoryClientId = randomUUID();
    const budget = await request(
      'PUT',
      `/api/v1/wedding-plans/${planId}/money-budget`,
      { totalBudget: '1000', currency: 'YER', categories: [{ clientId: categoryClientId, name: 'Hall', allocatedAmount: '900' }] },
      owner.token,
    );
    const categoryId = budget.body?.idMap?.[categoryClientId];
    const cost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      { budgetCategoryId: categoryId, title: 'Hall agreement', totalAmount: '500' },
      owner.token,
    );
    const costId = cost.body?.id;
    if (!costId) throw new Error(`cost setup failed with HTTP ${cost.status}`);

    const verify = await uploadReceipt(owner.token);
    check(
      'a receipt upload is private (a reference, no public URL)',
      verify?.status === 201 && typeof verify.body?.attachmentRef === 'string' && verify.body?.publicUrl === null,
    );
    const attachmentRef = verify?.body?.attachmentRef;

    const added = await request('POST', `/api/v1/costs/${costId}/receipts`, { attachmentRef }, owner.token);
    check('the receipt is kept with the cost', added.status === 201 && typeof added.body?.downloadUrl === 'string');
    const receiptId = added.body?.id;

    const file = await fetch(added.body?.downloadUrl);
    check(
      'the signed URL serves the photo, not cached publicly',
      file.status === 200 && file.headers.get('cache-control') === 'private, no-store',
    );

    const reused = await request('POST', `/api/v1/costs/${costId}/receipts`, { attachmentRef }, owner.token);
    check('the same upload cannot be attached twice', reused.status >= 400 && reused.status < 500);

    const listed = await request('GET', `/api/v1/costs/${costId}/receipts`, null, owner.token);
    check('the owner lists the receipt', listed.status === 200 && listed.body?.length === 1);
    const hidden = await request('GET', `/api/v1/costs/${costId}/receipts`, null, stranger.token);
    check('someone outside the plan cannot see it', hidden.status === 404 || hidden.status === 403);

    const deleteCost = await request('DELETE', `/api/v1/costs/${costId}`, null, owner.token);
    check('a cost with receipts is not deleted', deleteCost.status === 409 && deleteCost.body?.code === 'COST_HAS_RECEIPTS');

    const removed = await request('DELETE', `/api/v1/costs/${costId}/receipts/${receiptId}`, null, owner.token);
    check('the receipt is deleted', removed.status === 200 && removed.body?.deleted === true);
    const ticket = await prisma.mediaUploadTicket.findUnique({ where: { key: attachmentRef } });
    check('its file is scheduled for deletion', ticket?.status === 'DELETE_PENDING' || ticket?.status === 'DELETED');

    const second = await uploadReceipt(owner.token);
    const kept = await request('POST', `/api/v1/costs/${costId}/receipts`, { attachmentRef: second?.body?.attachmentRef }, owner.token);
    check('a second receipt is kept for the account-deletion check', kept.status === 201);

    const deletion = await requestAccountDeletion(request, owner.token);
    check('the owner asks to delete their account', isPendingDeletion(deletion));
    const purge = await purgePendingAccounts();
    ownerDeleted =
      purge.failures.length === 0 &&
      (await prisma.user.count({ where: { id: owner.userId } })) === 0;
    check('after the 30 days the purge erases the account', ownerDeleted);
    const rows = await prisma.costReceipt.count({ where: { id: kept.body?.id } });
    const secondTicket = await prisma.mediaUploadTicket.findUnique({ where: { key: second?.body?.attachmentRef } });
    check('account deletion removes the plan receipts', rows === 0);
    check(
      'and schedules their files for deletion',
      secondTicket === null || secondTicket.status === 'DELETE_PENDING' || secondTicket.status === 'DELETED',
    );
  } finally {
    const cleanups = [['stranger', stranger.token]];
    if (!ownerDeleted) cleanups.push(['owner', owner.token]);
    for (const [label, token] of cleanups) {
      if (!token) continue;
      const response = await requestAccountDeletion(request, token);
      check(`${label} fixture account asks to be deleted`, isPendingDeletion(response));
    }
    const cleanup = await purgePendingAccounts();
    check('the fixture accounts are erased', cleanup.failures.length === 0);
    await prisma.$disconnect();
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Cost receipts smoke error:', error.message);
  process.exit(1);
});
