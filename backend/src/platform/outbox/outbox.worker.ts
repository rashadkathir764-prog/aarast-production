import { randomUUID } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { OutboxEvent, Prisma } from '@prisma/client';
import {
  outboxBacklog,
  outboxDispatchTotal,
} from '../observability/metrics';
import { isQuietHour, quietHoursEnd } from '../../shared-kernel/time/quiet-hours';
import { PrismaService } from '../database/prisma.service';
import { OutboxDispatcher } from './outbox.dispatcher';
import { OutboxRetryWithProgress } from './outbox-retry';

const batchSize = 100;
const maxAttempts = 8;
const staleLockMs = 2 * 60_000;

@Injectable()
export class OutboxWorker {
  private readonly logger = new Logger(OutboxWorker.name);
  private readonly workerId = `${process.pid}:${randomUUID()}`;
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly dispatcher: OutboxDispatcher,
  ) {}

  @Interval(1_000)
  async drainOnce(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const events = await this.claimBatch();
      for (const event of events) await this.process(event);
    } catch (error) {
      this.logger.error(`Outbox drain failed: ${outboxFailureCode(error)}`);
    } finally {
      this.running = false;
    }
  }

  @Interval(15_000)
  async refreshMetrics(): Promise<void> {
    const groups = await this.prisma.outboxEvent.groupBy({
      by: ['status'],
      where: { status: { in: ['PENDING', 'PROCESSING', 'FAILED'] } },
      _count: { _all: true },
    });
    for (const status of ['PENDING', 'PROCESSING', 'FAILED']) {
      const count = groups.find((group) => group.status === status)?._count._all;
      outboxBacklog.set({ status: status.toLowerCase() }, count ?? 0);
    }
  }

  private async claimBatch(): Promise<OutboxEvent[]> {
    const staleBefore = new Date(Date.now() - staleLockMs);
    return this.prisma.$transaction(async (tx) => {
      await tx.outboxEvent.updateMany({
        where: {
          status: 'PROCESSING',
          lockedAt: { lt: staleBefore },
        },
        data: {
          status: 'PENDING',
          lockedAt: null,
          lockedBy: null,
        },
      });

      return tx.$queryRaw<OutboxEvent[]>(Prisma.sql`
        WITH candidates AS (
          SELECT "id"
          FROM "OutboxEvent"
          WHERE "status" = 'PENDING'
            AND "nextAttemptAt" <= NOW()
          ORDER BY "createdAt" ASC
          FOR UPDATE SKIP LOCKED
          LIMIT ${batchSize}
        )
        UPDATE "OutboxEvent" AS event
        SET "status" = 'PROCESSING',
            "lockedAt" = NOW(),
            "lockedBy" = ${this.workerId},
            "attemptCount" = event."attemptCount" + 1,
            "updatedAt" = NOW()
        FROM candidates
        WHERE event."id" = candidates."id"
        RETURNING event.*
      `);
    });
  }

  private async process(event: OutboxEvent): Promise<void> {
    try {
      await this.dispatcher.dispatch(event);
      await this.prisma.outboxEvent.updateMany({
        where: {
          id: event.id,
          status: 'PROCESSING',
          lockedBy: this.workerId,
        },
        data: {
          status: 'PROCESSED',
          processedAt: new Date(),
          lockedAt: null,
          lockedBy: null,
          lastError: null,
        },
      });
      outboxDispatchTotal.inc({ event_type: event.type, outcome: 'processed' });
    } catch (error) {
      const terminal = event.attemptCount >= maxAttempts;
      await this.prisma.outboxEvent.updateMany({
        where: {
          id: event.id,
          status: 'PROCESSING',
          lockedBy: this.workerId,
        },
        data: {
          status: terminal ? 'FAILED' : 'PENDING',
          nextAttemptAt: outboxNextAttemptAt(event, new Date()),
          // RA-BE-190: what the failed try finished is kept for the next.
          ...(error instanceof OutboxRetryWithProgress
            ? {
                payload: {
                  ...(jsonRecord(event.payload) ?? {}),
                  ...error.payloadPatch,
                } as Prisma.InputJsonObject,
              }
            : {}),
          lockedAt: null,
          lockedBy: null,
          lastError: outboxFailureCode(error),
        },
      });
      outboxDispatchTotal.inc({
        event_type: event.type,
        outcome: terminal ? 'failed' : 'retry',
      });
      if (terminal) {
        try {
          await this.dispatcher.recordTerminalFailure(
            event,
            outboxFailureCode(error),
          );
        } catch (recordError) {
          this.logger.error(
            `Outbox terminal failure not recorded for ${event.id}: ${outboxFailureCode(recordError)}`,
          );
        }
      }
    }
  }
}

/**
 * When a failed event is tried again. RA-BE-185: a push held through quiet
 * hours (its row says so, `heldThroughQuietHours`) whose retry would land
 * from 21:00 to 09:00 in Aden waits for 09:00, as its first try did; chat
 * and a booking request are never held.
 */
export function outboxNextAttemptAt(event: OutboxEvent, failedAt: Date): Date {
  const next = new Date(
    failedAt.getTime() + outboxRetryDelayMs(event.attemptCount),
  );
  return heldThroughQuietHours(event) && isQuietHour(next)
    ? quietHoursEnd(next)
    : next;
}

function jsonRecord(value: Prisma.JsonValue): Prisma.JsonObject | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value
    : null;
}

function heldThroughQuietHours(event: OutboxEvent): boolean {
  const payload = event.payload;
  return (
    payload !== null &&
    typeof payload === 'object' &&
    !Array.isArray(payload) &&
    payload.heldThroughQuietHours === true
  );
}

export function outboxRetryDelayMs(attemptCount: number): number {
  const safeAttempt = Math.max(1, Math.min(attemptCount, maxAttempts));
  return Math.min(5 * 60_000, 1_000 * 2 ** (safeAttempt - 1));
}

export function outboxFailureCode(error: unknown): string {
  const name = error instanceof Error ? error.name : typeof error;
  return name.replace(/[^A-Za-z0-9_.-]/g, '').slice(0, 80) || 'UnknownError';
}
