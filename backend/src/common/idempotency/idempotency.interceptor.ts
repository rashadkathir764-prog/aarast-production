import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
  ServiceUnavailableException,
} from '@nestjs/common';
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

interface RequestLike {
  method?: string;
  path?: string;
  originalUrl?: string;
  headers?: Record<string, string | string[] | undefined>;
  user?: { id?: string };
}

const IDEMPOTENCY_HEADER = 'x-client-request-id';
const MUTATING_METHODS = new Set(['POST', 'PATCH', 'PUT', 'DELETE']);
const MAX_KEY_LENGTH = 120;

// A request that loses the reservation race polls the winner's row until it is
// completed, then replays that response. The budget must comfortably exceed a
// normal mutation's duration; a slower winner falls through to a RETRYABLE 503.
const REPLAY_POLL_INTERVAL_MS = 100;
const REPLAY_MAX_ATTEMPTS = 30;

type Acquisition = { owned: true } | { owned: false; response: unknown };

/**
 * Replay protection for the mobile offline sync queue.
 *
 * A queued write is retried whenever the response is lost (timeout after the
 * server committed). When the client sends `X-Client-Request-Id`, the row is
 * reserved BEFORE the mutation runs, so the unique `(userId, key)` index is the
 * atomic gate: exactly one concurrent request executes the work and the rest
 * replay its stored response instead of duplicating a financial record.
 *
 * A collision is NEVER answered with a 4xx: the offline-sync client treats any
 * 4xx as a permanent rejection and drops the (possibly financial) write. Losers
 * wait for the winner and replay its 2xx result; on the rare timeout they get a
 * retryable 503 that the client safely retries later.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(private readonly prisma: PrismaService) {}

  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    const request = context.switchToHttp().getRequest<RequestLike>();
    const method = (request.method ?? '').toUpperCase();
    const userId = request.user?.id;
    const key = this.headerValue(request, IDEMPOTENCY_HEADER);

    if (!userId || !key || !MUTATING_METHODS.has(method)) {
      return next.handle();
    }

    const path = request.path ?? request.originalUrl ?? '';

    return from(this.acquire(userId, key, method, path)).pipe(
      switchMap((acquisition) => {
        if (!acquisition.owned) {
          // Another request already did the work — replay its result.
          return of(acquisition.response);
        }
        // We own the reservation: run the mutation exactly once, record its
        // response, then serve it. If the mutation throws, release the
        // reservation so the client's retry can succeed instead of replaying
        // a cached failure forever.
        return next.handle().pipe(
          switchMap((response) =>
            from(this.complete(userId, key, response)).pipe(
              switchMap(() => of(response)),
            ),
          ),
          catchError((error) =>
            from(this.release(userId, key)).pipe(
              switchMap(() => throwError(() => error)),
            ),
          ),
        );
      }),
    );
  }

  private headerValue(request: RequestLike, name: string): string | null {
    const raw = request.headers?.[name];
    const value = Array.isArray(raw) ? raw[0] : raw;
    const trimmed = value?.trim();
    if (!trimmed) return null;
    return trimmed.slice(0, MAX_KEY_LENGTH);
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
  ): Promise<Acquisition> {
    for (let attempt = 0; attempt < REPLAY_MAX_ATTEMPTS; attempt++) {
      try {
        await this.prisma.idempotencyKey.create({
          data: {
            userId,
            key,
            method,
            path,
            // NULL response + NULL completedAt = reservation in flight.
            response: Prisma.DbNull,
          },
        });
        return { owned: true };
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
        if (existing?.completedAt) {
          return { owned: false, response: existing.response ?? {} };
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
    userId: string,
    key: string,
    response: unknown,
  ): Promise<void> {
    try {
      await this.prisma.idempotencyKey.update({
        where: { userId_key: { userId, key } },
        data: {
          response: (response ?? Prisma.JsonNull) as Prisma.InputJsonValue,
          completedAt: new Date(),
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

  private async release(userId: string, key: string): Promise<void> {
    try {
      await this.prisma.idempotencyKey.delete({
        where: { userId_key: { userId, key } },
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
}
