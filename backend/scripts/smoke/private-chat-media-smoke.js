#!/usr/bin/env node
'use strict';

const { configureSmokeDatabaseUrl, requireResponseId } = require('./smoke-utils');

configureSmokeDatabaseUrl();

const http = require('http');
const { PrismaClient } = require('@prisma/client');
const { registerVerified } = require('./verified-registration');

const prisma = new PrismaClient();
const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const suffix = `${Date.now().toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const PASSWORD = 'SmokeTest123!';
const users = [];
let providerId;
let passed = 0;
let failed = 0;

function check(label, condition) {
  console.log(`${condition ? 'PASS' : 'FAIL'} - ${label}`);
  if (condition) passed += 1;
  else failed += 1;
}

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === undefined ? undefined : JSON.stringify(body);
    const headers = {
      'Content-Type': 'application/json',
      'X-Forwarded-For': '198.18.1.40',
    };
    if (token) headers.Authorization = `Bearer ${token}`;
    if (payload) headers['Content-Length'] = Buffer.byteLength(payload);
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
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve({
              status: res.statusCode,
              headers: res.headers,
              body: data ? JSON.parse(data) : null,
            });
          } catch {
            resolve({ status: res.statusCode, headers: res.headers, body: data });
          }
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function register(name, prefix) {
  const phone = `+967${prefix}${suffix}`;
  const response = await registerVerified(request, {
    name,
    phone,
    password: PASSWORD,
  });
  check(`${name} verified registration`, response.status === 201);
  if (response.body?.user?.id) users.push(response.body.user.id);
  return { ...response.body, phone };
}

function hasStorageKey(value) {
  if (Array.isArray(value)) return value.some(hasStorageKey);
  if (!value || typeof value !== 'object') return false;
  return Object.entries(value).some(
    ([key, nested]) => key === 'storageKey' || hasStorageKey(nested),
  );
}

async function run() {
  console.log('\nPrivate Chat Media Smoke Report');
  console.log(`Target: ${BASE_URL}\n`);
  try {
    const requester = await register('Private Media Requester', '71');
    const providerUser = await register('Private Media Provider', '72');
    const stranger = await register('Private Media Stranger', '73');

    const city = await prisma.city.upsert({
      where: {
        nameAr_countryCode: { nameAr: 'مدينة اختبار الوسائط', countryCode: 'YE' },
      },
      create: {
        nameAr: 'مدينة اختبار الوسائط',
        nameEn: 'Private Media Smoke City',
        countryCode: 'YE',
        isActive: true,
      },
      update: { isActive: true },
    });
    const provider = await prisma.provider.create({
      data: {
        userId: providerUser.user.id,
        cityId: city.id,
        businessName: 'مزود اختبار الوسائط الخاصة',
        phone: providerUser.phone,
        status: 'ACTIVE',
      },
    });
    providerId = provider.id;
    const quote = await prisma.quoteRequest.create({
      data: {
        userId: requester.user.id,
        providerId: provider.id,
        message: 'Private chat media smoke',
      },
    });

    const ensured = await request(
      'POST',
      `/conversations/quote-requests/${quote.id}`,
      {},
      requester.accessToken,
    );
    check('requester creates quote conversation', ensured.status === 201);
    const conversationId = requireResponseId('quote conversation', ensured);

    const ticket = await request(
      'POST',
      '/media/uploads/presign',
      {
        purpose: 'chat-image',
        fileName: 'private.webp',
        contentType: 'image/webp',
        byteSize: 2048,
      },
      requester.accessToken,
    );
    check('chat upload presign succeeds', ticket.status === 201);
    check('chat upload returns no public URL', ticket.body?.publicUrl === null);
    check(
      'chat upload returns opaque owned reference',
      typeof ticket.body?.attachmentRef === 'string' &&
        ticket.body.attachmentRef.startsWith(`chat-image/${requester.user.id}/`),
    );

    const publicPayload = await request(
      'POST',
      `/conversations/${conversationId}/messages`,
      {
        body: 'must reject public URL',
        attachments: [
          {
            url: 'https://cdn.example.test/chat-image/public.webp',
            contentType: 'image/webp',
            byteSize: 2048,
          },
        ],
      },
      requester.accessToken,
    );
    check('message rejects a public attachment URL', publicPayload.status === 400);

    const sent = await request(
      'POST',
      `/conversations/${conversationId}/messages`,
      {
        body: 'private image',
        attachments: [
          {
            attachmentRef: ticket.body.attachmentRef,
            contentType: 'image/webp',
            byteSize: 2048,
          },
        ],
      },
      requester.accessToken,
    );
    check('owned private attachment message succeeds', sent.status === 201);
    const attachment = sent.body?.attachments?.[0];
    check(
      'message returns a 120-second signed GET',
      typeof attachment?.url === 'string' &&
        attachment.url.includes('X-Amz-Expires=120'),
    );
    check('message response hides storageKey', !hasStorageKey(sent.body));
    check(
      'message response is private and non-cacheable',
      sent.headers['cache-control'] === 'private, no-store',
    );

    const outsiderMessages = await request(
      'GET',
      `/conversations/${conversationId}/messages`,
      undefined,
      stranger.accessToken,
    );
    check('non-participant cannot enumerate attachments', outsiderMessages.status === 403);

    const providerMessages = await request(
      'GET',
      `/conversations/${conversationId}/messages`,
      undefined,
      providerUser.accessToken,
    );
    check('provider participant reads messages', providerMessages.status === 200);
    check('message list hides storageKey', !hasStorageKey(providerMessages.body));

    const attachmentId = attachment?.id;
    const outsiderRefresh = await request(
      'GET',
      `/conversations/${conversationId}/attachments/${attachmentId}/download`,
      undefined,
      stranger.accessToken,
    );
    check('non-participant cannot refresh a link', outsiderRefresh.status === 403);

    const memberRefresh = await request(
      'GET',
      `/conversations/${conversationId}/attachments/${attachmentId}/download`,
      undefined,
      providerUser.accessToken,
    );
    check('participant refreshes an attachment link', memberRefresh.status === 200);
    check('refreshed link expires in 120 seconds', memberRefresh.body?.expiresInSeconds === 120);
    check('refresh response hides storageKey', !hasStorageKey(memberRefresh.body));
  } finally {
    if (providerId) {
      await prisma.provider.deleteMany({ where: { id: providerId } });
    }
    if (users.length) {
      await prisma.user.deleteMany({ where: { id: { in: users } } });
    }
    await prisma.$disconnect();
  }

  console.log(`\nSummary: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch(async (error) => {
  console.error(error);
  await prisma.$disconnect();
  process.exit(1);
});
