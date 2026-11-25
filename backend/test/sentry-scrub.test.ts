import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Event } from '@sentry/node';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  scrubSentryBreadcrumb,
  scrubSentryEvent,
} from '../src/platform/observability/sentry-scrub';

// RA-BE-149: whatever an event carries (an error's message, a breadcrumb, the
// request the SDK attached, a context), no phone number, token, name or
// amount leaves the server for Sentry.

const jwt =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTEiLCJwaG9uZSI6Ijc3NzEyMzQ1NiJ9.c2lnbmF0dXJlLXZhbHVlLWhlcmU';

function serialized(value: unknown): string {
  return JSON.stringify(value);
}

test('phones, tokens and amounts are taken out of every text of an event', () => {
  const event = scrubSentryEvent({
    message: 'payment of 1,500,000 by +967 777 123 456 failed',
    exception: {
      values: [
        {
          type: 'Error',
          value: `refresh ${'a'.repeat(64)} for 967777123456 with Bearer ${jwt}; total ٢٥٠٠٠٠`,
          stacktrace: { frames: [{ filename: 'x.ts', vars: { name: 'سلمان', phone: '777123456' } }] },
        },
      ],
    },
    breadcrumbs: [{ message: `GET /api/v1/public/rsvp/${'B'.repeat(43)} amount 250000` }],
    tags: { route: 'POST /api/v1/costs', status: '500' },
  } as Event);
  const text = serialized(event);
  for (const leaked of ['1,500,000', '777 123 456', '967777123456', 'a'.repeat(64), jwt, '٢٥٠٠٠٠', 'B'.repeat(43), '250000', 'سلمان', '777123456']) {
    assert.equal(text.includes(leaked), false, `${leaked} must not leave`);
  }
  // What helps reading the error stays: its type, the route, the status.
  assert.match(text, /payment of \[number\] by \[number\] failed/);
  assert.equal(event?.exception?.values?.[0]?.type, 'Error');
  assert.deepEqual(event?.tags, { route: 'POST /api/v1/costs', status: '500' });
});

test('the request the SDK attached keeps its method and route only, and the user goes', () => {
  const event = scrubSentryEvent({
    user: { id: 'user-1', username: 'سلمان', ip_address: '198.51.100.7' },
    server_name: 'ip-10-0-0-1',
    request: {
      method: 'POST',
      url: 'https://api.example/api/v1/auth/login?phone=777123456&token=abc',
      query_string: 'phone=777123456',
      data: { phone: '777123456', password: 'secret12', name: 'سلمان' },
      cookies: { session: 'x' },
      headers: { authorization: `Bearer ${jwt}`, 'user-agent': 'okhttp', cookie: 'a=b' },
    },
  } as Event);
  assert.equal(event?.user, undefined);
  assert.equal(event?.server_name, undefined);
  assert.deepEqual(event?.request, { method: 'POST', url: '/api/v1/auth/login' });
});

test('a context or extra keeps its shape, with personal fields and amounts taken out', () => {
  const event = scrubSentryEvent({
    extra: { guestName: 'سلمان', totalAmount: 2500000, phoneNumber: '777123456', count: 3, nested: { accessToken: jwt, note: 'plan 1234567 ok' } },
    contexts: { app: { app_name: 'aarast-backend' }, plan: { title: 'عرس سلمان', budget: 900000 } },
  } as Event);
  assert.deepEqual(event?.extra, {
    guestName: '[redacted]',
    totalAmount: '[redacted]',
    phoneNumber: '[redacted]',
    count: 3,
    nested: { accessToken: '[redacted]', note: 'plan [number] ok' },
  });
  assert.deepEqual(event?.contexts?.app, { app_name: 'aarast-backend' });
  assert.deepEqual(event?.contexts?.plan, { title: '[redacted]', budget: '[redacted]' });
});

test('a breadcrumb is scrubbed the same way before it is kept', () => {
  const breadcrumb = scrubSentryBreadcrumb({
    category: 'http',
    message: 'call to 777123456',
    data: { url: `https://openwa/api/sessions/s/messages?phone=967777123456`, status_code: 200, phone: '777123456' },
  });
  assert.equal(serialized(breadcrumb).includes('777123456'), false);
  assert.equal(breadcrumb?.data?.status_code, 200);
  assert.equal(breadcrumb?.category, 'http');
});

test('the server hands every event, transaction and breadcrumb to the scrubber', () => {
  const main = readFileSync(join(__dirname, '..', 'src', 'main.ts'), 'utf8');
  const init = /Sentry\.init\(\{([\s\S]*?)\}\);/.exec(main)?.[1] ?? '';
  assert.match(init, /beforeSend: scrubSentryEvent,/);
  assert.match(init, /beforeSendTransaction: scrubSentryEvent,/);
  assert.match(init, /beforeBreadcrumb: scrubSentryBreadcrumb,/);
  assert.match(init, /sendDefaultPii: false,/);
});
