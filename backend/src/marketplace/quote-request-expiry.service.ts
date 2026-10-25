import { Inject, Injectable } from "@nestjs/common";
import { ConversationEventType, QuoteRequestStatus } from "@prisma/client";
import {
  CONVERSATION_LIFECYCLE_PORT,
  type ConversationLifecyclePort,
} from "../modules/messaging/public/conversation-lifecycle.port";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import * as deadlines from "../modules/marketplace/infrastructure/quote-offer-lifecycle.repository";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import {
  assertQuoteRequestTransition,
  isQuoteRequestOverdue,
  lockQuoteRequestTransitionRow,
  QUOTE_REQUEST_ANSWER_DAYS,
} from "./quote-lifecycle";
import {
  quoteRequestExpiredRequesterNotification,
  quoteRequestExpiringProviderNotification,
} from "./quote-notifications";

const BATCH_SIZE = 100;
const MAX_BATCHES_PER_RUN = 20;
const WARNING_WINDOW_MS = 24 * 60 * 60 * 1000;

export interface QuoteRequestExpiryRun {
  expired: number;
  warned: number;
  failures: Array<{ quoteRequestId: string; error: unknown }>;
}

/**
 * B-04: a request waits seven days for the provider. The day before, the
 * provider is told; at the deadline the request ends EXPIRED and the
 * customer is told «ما رد … خلال 7 أيام». Each request moves in its own
 * transaction under the conversation and request locks every quote
 * transition takes, and only from the state it was read in, so a retry or a
 * second instance of the job finds nothing left to do.
 */
@Injectable()
export class QuoteRequestExpiryService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(CONVERSATION_LIFECYCLE_PORT)
    private readonly lifecycle: ConversationLifecyclePort,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
  ) {}

  async run(now: Date = new Date()): Promise<QuoteRequestExpiryRun> {
    const result: QuoteRequestExpiryRun = { expired: 0, warned: 0, failures: [] };
    const failed = new Set<string>();

    for (let batch = 0; batch < MAX_BATCHES_PER_RUN; batch += 1) {
      const due = (
        await deadlines.listOverdueQuoteRequestIds(this.prisma, now, BATCH_SIZE + failed.size)
      ).filter((row) => !failed.has(row.id));
      if (due.length === 0) break;
      for (const { id } of due) {
        try {
          if (await this.expire(id, now)) result.expired += 1;
        } catch (error) {
          failed.add(id);
          result.failures.push({ quoteRequestId: id, error });
        }
      }
      if (due.length < BATCH_SIZE) break;
    }

    const until = new Date(now.getTime() + WARNING_WINDOW_MS);
    for (let batch = 0; batch < MAX_BATCHES_PER_RUN; batch += 1) {
      const due = (
        await deadlines.listQuoteRequestIdsToWarn(this.prisma, now, until, BATCH_SIZE + failed.size)
      ).filter((row) => !failed.has(row.id));
      if (due.length === 0) break;
      for (const { id } of due) {
        try {
          if (await this.warn(id, now, until)) result.warned += 1;
        } catch (error) {
          failed.add(id);
          result.failures.push({ quoteRequestId: id, error });
        }
      }
      if (due.length < BATCH_SIZE) break;
    }
    return result;
  }

  /** Ends one overdue request; false when it was answered, cancelled or ended meanwhile. */
  private expire(id: string, now: Date): Promise<boolean> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      if (!(await lockQuoteRequestTransitionRow(tx, this.lifecycle, id))) return false;
      const request = await deadlines.findQuoteRequestDeadline(tx, id);
      if (!request || !isQuoteRequestOverdue(request, now)) return false;
      assertQuoteRequestTransition(request.status, QuoteRequestStatus.EXPIRED, "expiry");
      const moved = await deadlines.expireOverdueQuoteRequest(tx, id, request.status, now);
      if (moved.count !== 1) return false;

      await this.lifecycle.recordConversationEvent(tx, {
        conversationId: request.conversationId,
        quoteRequestId: id,
        actorUserId: null,
        type: ConversationEventType.QUOTE_REQUEST_EXPIRED,
        occurredAt: now,
        dedupeKey: `quote-request:${id}:expired`,
        data: { status: QuoteRequestStatus.EXPIRED, answerDays: QUOTE_REQUEST_ANSWER_DAYS },
      });
      const recipientId = await this.notifications.resolveProviderUpdateRecipientInTransaction(
        tx,
        request.weddingPlanId,
        request.userId,
      );
      await this.notifications.createNotificationInTransaction(
        tx,
        quoteRequestExpiredRequesterNotification({
          requesterId: recipientId,
          weddingPlanId: request.weddingPlanId,
          quoteRequestId: id,
          providerId: request.providerId,
          providerName: request.provider.businessName,
          answerDays: QUOTE_REQUEST_ANSWER_DAYS,
        }),
      );
      return true;
    });
  }

  /** Tells the provider once per answer window; false when there is nothing to tell. */
  private warn(id: string, now: Date, until: Date): Promise<boolean> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      if (!(await lockQuoteRequestTransitionRow(tx, this.lifecycle, id))) return false;
      const request = await deadlines.findQuoteRequestDeadline(tx, id);
      if (
        !request ||
        (request.status !== QuoteRequestStatus.SENT &&
          request.status !== QuoteRequestStatus.VIEWED) ||
        request.expiryWarnedAt !== null ||
        request.expiresAt.getTime() <= now.getTime() ||
        request.expiresAt.getTime() > until.getTime()
      ) {
        return false;
      }
      const marked = await deadlines.markQuoteRequestExpiryWarned(tx, id, request.expiresAt, now);
      if (marked.count !== 1) return false;
      const providerUserId = request.provider.userId;
      if (!providerUserId) return true;
      await this.notifications.createNotificationInTransaction(
        tx,
        quoteRequestExpiringProviderNotification({
          providerUserId,
          quoteRequestId: id,
          providerId: request.providerId,
          customerName: request.contactName,
          expiresAt: request.expiresAt,
        }),
      );
      return true;
    });
  }
}
