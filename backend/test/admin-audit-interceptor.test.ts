import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { CallHandler, ExecutionContext } from '@nestjs/common';
import { BadRequestException } from '@nestjs/common';
import { AdminAuditPhase, AdminRole, UserRole } from '@prisma/client';
import { AsyncResource } from 'node:async_hooks';
import { defer, firstValueFrom, from, of, throwError } from 'rxjs';
import { AdminAuditInterceptor } from '../src/admin/admin-audit.interceptor';
import { recordAdminAuditChange } from '../src/modules/backoffice/public/admin-audit-change';

function fixture() {
  const rows: any[] = [];
  const auditLog = {
    append: async (data: any) => {
      rows.push(data);
    },
  };
  return { rows, interceptor: new AdminAuditInterceptor(auditLog as any) };
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
    append: async () => {
      throw new Error('audit unavailable');
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

// RA-AD-23: the log kept the route, not the decision. The reason the admin
// typed and what the action changed are kept now, on the action's rows.
function nestLikeHandler(run: () => Promise<unknown>): CallHandler {
  // Nest binds the handler to the async context `handle()` is called in.
  return { handle: () => defer(AsyncResource.bind(() => from(run()))) } as CallHandler;
}

test('the reason given and what the mutation changed are written with the action', async () => {
  const { rows, interceptor } = fixture();
  const next = nestLikeHandler(async () => {
    await new Promise((resolve) => setImmediate(resolve));
    recordAdminAuditChange({ status: 'ACTIVE' }, { status: 'SUSPENDED' });
    return { ok: true };
  });

  await firstValueFrom(
    interceptor.intercept(
      context({
        route: { path: '/providers/:id/suspend' },
        body: { reason: '  كلام غير لائق مع العرسان  ', secretBody: 'never audited' },
      }),
      next,
    ),
  );

  assert.equal(rows.length, 2);
  assert.equal(rows[0].reason, 'كلام غير لائق مع العرسان');
  assert.equal('before' in rows[0], false);
  assert.equal(rows[1].phase, AdminAuditPhase.SUCCEEDED);
  assert.equal(rows[1].reason, 'كلام غير لائق مع العرسان');
  assert.deepEqual(rows[1].before, { status: 'ACTIVE' });
  assert.deepEqual(rows[1].after, { status: 'SUSPENDED' });
  assert.equal(JSON.stringify(rows).includes('never audited'), false);
});

test('a note stands for the reason; a failed action keeps the reason and no change', async () => {
  const { rows, interceptor } = fixture();
  const next = nestLikeHandler(async () => {
    recordAdminAuditChange({ status: 'PENDING' }, { status: 'REJECTED' });
    throw new BadRequestException('refused');
  });

  await assert.rejects(() =>
    firstValueFrom(interceptor.intercept(context({ body: { note: 'الهوية ناقصة' } }), next)),
  );

  assert.equal(rows[1].phase, AdminAuditPhase.FAILED);
  assert.equal(rows[1].reason, 'الهوية ناقصة');
  assert.equal('before' in rows[1], false);
  assert.equal('after' in rows[1], false);
});

test('a long reason is kept to its first 2000 characters; a non-text one is not kept', async () => {
  const { rows, interceptor } = fixture();
  await firstValueFrom(
    interceptor.intercept(context({ body: { reason: 'س'.repeat(2500) } }), nestLikeHandler(async () => ({}))),
  );
  assert.equal(rows[0].reason.length, 2000);

  const other = fixture();
  await firstValueFrom(
    other.interceptor.intercept(context({ body: { reason: { nested: true } } }), nestLikeHandler(async () => ({}))),
  );
  assert.equal(other.rows[0].reason, null);
});

test('recording outside an audited request changes nothing', () => {
  assert.doesNotThrow(() => recordAdminAuditChange({ status: 'A' }, { status: 'B' }));
});
