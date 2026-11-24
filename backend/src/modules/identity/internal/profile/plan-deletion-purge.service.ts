import { Inject, Injectable, Logger } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../../../../platform/database/prisma.service";
import { runRetryableTransaction } from "../../../../platform/database/serializable-transaction";
import {
  MARKETPLACE_ERASURE_PORT,
  type MarketplaceErasurePort,
} from "../../../marketplace/public/marketplace-erasure.port";
import {
  MEDIA_STORAGE_PORT,
  type MediaStoragePort,
} from "../../../media/public/media-storage.port";
import {
  MESSAGING_ERASURE_PORT,
  type MessagingErasurePort,
} from "../../../messaging/public/messaging-erasure.port";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../../../notifications/public/notifications.port";
import {
  FINANCE_PORT,
  type FinancePort,
} from "../../../finance/public/finance.port";
import {
  PLAN_ERASURE_PORT,
  type PlanErasurePort,
} from "../../../planning/public/plan-erasure.port";
import { lockUserForAccountDeletion } from "../../infrastructure/account-erasure.repository";
import { purgeErasedGraphInTransaction } from "./erasure-graph";
import { UsersService } from "./users.service";

/** The purge takes this many due plans a run; the rest wait an hour. */
const PLAN_PURGE_BATCH = 25;

export interface PlanPurgeSummary {
  erased: number;
  failures: Array<{ weddingPlanId: string; error: unknown }>;
}

/**
 * Q-45 (D124), RA-BE-179: a plan its owner deleted is erased once its 30
 * days are over, with everything in it (guests, invitations, tasks, events,
 * costs, conversations, provider links, members, notifications), through
 * the same purge as an erased account's plans. Each plan is its own
 * transaction, in the saga's lock order (the owner's media boundary, the
 * owner's row, the plan, its costs, its conversations, its requests); one
 * taken back in the meantime is left as it is. The providers of its open
 * requests are told «حذف خطة العرس».
 */
@Injectable()
export class PlanDeletionPurgeService {
  private readonly logger = new Logger(PlanDeletionPurgeService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    @Inject(MEDIA_STORAGE_PORT) private readonly mediaStorage: MediaStoragePort,
    @Inject(PLAN_ERASURE_PORT) private readonly planErasure: PlanErasurePort,
    @Inject(FINANCE_PORT) private readonly finance: FinancePort,
    @Inject(MESSAGING_ERASURE_PORT)
    private readonly messagingErasure: MessagingErasurePort,
    @Inject(MARKETPLACE_ERASURE_PORT)
    private readonly marketplaceErasure: MarketplaceErasurePort,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
  ) {}

  async purgeDuePlans(now: Date): Promise<PlanPurgeSummary> {
    const due = await this.planErasure.listDuePlanDeletions(
      this.prisma,
      now,
      PLAN_PURGE_BATCH,
    );
    const summary: PlanPurgeSummary = { erased: 0, failures: [] };
    for (const plan of due) {
      try {
        if (await this.erasePlan(plan.id, plan.ownerUserId, now)) {
          summary.erased += 1;
        }
      } catch (error) {
        summary.failures.push({ weddingPlanId: plan.id, error });
      }
    }
    if (due.length === PLAN_PURGE_BATCH) {
      this.logger.warn(
        `The plan purge took its batch of ${PLAN_PURGE_BATCH}; the rest wait for the next run`,
      );
    }
    return summary;
  }

  /** True when the plan was erased; false when it is gone or was taken back. */
  async erasePlan(
    weddingPlanId: string,
    ownerUserId: string,
    now: Date,
  ): Promise<boolean> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        await this.mediaStorage.lockAccountDeletionBoundary(ownerUserId, tx);
        const [owner] = await lockUserForAccountDeletion(tx, ownerUserId);
        if (!owner) return false;
        if (
          !(await this.planErasure.lockDuePlanForUpdateInTransaction(
            tx,
            weddingPlanId,
            now,
          ))
        ) {
          return false;
        }
        const weddingPlanIds = [weddingPlanId];
        // Built while the requests exist; written after the purge.
        const notices =
          await this.marketplaceErasure.closedCustomerNoticesInTransaction(
            tx,
            { userId: null, weddingPlanIds },
            owner.name,
            now,
            "PLAN",
          );
        await this.finance.lockPlanCostsForUpdateInTransaction(tx, weddingPlanIds);
        const conversationIds =
          await this.messagingErasure.lockOwnedConversationIdsForUpdateInTransaction(
            tx,
            { userId: null, weddingPlanIds },
          );
        const quoteRequestIds =
          await this.marketplaceErasure.lockOwnedQuoteRequestIdsForUpdateInTransaction(
            tx,
            { userId: null, weddingPlanIds, conversationIds },
          );
        await purgeErasedGraphInTransaction(this.users.erasureGraphPorts(), tx, {
          userId: null,
          weddingPlanIds,
          conversationIds,
          quoteRequestIds,
          erasedAt: now,
        });
        for (const notice of notices) {
          await this.notifications.createNotificationInTransaction(tx, notice);
        }
        return true;
      },
      {
        timeout: 15_000,
        isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
      },
    );
  }
}
