import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { CallHandler, ExecutionContext } from '@nestjs/common';
import { BadRequestException } from '@nestjs/common';
import { AdminAuditPhase, AdminRole, UserRole } from '@prisma/client';
import { firstValueFrom, of, throwError } from 'rxjs';
import { AdminAuditInterceptor } from '../src/admin/admin-audit.interceptor';

function fixture() {
  const rows: any[] = [];
  const prisma = {
    adminAuditLog: {
      create: async ({ data }: { data: any }) => {
        rows.push(data);
        return data;
      },
    },
  };
  return { rows, interceptor: new AdminAuditInterceptor(prisma as any) };
}

function context(overrides: Record<string, unknown> = {}): ExecutionContext {
  const request = {
    method: 'PATCH',
    baseUrl: '/admin',
    route: { path: '/providers/:id/approve' },
    params: { id: 'provider-safe-id' },
    requestId: 'request-safe-1',
    user: {
      id: 'admin-1',
      role: UserRole.ADMIN,
      adminRole: AdminRole.OPERATIONS,
    },
    ...overrides,
  };
  return {
    switchToHttp: () => ({
      getRequest: () => request,
      getResponse: () => ({ statusCode: 200 }),
    }),
  } as unknown as ExecutionContext;
}

test('successful admin mutation writes ATTEMPT then SUCCEEDED without bodies', async () => {
  const { rows, interceptor } = fixture();
  const next = { handle: () => of({ secretBody: 'never audited' }) } as CallHandler;

  const result = await firstValueFrom(interceptor.intercept(context(), next));

  assert.deepEqual(result, { secretBody: 'never audited' });
  assert.equal(rows.length, 2);
  assert.equal(rows[0].phase, AdminAuditPhase.ATTEMPT);
  assert.equal(rows[1].phase, AdminAuditPhase.SUCCEEDED);
  assert.equal(rows[0].eventId, rows[1].eventId);
  assert.equal(rows[0].route, '/admin/providers/:id/approve');
  assert.equal(rows[0].targetId, 'provider-safe-id');
  assert.equal(JSON.stringify(rows).includes('secretBody'), false);
});

test('failed mutation stores only a safe error class and status', async () => {
  const { rows, interceptor } = fixture();
  const next = {
    handle: () =>
      throwError(() => new BadRequestException('sensitive request detail')),
  } as CallHandler;

  await assert.rejects(() => firstValueFrom(interceptor.intercept(context(), next)));

  assert.equal(rows.length, 2);
  assert.equal(rows[1].phase, AdminAuditPhase.FAILED);
  assert.equal(rows[1].statusCode, 400);
  assert.equal(rows[1].errorType, 'BadRequestException');
  assert.equal(JSON.stringify(rows).includes('sensitive request detail'), false);
});

test('audit ATTEMPT failure blocks the privileged mutation', async () => {
  let executions = 0;
  const interceptor = new AdminAuditInterceptor({
    adminAuditLog: {
      create: async () => {
        throw new Error('audit unavailable');
      },
    },
  } as any);
  const next = {
    handle: () => {
      executions++;
      return of({ ok: true });
    },
  } as CallHandler;

  await assert.rejects(() => firstValueFrom(interceptor.intercept(context(), next)));
  assert.equal(executions, 0);
});

test('non-admin route bypasses audit storage', async () => {
  const { rows, interceptor } = fixture();
  const next = { handle: () => of({ ok: true }) } as CallHandler;

  await firstValueFrom(
    interceptor.intercept(
      context({ baseUrl: '/wedding-plans', route: { path: '/:id' } }),
      next,
    ),
  );
  assert.equal(rows.length, 0);
});
