import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';
import { recordRequestCommit } from './request-commits';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  /**
   * Connect eagerly so a broken DATABASE_URL fails the deployment at boot,
   * not on the first user request.
   */
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  /**
   * RA-BE-143: every transaction that commits is recorded on the request
   * that ran it (`request-commits.ts`), so the idempotency interceptor keeps
   * the reservation of a request that fails after its work became durable.
   */
  override $transaction<P extends Prisma.PrismaPromise<unknown>[]>(
    queries: [...P],
    options?: { isolationLevel?: Prisma.TransactionIsolationLevel },
  ): Promise<{ [K in keyof P]: Awaited<P[K]> }>;
  override $transaction<R>(
    work: (tx: Prisma.TransactionClient) => Promise<R>,
    options?: {
      maxWait?: number;
      timeout?: number;
      isolationLevel?: Prisma.TransactionIsolationLevel;
    },
  ): Promise<R>;
  override async $transaction(
    input: unknown,
    options?: Record<string, unknown>,
  ): Promise<unknown> {
    const result = await (
      super.$transaction as (input: unknown, options?: unknown) => Promise<unknown>
    ).call(this, input, options);
    recordRequestCommit();
    return result;
  }
}
