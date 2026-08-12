import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  requestRouteTemplate,
  safeClientRequestId,
  sanitizeRequestTarget,
} from '../src/platform/observability/sanitize-request-target';

test('request targets redact invite tokens and sensitive query values', () => {
  const result = sanitizeRequestTarget(
    '/api/v1/invites/super-secret-token/accept?phone=%2B967777123456&next=%2Fhome',
  );
  assert.equal(
    result,
    '/api/v1/invites/:token/accept?phone=REDACTED&next=%2Fhome',
  );
  assert.equal(result.includes('super-secret-token'), false);
  assert.equal(result.includes('967777123456'), false);
});

test('ordinary operational paths remain useful in logs', () => {
  assert.equal(
    sanitizeRequestTarget('/api/v1/wedding-plans/plan-1/tasks?take=20'),
    '/api/v1/wedding-plans/plan-1/tasks?take=20',
  );
});

test('access telemetry uses route templates and drops query strings', () => {
  assert.equal(
    requestRouteTemplate({
      baseUrl: '/api/v1',
      route: { path: '/invites/:token/accept' },
      originalUrl: '/api/v1/invites/raw-secret/accept?phone=%2B967777123456',
    }),
    '/api/v1/invites/:token/accept',
  );
  assert.equal(
    requestRouteTemplate({ originalUrl: '/unknown/raw-secret?token=secret' }),
    'unmatched',
  );
});

test('client request ids reject log injection and oversized input', () => {
  assert.equal(safeClientRequestId('mobile.abc-123:retry_1'), 'mobile.abc-123:retry_1');
  assert.equal(safeClientRequestId('safe\nforged-log-line'), undefined);
  assert.equal(safeClientRequestId(`x${'a'.repeat(128)}`), undefined);
});
