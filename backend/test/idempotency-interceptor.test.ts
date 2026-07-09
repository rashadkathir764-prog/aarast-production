import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import type { CallHandler, ExecutionContext } from "@nestjs/common";
import { ServiceUnavailableException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { Observable, defer, firstValueFrom, from, of } from "rxjs";
import { IdempotencyInterceptor } from "../src/common/idempotency/idempotency.interceptor";

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

type Row = {
  userId: string;
  key: string;
  method: string;
  path: string;
  response: unknown;
  completedAt: Date | null;
  createdAt: Date;
};

const known = (code: string) =>
  new Prisma.PrismaClientKnownRequestError(code, {
    code,
    clientVersion: "test",
  });

const unwrap = (value: unknown): unknown =>
  value === Prisma.DbNull || value === Prisma.JsonNull ? null : value;

/**
 * In-memory stand-in for the IdempotencyKey table. `create` enforces the
 * unique `(userId,key)` index atomically — the has/set pair runs with no await
 * between them, so concurrent creates serialize exactly like Postgres does.
 */
class FakeIdempotencyStore {
  private readonly rows = new Map<string, Row>();
  private id(userId: string, key: string) {
    return `${userId}::${key}`;
  }

  readonly idempotencyKey = {
    create: async ({ data }: { data: any }) => {
      const id = this.id(data.userId, data.key);
      if (this.rows.has(id)) throw known("P2002");
      this.rows.set(id, {
        userId: data.userId,
        key: data.key,
        method: data.method,
        path: data.path,
        response: unwrap(data.response),
        completedAt: null,
        createdAt: new Date(),
      });
    },
    findUnique: async ({ where }: { where: any }) => {
      const { userId, key } = where.userId_key;
      return this.rows.get(this.id(userId, key)) ?? null;
    },
    update: async ({ where, data }: { where: any; data: any }) => {
      const { userId, key } = where.userId_key;
      const row = this.rows.get(this.id(userId, key));
      if (!row) throw known("P2025");
      if ("response" in data) row.response = unwrap(data.response);
      if ("completedAt" in data) row.completedAt = data.completedAt;
      return row;
    },
    delete: async ({ where }: { where: any }) => {
      const { userId, key } = where.userId_key;
      if (!this.rows.delete(this.id(userId, key))) throw known("P2025");
    },
  };
}

const context = (
  userId: string,
  key: string | undefined,
  method = "POST",
): ExecutionContext =>
  ({
    switchToHttp: () => ({
      getRequest: () => ({
        method,
        path: "/expenses",
        headers: key ? { "x-client-request-id": key } : {},
        user: { id: userId },
      }),
    }),
  }) as unknown as ExecutionContext;

const handler = (
  run: () => Observable<unknown>,
): CallHandler => ({ handle: run }) as CallHandler;

test("concurrent same-key requests execute the mutation exactly once", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  let executions = 0;
  const response = { id: "expense-1", amount: "100.00" };
  const next = handler(() =>
    defer(() => {
      executions++;
      return from(delay(30).then(() => response));
    }),
  );

  const results = await Promise.all(
    Array.from({ length: 8 }, () =>
      firstValueFrom(interceptor.intercept(context("u1", "req-1"), next)),
    ),
  );

  assert.equal(executions, 1, "the mutation must run exactly once");
  for (const result of results) assert.deepEqual(result, response);
});

test("a later retry after completion replays instead of re-executing", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  let executions = 0;
  const response = { id: "debt-9" };
  const next = handler(() =>
    defer(() => {
      executions++;
      return of(response);
    }),
  );

  const first = await firstValueFrom(
    interceptor.intercept(context("u1", "req-2"), next),
  );
  const replay = await firstValueFrom(
    interceptor.intercept(context("u1", "req-2"), next),
  );

  assert.equal(executions, 1);
  assert.deepEqual(first, response);
  assert.deepEqual(replay, response);
});

test("a failed mutation is not cached — the key is released for retry", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  let attempts = 0;
  const next = handler(() =>
    defer(() => {
      attempts++;
      if (attempts === 1) {
        return from(Promise.reject(new Error("boom")));
      }
      return of({ id: "ok" });
    }),
  );

  await assert.rejects(
    () => firstValueFrom(interceptor.intercept(context("u1", "req-3"), next)),
    /boom/,
  );

  // The reservation was released, so the retry runs the work rather than
  // replaying the failure or stalling on a pending row.
  const retried = await firstValueFrom(
    interceptor.intercept(context("u1", "req-3"), next),
  );
  assert.equal(attempts, 2);
  assert.deepEqual(retried, { id: "ok" });
});

test("requests without a key or user, and non-mutating methods, are passed through", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  let executions = 0;
  const next = handler(() =>
    defer(() => {
      executions++;
      return of({ ok: true });
    }),
  );

  // No idempotency header.
  await firstValueFrom(
    interceptor.intercept(context("u1", undefined), next),
  );
  // GET is never guarded even with a key.
  await firstValueFrom(
    interceptor.intercept(context("u1", "req-4", "GET"), next),
  );

  assert.equal(executions, 2);
});

test("a handler still returns its response when its reservation row vanished mid-flight", async () => {
  // Account deletion removes this user's idempotency keys inside the same
  // request, so complete() hits P2025 — the response must still be served.
  const interceptor = new IdempotencyInterceptor({
    idempotencyKey: {
      create: async () => {},
      update: async () => {
        throw known("P2025");
      },
    },
  } as any);
  const response = { deleted: true };
  const next = handler(() => of(response));

  const result = await firstValueFrom(
    interceptor.intercept(context("u1", "req-6"), next),
  );
  assert.deepEqual(result, response);
});

test("an in-flight owner that never completes fails with a retryable 503", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  // Pre-seed a reserved-but-never-completed row (as a crashed owner would
  // leave behind), so the loser exhausts its poll budget.
  await store.idempotencyKey.create({
    data: {
      userId: "u1",
      key: "req-5",
      method: "POST",
      path: "/expenses",
      response: Prisma.DbNull,
    },
  });

  const next = handler(() => of({ id: "never" }));

  await assert.rejects(
    () => firstValueFrom(interceptor.intercept(context("u1", "req-5"), next)),
    (error: unknown) => error instanceof ServiceUnavailableException,
  );
});
