import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Observable, from, of, switchMap } from 'rxjs';
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

/**
 * Replay protection for the mobile offline sync queue.
 *
 * A queued write is retried whenever the response is lost (timeout after the
 * server committed). When the client sends `X-Client-Request-Id`, the first
 * successful response is stored per user+key; any replay returns that stored
 * response instead of duplicating the financial record.
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

    return from(this.findStored(userId, key)).pipe(
      switchMap((stored) => {
        if (stored) {
          return of(stored.response ?? {});
        }
        return next.handle().pipe(
          switchMap((response) =>
            from(
              this.store(
                userId,
                key,
                method,
                request.path ?? request.originalUrl ?? '',
                response,
              ),
            ).pipe(switchMap(() => of(response))),
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

  private findStored(userId: string, key: string) {
    return this.prisma.idempotencyKey.findUnique({
      where: { userId_key: { userId, key } },
    });
  }

  private async store(
    userId: string,
    key: string,
    method: string,
    path: string,
    response: unknown,
  ): Promise<void> {
    try {
      await this.prisma.idempotencyKey.create({
        data: {
          userId,
          key,
          method,
          path,
          response: (response ?? Prisma.JsonNull) as Prisma.InputJsonValue,
        },
      });
    } catch (error) {
      // A concurrent request with the same key won the insert — the work
      // was done exactly once server-side either way, so serving our own
      // response is still correct.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        return;
      }
      throw error;
    }
  }
}
