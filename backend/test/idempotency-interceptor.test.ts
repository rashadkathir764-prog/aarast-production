import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import type { CallHandler, ExecutionContext } from "@nestjs/common";
import {
  BadRequestException,
  ConflictException,
  InternalServerErrorException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { Observable, defer, firstValueFrom, from, of } from "rxjs";
import {
  IdempotencyInterceptor,
  requestFingerprint,
} from "../src/common/idempotency/idempotency.interceptor";

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

type Row = {
  id: string;
  userId: string;
  key: string;
  method: string;
  path: string;
  requestHash: string;
  response: unknown;
  completedAt: Date | null;
  expiresAt: Date;
  createdAt: Date;
};

type TestResponse = {
  statusCode: number;
  status?: (code: number) => unknown;
  getHeader?: (name: string) => number | string | string[] | undefined;
  setHeader?: (name: string, value: number | string | string[]) => unknown;
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
  private sequence = 0;
  private id(userId: string, key: string) {
    return `${userId}::${key}`;
  }

  row(userId: string, key: string): Row | undefined {
    return this.rows.get(this.id(userId, key));
  }

  expire(userId: string, key: string): void {
    const row = this.row(userId, key);
    if (row) row.expiresAt = new Date(Date.now() - 1_000);
  }

  private rowForWhere(where: any): Row | undefined {
    if (where.id) {
      return [...this.rows.values()].find((row) => row.id === where.id);
    }
    const { userId, key } = where.userId_key;
    return this.row(userId, key);
  }

  readonly idempotencyKey = {
    create: async ({ data }: { data: any }) => {
      const id = this.id(data.userId, data.key);
      if (this.rows.has(id)) throw known("P2002");
      const row = {
        id: `reservation-${++this.sequence}`,
        userId: data.userId,
        key: data.key,
        method: data.method,
        path: data.path,
        requestHash: data.requestHash,
        response: unwrap(data.response),
        completedAt: null,
        expiresAt: data.expiresAt,
        createdAt: new Date(),
      };
      this.rows.set(id, row);
      return data.select ? { id: row.id } : row;
    },
    findUnique: async ({ where }: { where: any }) => {
      const { userId, key } = where.userId_key;
      return this.rows.get(this.id(userId, key)) ?? null;
    },
    update: async ({ where, data }: { where: any; data: any }) => {
      const row = this.rowForWhere(where);
      if (!row) throw known("P2025");
      if ("response" in data) row.response = unwrap(data.response);
      if ("completedAt" in data) row.completedAt = data.completedAt;
      if ("expiresAt" in data) row.expiresAt = data.expiresAt;
      return row;
    },
    delete: async ({ where }: { where: any }) => {
      const row = this.rowForWhere(where);
      if (!row || !this.rows.delete(this.id(row.userId, row.key))) {
        throw known("P2025");
      }
      return row;
    },
    deleteMany: async ({ where }: { where: any }) => {
      const row = this.rowForWhere(where);
      if (!row) return { count: 0 };
      const cutoff = where.expiresAt?.lte as Date | undefined;
      if (cutoff && row.expiresAt.getTime() > cutoff.getTime()) {
        return { count: 0 };
      }
      this.rows.delete(this.id(row.userId, row.key));
      return { count: 1 };
    },
  };
}

const context = (
  userId: string,
  key: string | undefined,
  method = "POST",
  options: {
    body?: unknown;
    routePath?: string;
    originalUrl?: string;
    baseUrl?: string;
    response?: TestResponse;
  } = {},
): ExecutionContext =>
  ({
    switchToHttp: () => ({
      getRequest: () => ({
        method,
        baseUrl: options.baseUrl,
        body: options.body,
        route: {
          path:
            options.routePath ??
            "/api/v1/wedding-plans/:weddingPlanId/costs",
        },
        originalUrl: options.originalUrl,
        headers: key ? { "x-client-request-id": key } : {},
        user: { id: userId },
      }),
      getResponse: () => options.response ?? { statusCode: 200 },
    }),
  }) as unknown as ExecutionContext;

const handler = (
  run: () => Observable<unknown>,
): CallHandler => ({ handle: run }) as CallHandler;

test("concurrent same-key requests execute the mutation exactly once", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  let executions = 0;
  const response = { id: "cost-1", totalAmount: "100.00" };
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
  const response = { id: "commitment-9" };
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

test("a replay restores the original HTTP status code with the response body", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  let executions = 0;
  const firstResponse = {
    statusCode: 202,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
  };
  const replayResponse = {
    statusCode: 200,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
  };
  const next = handler(() => {
    executions++;
    return of({ accepted: true });
  });

  await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-status", "POST", { response: firstResponse }),
      next,
    ),
  );
  const replay = await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-status", "POST", { response: replayResponse }),
      next,
    ),
  );

  assert.equal(executions, 1);
  assert.deepEqual(replay, { accepted: true });
  assert.equal(replayResponse.statusCode, 202);
});

test("a replay restores safe representation headers but never session headers", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  const originalHeaders = new Map<string, number | string | string[]>([
    ["location", "/api/v1/costs/cost-1"],
    ["content-type", "application/json; charset=utf-8"],
    ["content-language", "ar"],
    ["set-cookie", "refresh=secret; HttpOnly"],
  ]);
  const replayHeaders = new Map<string, number | string | string[]>();
  const firstResponse: TestResponse = {
    statusCode: 201,
    getHeader: (name) => originalHeaders.get(name.toLowerCase()),
  };
  const replayResponse: TestResponse = {
    statusCode: 200,
    setHeader: (name, value) => replayHeaders.set(name.toLowerCase(), value),
  };
  let executions = 0;
  const next = handler(() => {
    executions++;
    return of({ id: "cost-1" });
  });

  await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-safe-headers", "POST", { response: firstResponse }),
      next,
    ),
  );
  await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-safe-headers", "POST", { response: replayResponse }),
      next,
    ),
  );

  assert.equal(executions, 1);
  assert.equal(replayResponse.statusCode, 201);
  assert.equal(replayHeaders.get("location"), "/api/v1/costs/cost-1");
  assert.equal(
    replayHeaders.get("content-type"),
    "application/json; charset=utf-8",
  );
  assert.equal(replayHeaders.get("content-language"), "ar");
  assert.equal(replayHeaders.has("set-cookie"), false);
});

test("signed upload presign responses bypass replay storage and stay fresh", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  let executions = 0;
  const next = handler(() => {
    executions++;
    return of({ uploadUrl: `https://storage.example.test/signed-${executions}` });
  });
  const presignContext = () =>
    context("u1", "req-presign", "POST", {
      baseUrl: "/api/v1/media/uploads",
      routePath: "/presign",
      originalUrl: "/api/v1/media/uploads/presign",
    });

  const first = await firstValueFrom(
    interceptor.intercept(presignContext(), next),
  );
  const second = await firstValueFrom(
    interceptor.intercept(presignContext(), next),
  );

  assert.equal(executions, 2);
  assert.notDeepEqual(first, second);
  assert.equal(store.row("u1", "req-presign"), undefined);
});

test("one-time invite bearer responses bypass replay storage and are never persisted", async () => {
  for (const route of [
    {
      key: "req-invite-create",
      routePath: "/api/v1/wedding-plans/:weddingPlanId/invites",
      originalUrl: "/api/v1/wedding-plans/plan-1/invites",
    },
    {
      key: "req-invite-reissue",
      routePath:
        "/api/v1/wedding-plans/:weddingPlanId/invites/:inviteId/reissue",
      originalUrl:
        "/api/v1/wedding-plans/plan-1/invites/invite-1/reissue",
    },
  ]) {
    const store = new FakeIdempotencyStore();
    const interceptor = new IdempotencyInterceptor(store as any);
    let executions = 0;
    const next = handler(() => {
      executions++;
      return of({
        id: "invite-1",
        token: `raw-one-time-bearer-${executions}`,
      });
    });
    const inviteContext = () =>
      context("u1", route.key, "POST", {
        routePath: route.routePath,
        originalUrl: route.originalUrl,
      });

    const first = await firstValueFrom(
      interceptor.intercept(inviteContext(), next),
    );
    const second = await firstValueFrom(
      interceptor.intercept(inviteContext(), next),
    );

    assert.equal(executions, 2);
    assert.notDeepEqual(first, second);
    assert.equal(store.row("u1", route.key), undefined);
  }
});

test("expired signed URLs in durable mutation replays are never returned stale", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  let executions = 0;
  const next = handler(() => {
    executions++;
    return of({
      id: "message-1",
      attachments: [
        {
          id: "attachment-1",
          url: "https://storage.example.test/private-expired-signature",
          expiresAt: new Date(Date.now() + 5_000).toISOString(),
        },
      ],
    });
  });

  const first = await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-message-signed-url", "POST", {
        baseUrl: "/api/v1/conversations",
        routePath: "/:id/messages",
        originalUrl: "/api/v1/conversations/conversation-1/messages",
      }),
      next,
    ),
  );
  const replay = await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-message-signed-url", "POST", {
        baseUrl: "/api/v1/conversations",
        routePath: "/:id/messages",
        originalUrl: "/api/v1/conversations/conversation-1/messages",
      }),
      next,
    ),
  );

  assert.equal(executions, 1);
  assert.equal((first as any).attachments[0].url.length > 0, true);
  assert.equal((replay as any).attachments[0].id, "attachment-1");
  assert.equal((replay as any).attachments[0].url, "");
});

test("canonical request fingerprints ignore JSON and query key ordering", () => {
  const first = requestFingerprint({
    method: "POST",
    originalUrl:
      "/api/v1/wedding-plans/p1/costs?currency=YER&status=OPEN",
    body: { amount: 100, metadata: { note: "x", category: "hall" } },
  });
  const reordered = requestFingerprint({
    method: "POST",
    originalUrl:
      "/api/v1/wedding-plans/p1/costs?status=OPEN&currency=YER",
    body: { metadata: { category: "hall", note: "x" }, amount: 100 },
  });

  assert.equal(first, reordered);
  assert.match(first, /^[a-f0-9]{64}$/);
});

test("reusing a live key for a different body is rejected with 409", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  let executions = 0;
  const next = handler(() => {
    executions++;
    return of({ id: `cost-${executions}` });
  });

  await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-bound-body", "POST", { body: { amount: 100 } }),
      next,
    ),
  );

  await assert.rejects(
    () =>
      firstValueFrom(
        interceptor.intercept(
          context("u1", "req-bound-body", "POST", { body: { amount: 200 } }),
          next,
        ),
      ),
    (error: unknown) => error instanceof ConflictException,
  );
  assert.equal(executions, 1);
});

test("reusing a key for a different concrete route target is rejected", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  let executions = 0;
  const next = handler(() => {
    executions++;
    return of({ accepted: true });
  });
  const route = "/invites/:token/accept";

  await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-bound-target", "POST", {
        routePath: route,
        originalUrl: "/invites/token-a/accept",
      }),
      next,
    ),
  );
  await assert.rejects(
    () =>
      firstValueFrom(
        interceptor.intercept(
          context("u1", "req-bound-target", "POST", {
            routePath: route,
            originalUrl: "/invites/token-b/accept",
          }),
          next,
        ),
      ),
    (error: unknown) => error instanceof ConflictException,
  );
  assert.equal(executions, 1);
});

test("an expired completed key can be safely reused", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  let executions = 0;
  const next = handler(() => {
    executions++;
    return of({ execution: executions });
  });

  await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-expired", "POST", { body: { amount: 100 } }),
      next,
    ),
  );
  const firstReservationId = store.row("u1", "req-expired")?.id;
  store.expire("u1", "req-expired");
  const result = await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-expired", "POST", { body: { amount: 200 } }),
      next,
    ),
  );

  assert.deepEqual(result, { execution: 2 });
  assert.equal(executions, 2);
  assert.notEqual(store.row("u1", "req-expired")?.id, firstReservationId);
});

test("a completed response receives a finite replay expiry", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  await firstValueFrom(
    interceptor.intercept(
      context("u1", "req-expiry"),
      handler(() => of({ ok: true })),
    ),
  );

  const row = store.row("u1", "req-expiry");
  assert.ok(row?.completedAt);
  assert.ok(row.expiresAt.getTime() > Date.now() + 6 * 24 * 60 * 60 * 1_000);
  assert.ok(row.expiresAt.getTime() < Date.now() + 8 * 24 * 60 * 60 * 1_000);
});

test("a validation 4xx releases the reservation for a corrected retry", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  let attempts = 0;
  const next = handler(() =>
    defer(() => {
      attempts++;
      if (attempts === 1) {
        return from(Promise.reject(new BadRequestException("invalid input")));
      }
      return of({ id: "ok" });
    }),
  );

  await assert.rejects(
    () => firstValueFrom(interceptor.intercept(context("u1", "req-3"), next)),
    (error: unknown) => error instanceof BadRequestException,
  );

  // The reservation was released, so the retry runs the work rather than
  // replaying the failure or stalling on a pending row.
  const retried = await firstValueFrom(
    interceptor.intercept(context("u1", "req-3"), next),
  );
  assert.equal(attempts, 2);
  assert.deepEqual(retried, { id: "ok" });
});

test("an unknown handler error retains an ambiguous reservation", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  (interceptor as any).delay = async () => {};
  let executions = 0;

  await assert.rejects(
    () =>
      firstValueFrom(
        interceptor.intercept(
          context("u1", "req-unknown-error"),
          handler(() => {
            executions++;
            return from(Promise.reject(new Error("ambiguous failure")));
          }),
        ),
      ),
    /ambiguous failure/,
  );
  const reservationId = store.row("u1", "req-unknown-error")?.id;
  assert.ok(reservationId);

  await assert.rejects(
    () =>
      firstValueFrom(
        interceptor.intercept(
          context("u1", "req-unknown-error"),
          handler(() => {
            executions++;
            return of({ duplicated: true });
          }),
        ),
      ),
    (error: unknown) => error instanceof ServiceUnavailableException,
  );
  assert.equal(executions, 1);
  assert.equal(store.row("u1", "req-unknown-error")?.id, reservationId);
});

test("a 5xx handler error retains an ambiguous reservation", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  await assert.rejects(
    () =>
      firstValueFrom(
        interceptor.intercept(
          context("u1", "req-5xx-error"),
          handler(() =>
            from(Promise.reject(new InternalServerErrorException("failed"))),
          ),
        ),
      ),
    (error: unknown) => error instanceof InternalServerErrorException,
  );

  assert.ok(store.row("u1", "req-5xx-error"));
});

test("Prisma P2034 rollback releases the reservation for a safe retry", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  let attempts = 0;
  const next = handler(() => {
    attempts++;
    return attempts === 1
      ? from(Promise.reject(known("P2034")))
      : of({ retried: true });
  });

  await assert.rejects(() =>
    firstValueFrom(
      interceptor.intercept(context("u1", "req-prisma-rollback"), next),
    ),
  );
  const retried = await firstValueFrom(
    interceptor.intercept(context("u1", "req-prisma-rollback"), next),
  );

  assert.equal(attempts, 2);
  assert.deepEqual(retried, { retried: true });
});

test("an ambiguous Prisma transaction API failure retains the reservation", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);

  await assert.rejects(() =>
    firstValueFrom(
      interceptor.intercept(
        context("u1", "req-prisma-ambiguous"),
        handler(() => from(Promise.reject(known("P2028")))),
      ),
    ),
  );

  assert.ok(store.row("u1", "req-prisma-ambiguous"));
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

test("unsafe client ids are ignored instead of stored as idempotency keys", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  let executions = 0;
  const next = handler(() => {
    executions++;
    return of({ ok: true });
  });

  await firstValueFrom(
    interceptor.intercept(context("u1", "safe\nforged-log-line"), next),
  );
  await firstValueFrom(
    interceptor.intercept(context("u1", "safe\nforged-log-line"), next),
  );

  assert.equal(executions, 2);
});

test("idempotency rows store route templates instead of invite bearer tokens", async () => {
  let storedPath = "";
  let storedHash = "";
  const interceptor = new IdempotencyInterceptor({
    idempotencyKey: {
      create: async ({ data }: { data: { path: string; requestHash: string } }) => {
        storedPath = data.path;
        storedHash = data.requestHash;
        return { id: "reservation-safe-path" };
      },
      update: async () => ({}),
    },
  } as any);
  const inviteContext = {
    switchToHttp: () => ({
      getRequest: () => ({
        method: "POST",
        baseUrl: "/api/v1",
        route: { path: "/invites/:token/accept" },
        originalUrl: "/api/v1/invites/raw-bearer-secret/accept",
        headers: { "x-client-request-id": "req-safe-1" },
        user: { id: "u1" },
      }),
      getResponse: () => ({ statusCode: 201 }),
    }),
  } as unknown as ExecutionContext;

  await firstValueFrom(
    interceptor.intercept(inviteContext, handler(() => of({ accepted: true }))),
  );

  assert.equal(storedPath, "/api/v1/invites/:token/accept");
  assert.equal(storedPath.includes("raw-bearer-secret"), false);
  assert.match(storedHash, /^[a-f0-9]{64}$/);
  assert.equal(storedHash.includes("raw-bearer-secret"), false);
});

test("a handler still returns its response when its reservation row vanished mid-flight", async () => {
  // Account deletion removes this user's idempotency keys inside the same
  // request, so complete() hits P2025 — the response must still be served.
  const interceptor = new IdempotencyInterceptor({
    idempotencyKey: {
      create: async () => ({ id: "reservation-deleted-account" }),
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

test("a response-store failure retains the reservation instead of risking duplicate work", async () => {
  let releaseCalls = 0;
  const interceptor = new IdempotencyInterceptor({
    idempotencyKey: {
      create: async () => ({ id: "reservation-store-failure" }),
      update: async () => {
        throw new Error("response store unavailable");
      },
      delete: async () => {
        releaseCalls++;
      },
    },
  } as any);
  let executions = 0;

  await assert.rejects(
    () =>
      firstValueFrom(
        interceptor.intercept(
          context("u1", "req-store-failure"),
          handler(() => {
            executions++;
            return of({ committed: true });
          }),
        ),
      ),
    /response store unavailable/,
  );

  assert.equal(executions, 1);
  assert.equal(releaseCalls, 0);
});

test("an expired in-flight reservation is never deleted or re-executed", async () => {
  const store = new FakeIdempotencyStore();
  const interceptor = new IdempotencyInterceptor(store as any);
  (interceptor as any).delay = async () => {};

  await store.idempotencyKey.create({
    data: {
      userId: "u1",
      key: "req-ambiguous-expired",
      method: "POST",
      path: "/api/v1/wedding-plans/:weddingPlanId/costs",
      requestHash: requestFingerprint({
        method: "POST",
        route: { path: "/api/v1/wedding-plans/:weddingPlanId/costs" },
      }),
      expiresAt: new Date(Date.now() - 60_000),
      response: Prisma.DbNull,
    },
  });
  const reservationId = store.row("u1", "req-ambiguous-expired")?.id;
  let executions = 0;

  await assert.rejects(
    () =>
      firstValueFrom(
        interceptor.intercept(
          context("u1", "req-ambiguous-expired"),
          handler(() => {
            executions++;
            return of({ duplicated: true });
          }),
        ),
      ),
    (error: unknown) => error instanceof ServiceUnavailableException,
  );

  assert.equal(executions, 0);
  assert.equal(store.row("u1", "req-ambiguous-expired")?.id, reservationId);
  assert.equal(store.row("u1", "req-ambiguous-expired")?.completedAt, null);
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
      path: "/api/v1/wedding-plans/:weddingPlanId/costs",
      requestHash: requestFingerprint({
        method: "POST",
        route: { path: "/api/v1/wedding-plans/:weddingPlanId/costs" },
      }),
      expiresAt: new Date(Date.now() + 60 * 60 * 1_000),
      response: Prisma.DbNull,
    },
  });

  const next = handler(() => of({ id: "never" }));

  await assert.rejects(
    () => firstValueFrom(interceptor.intercept(context("u1", "req-5"), next)),
    (error: unknown) => error instanceof ServiceUnavailableException,
  );
});
