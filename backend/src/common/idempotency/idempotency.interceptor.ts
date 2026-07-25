import {
  CallHandler,
  ConflictException,
  ExecutionContext,
  HttpException,
  Injectable,
  NestInterceptor,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import { Prisma } from '@prisma/client';
import {
  Observable,
  catchError,
  from,
  of,
  switchMap,
  throwError,
} from 'rxjs';
import { PrismaService } from '../../prisma/prisma.service';
import {
  requestRouteTemplate,
  safeClientRequestId,
} from '../observability/sanitize-request-target';

interface RequestLike {
  baseUrl?: string;
  body?: unknown;
  method?: string;
  originalUrl?: string;
  route?: { path?: unknown };
  url?: string;
  headers?: Record<string, string | string[] | undefined>;
  user?: { id?: string };
}

interface ResponseLike {
  statusCode?: number;
  status?: (code: number) => unknown;
  getHeader?: (name: string) => number | string | string[] | undefined;
  setHeader?: (
    name: string,
    value: number | string | readonly string[],
  ) => unknown;
}

type ReplayHeaders = Record<string, string | string[]>;

export interface ReplayMetadata {
  statusCode?: number;
  headers?: ReplayHeaders;
}

const IDEMPOTENCY_HEADER = 'x-client-request-id';
const MUTATING_METHODS = new Set(['POST', 'PATCH', 'PUT', 'DELETE']);
const STORED_RESPONSE_MARKER = '__aarastIdempotencyResponseV1';
const SIGNED_URL_REPLAY_SAFETY_MS = 10_000;
const TRANSIENT_URL_KEYS = ['url', 'downloadUrl', 'uploadUrl'] as const;
const SAFE_REPLAY_HEADERS = [
  'location',
  'content-type',
  'content-language',
] as const;

// A request that loses the reservation race polls the winner's row until it is
// completed, then replays that response. The budget must comfortably exceed a
// normal mutation's duration; a slower winner falls through to a RETRYABLE 503.
const REPLAY_POLL_INTERVAL_MS = 100;
const REPLAY_MAX_ATTEMPTS = 30;
const RESERVATION_TTL_HOURS = boundedHours(
  'IDEMPOTENCY_RESERVATION_TTL_HOURS',
  24,
  1,
  168,
);
const RESPONSE_TTL_HOURS = boundedHours(
  'IDEMPOTENCY_TTL_HOURS',
  168,
  1,
  720,
);

type Acquisition =
  | { owned: true; reservationId: string }
  | ({ owned: false; response: unknown } & ReplayMetadata);

/**
 * Replay protection for the mobile offline sync queue.
 *
 * A queued write is retried whenever the response is lost (timeout after the
 * server committed). When the client sends `X-Client-Request-Id`, the row is
 * reserved BEFORE the mutation runs, so the unique `(userId, key)` index is the
 * atomic gate: exactly one concurrent request executes the work and the rest
 * replay its stored response instead of duplicating a financial record.
 *
 * A same-request collision is NEVER answered with a 4xx: losers wait for the
 * winner and replay its 2xx result. Reusing the same key for a DIFFERENT request
 * is a permanent client error and returns 409 instead of replaying the wrong
 * financial response.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(private readonly prisma: PrismaService) {}

  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    const http = context.switchToHttp();
    const request = http.getRequest<RequestLike>();
    const response = http.getResponse<ResponseLike>();
    const method = (request.method ?? '').toUpperCase();
    const userId = request.user?.id;
    const key = this.headerValue(request, IDEMPOTENCY_HEADER);

    if (!userId || !key || !MUTATING_METHODS.has(method)) {
      return next.handle();
    }

    const path = requestRouteTemplate(request);
    // Presigning creates no durable application record, and invite
    // create/reissue responses carry a raw bearer that must be presented only
    // once. Neither response is eligible for durable replay storage.
    if (
      isTransientPresignRoute(method, path) ||
      isOneTimeInviteBearerRoute(method, path)
    ) {
      return next.handle();
    }
    const requestHash = requestFingerprint(request, method);

    return from(this.acquire(userId, key, method, path, requestHash)).pipe(
      switchMap((acquisition) => {
        if (!acquisition.owned) {
          // Another request already did the work — replay its result.
          this.restoreReplayMetadata(response, acquisition);
          return of(acquisition.response);
        }
        // We own the reservation: run the mutation and record its response.
        // Unknown and server-side failures retain the reservation because the
        // outcome may have committed before the handler threw.
        const reservationId = acquisition.reservationId;
        return next.handle().pipe(
          // Release only failures with an explicit no-commit outcome. Keeping
          // ambiguous failures trades automatic recovery for duplicate-write
          // prevention until an operator can reconcile the tombstone.
          catchError((error) => {
            if (!isProvablySafeToRetry(error)) {
              return throwError(() => error);
            }
            return from(this.release(reservationId)).pipe(
              switchMap(() => throwError(() => error)),
            );
          }),
          switchMap((handlerResponse) =>
            from(
              this.complete(
                reservationId,
                handlerResponse,
                captureReplayMetadata(http.getResponse<ResponseLike>()),
              ),
            ).pipe(
              switchMap(() => of(handlerResponse)),
            ),
          ),
        );
      }),
    );
  }

  private headerValue(request: RequestLike, name: string): string | null {
    const raw = request.headers?.[name];
    const value = Array.isArray(raw) ? raw[0] : raw;
    return safeClientRequestId(value) ?? null;
  }

  /**
   * Reserve the `(userId, key)` row before the mutation runs. The unique index
   * turns the INSERT into the atomic gate: the winner owns execution; a loser
   * observes the winner's row and replays its completed response.
   */
  private async acquire(
    userId: string,
    key: string,
    method: string,
    path: string,
    requestHash: string,
  ): Promise<Acquisition> {
    for (let attempt = 0; attempt < REPLAY_MAX_ATTEMPTS; attempt++) {
      try {
        const reservation = await this.prisma.idempotencyKey.create({
          data: {
            userId,
            key,
            method,
            path,
            requestHash,
            expiresAt: hoursFromNow(RESERVATION_TTL_HOURS),
            // NULL response + NULL completedAt = reservation in flight.
            response: Prisma.DbNull,
          },
          select: { id: true },
        });
        return { owned: true, reservationId: reservation.id };
      } catch (error) {
        if (
          !(error instanceof Prisma.PrismaClientKnownRequestError) ||
          error.code !== 'P2002'
        ) {
          throw error;
        }
        // The key already exists: either the winner finished (replay it) or is
        // still in flight (wait), or it failed and released the row (re-own).
        const existing = await this.findStored(userId, key);
        if (
          existing?.completedAt &&
          existing.expiresAt.getTime() <= Date.now()
        ) {
          // Only a completed response has a known outcome and may age out.
          // A NULL completedAt is ambiguous after a process crash: the domain
          // transaction may already have committed, so it remains a tombstone
          // and must never be reclaimed for execution.
          await this.prisma.idempotencyKey.deleteMany({
            where: {
              id: existing.id,
              completedAt: { not: null },
              expiresAt: { lte: new Date() },
            },
          });
          continue;
        }
        if (
          existing &&
          (existing.method !== method ||
            existing.path !== path ||
            existing.requestHash !== requestHash)
        ) {
          throw new ConflictException(
            'This idempotency key was already used for a different request.',
          );
        }
        if (existing?.completedAt) {
          const replay = decodeStoredResponse(existing.response);
          return { owned: false, ...replay };
        }
        if (!existing) {
          continue;
        }
        await this.delay(REPLAY_POLL_INTERVAL_MS);
      }
    }
    // The in-flight owner never finished within the poll budget. Fail with a
    // RETRYABLE status so the offline-sync client retries (and then replays)
    // later — never a 4xx, which the client treats as a permanent drop.
    throw new ServiceUnavailableException(
      'A request with this idempotency key is still in progress.',
    );
  }

  private findStored(userId: string, key: string) {
    return this.prisma.idempotencyKey.findUnique({
      where: { userId_key: { userId, key } },
    });
  }

  private async complete(
    reservationId: string,
    response: unknown,
    metadata: ReplayMetadata,
  ): Promise<void> {
    try {
      await this.prisma.idempotencyKey.update({
        where: { id: reservationId },
        data: {
          response: encodeStoredResponse(response, metadata),
          completedAt: new Date(),
          expiresAt: hoursFromNow(RESPONSE_TTL_HOURS),
        },
      });
    } catch (error) {
      // The reservation row can vanish if the handler itself deleted this
      // user's idempotency keys (account deletion). The response is still
      // valid to return; there is simply nothing left to store for a replay
      // (which cannot happen anyway once the account is gone).
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2025'
      ) {
        return;
      }
      throw error;
    }
  }

  private async release(reservationId: string): Promise<void> {
    try {
      await this.prisma.idempotencyKey.delete({
        where: { id: reservationId },
      });
    } catch (error) {
      // Already gone — nothing to release.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2025'
      ) {
        return;
      }
      throw error;
    }
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private restoreReplayMetadata(
    response: ResponseLike,
    metadata: ReplayMetadata,
  ): void {
    const { statusCode, headers } = metadata;
    if (isHttpStatus(statusCode)) {
      if (typeof response.status === 'function') {
        response.status(statusCode);
      } else {
        response.statusCode = statusCode;
      }
    }
    if (typeof response.setHeader !== 'function') return;
    for (const [name, value] of Object.entries(headers ?? {})) {
      response.setHeader(name, value);
    }
  }
}

function isTransientPresignRoute(method: string, path: string): boolean {
  return method === 'POST' && /(?:^|\/)media\/uploads\/presign\/?$/.test(path);
}

function isOneTimeInviteBearerRoute(method: string, path: string): boolean {
  if (method !== 'POST') return false;
  return (
    /^\/api\/v1\/wedding-plans\/:weddingPlanId\/invites\/?$/.test(path) ||
    /^\/api\/v1\/wedding-plans\/:weddingPlanId\/invites\/:inviteId\/reissue\/?$/.test(
      path,
    )
  );
}

export function encodeStoredResponse(
  response: unknown,
  metadata: ReplayMetadata,
): Prisma.InputJsonValue {
  const { statusCode, headers } = metadata;
  return {
    [STORED_RESPONSE_MARKER]: true,
    body: response ?? null,
    ...(isHttpStatus(statusCode) ? { statusCode } : {}),
    ...(headers && Object.keys(headers).length > 0 ? { headers } : {}),
  } as Prisma.InputJsonValue;
}

function decodeStoredResponse(
  stored: unknown,
): { response: unknown } & ReplayMetadata {
  if (
    stored &&
    typeof stored === 'object' &&
    !Array.isArray(stored) &&
    (stored as Record<string, unknown>)[STORED_RESPONSE_MARKER] === true
  ) {
    const envelope = stored as Record<string, unknown>;
    const headers = decodeReplayHeaders(envelope.headers);
    return {
      response: withoutExpiredTransientUrls(envelope.body),
      ...(isHttpStatus(envelope.statusCode)
        ? { statusCode: envelope.statusCode }
        : {}),
      ...(headers ? { headers } : {}),
    };
  }
  // Rows created before the response envelope remain replayable. Their body
  // is preserved, but no historical status code exists to restore.
  return { response: withoutExpiredTransientUrls(stored ?? {}) };
}

function withoutExpiredTransientUrls(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((entry) => withoutExpiredTransientUrls(entry));
  }
  if (!value || typeof value !== 'object') return value;

  const source = value as Record<string, unknown>;
  const result = Object.fromEntries(
    Object.entries(source).map(([key, entry]) => [
      key,
      withoutExpiredTransientUrls(entry),
    ]),
  );
  const expiresAt = transientExpiryTime(source.expiresAt);
  if (
    expiresAt !== null &&
    expiresAt <= Date.now() + SIGNED_URL_REPLAY_SAFETY_MS
  ) {
    // Keep the attachment identity and expiry so clients can use the existing
    // authenticated refresh endpoint, but never emit a credential that is
    // already expired (or likely to expire in transit).
    for (const key of TRANSIENT_URL_KEYS) {
      if (typeof source[key] === 'string') result[key] = '';
    }
  }
  return result;
}

function transientExpiryTime(value: unknown): number | null {
  if (value instanceof Date) {
    const time = value.getTime();
    return Number.isFinite(time) ? time : null;
  }
  if (typeof value !== 'string' && typeof value !== 'number') return null;
  const time = new Date(value).getTime();
  return Number.isFinite(time) ? time : null;
}

function captureReplayMetadata(response: ResponseLike): ReplayMetadata {
  const statusCode = isHttpStatus(response.statusCode)
    ? response.statusCode
    : undefined;
  const headers: ReplayHeaders = {};
  if (typeof response.getHeader === 'function') {
    for (const name of SAFE_REPLAY_HEADERS) {
      const value = normalizeReplayHeader(response.getHeader(name));
      if (value !== undefined) headers[name] = value;
    }
  }
  return {
    ...(statusCode !== undefined ? { statusCode } : {}),
    ...(Object.keys(headers).length > 0 ? { headers } : {}),
  };
}

function decodeReplayHeaders(value: unknown): ReplayHeaders | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return undefined;
  }
  const source = value as Record<string, unknown>;
  const headers: ReplayHeaders = {};
  for (const name of SAFE_REPLAY_HEADERS) {
    const normalized = normalizeReplayHeader(source[name]);
    if (normalized !== undefined) headers[name] = normalized;
  }
  return Object.keys(headers).length > 0 ? headers : undefined;
}

function normalizeReplayHeader(
  value: unknown,
): string | string[] | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === 'string') {
    return /[\r\n]/.test(value) ? undefined : value;
  }
  if (
    Array.isArray(value) &&
    value.every((entry) => typeof entry === 'string' && !/[\r\n]/.test(entry))
  ) {
    return [...value];
  }
  return undefined;
}

function isProvablySafeToRetry(error: unknown): boolean {
  if (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === 'P2034'
  ) {
    // Prisma documents P2034 as an aborted transaction caused by a write
    // conflict/deadlock. The transaction did not commit, so retry is safe.
    return true;
  }
  if (!(error instanceof HttpException)) return false;
  const status = error.getStatus();
  // Restrict automatic release to validation statuses used before durable
  // writes. Other 4xx responses may be raised after partial side effects.
  return status === 400 || status === 422;
}

function isHttpStatus(value: unknown): value is number {
  return Number.isInteger(value) && Number(value) >= 100 && Number(value) <= 599;
}

/**
 * Bind a key to the concrete target, canonical JSON body, and method. Raw
 * invite tokens and query values are never persisted; only this SHA-256 digest
 * is stored alongside the safe route template.
 */
export function requestFingerprint(
  request: RequestLike,
  method = (request.method ?? '').toUpperCase(),
): string {
  const rawTarget =
    request.originalUrl ?? request.url ?? requestRouteTemplate(request);
  const target = canonicalRequestTarget(rawTarget);
  const body = canonicalJson(request.body ?? null);
  return createHash('sha256')
    .update(`${method}\n${target}\n${body}`, 'utf8')
    .digest('hex');
}

function canonicalRequestTarget(rawTarget: string): string {
  const parsed = new URL(rawTarget, 'http://aarast.local');
  const entries = [...parsed.searchParams.entries()].sort(([keyA, valueA], [keyB, valueB]) =>
    keyA === keyB ? valueA.localeCompare(valueB) : keyA.localeCompare(keyB),
  );
  const query = new URLSearchParams(entries).toString();
  return query ? `${parsed.pathname}?${query}` : parsed.pathname;
}

function canonicalJson(value: unknown): string {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'string' || typeof value === 'boolean') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    return Number.isFinite(value) ? JSON.stringify(value) : 'null';
  }
  if (Array.isArray(value)) {
    return `[${value.map((entry) => canonicalJson(entry)).join(',')}]`;
  }
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>;
    return `{${Object.keys(record)
      .filter((key) => record[key] !== undefined)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(record[key])}`)
      .join(',')}}`;
  }
  return 'null';
}

function boundedHours(
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const parsed = Number(process.env[name]);
  return Number.isFinite(parsed) && parsed >= minimum && parsed <= maximum
    ? parsed
    : fallback;
}

function hoursFromNow(hours: number): Date {
  return new Date(Date.now() + hours * 60 * 60 * 1_000);
}
