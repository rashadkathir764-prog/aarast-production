import type { Prisma } from "@prisma/client";
import { purgeOutboxEventsForAggregatesInTransaction } from "../../../../platform/outbox/outbox-purge";
import type { CollaborationErasurePort } from "../../../collaboration/public/collaboration-erasure.port";
import type { FinancePort } from "../../../finance/public/finance.port";
import type { GuestsPort } from "../../../guests/public/guests.port";
import type { MarketplaceErasurePort } from "../../../marketplace/public/marketplace-erasure.port";
import type { MediaStoragePort } from "../../../media/public/media-storage.port";
import type { MessagingErasurePort } from "../../../messaging/public/messaging-erasure.port";
import type { NotificationsErasurePort } from "../../../notifications/public/notifications-erasure.port";
import type { PlanErasurePort } from "../../../planning/public/plan-erasure.port";
import type { TasksPort } from "../../../tasks/public/tasks.port";

export interface ErasureGraphPorts {
  mediaStorage: MediaStoragePort;
  planErasure: PlanErasurePort;
  marketplaceErasure: MarketplaceErasurePort;
  messagingErasure: MessagingErasurePort;
  notificationsErasure: NotificationsErasurePort;
  collaborationErasure: CollaborationErasurePort;
  finance: FinancePort;
  tasks: TasksPort;
  guests: GuestsPort;
}

/** What goes, every row of it already locked by the caller in the saga's order. */
export interface ErasedGraph {
  /** The erased account (D63); null when only plans go (Q-45). */
  userId: string | null;
  weddingPlanIds: readonly string[];
  conversationIds: readonly string[];
  quoteRequestIds: readonly string[];
  erasedAt: Date;
}

/**
 * The one purge of an erased account's own rows and of its plans, and of a
 * plan its owner deleted (Q-45, D124): each statement runs in its table's
 * owner, on the caller's transaction, in this order, which is the FK-safe,
 * deadlock-safe order of the erasure saga (`UsersService.eraseDueAccount`).
 * The caller has locked the account (if any), the plans, their costs, the
 * conversations and the quote requests before it.
 */
export async function purgeErasedGraphInTransaction(
  ports: ErasureGraphPorts,
  tx: Prisma.TransactionClient,
  graph: ErasedGraph,
): Promise<void> {
  const { userId, weddingPlanIds: planIds, conversationIds, quoteRequestIds } = graph;
  const attachmentIds =
    await ports.messagingErasure.listAttachmentIdsForConversations(
      tx,
      conversationIds,
    );
  await ports.mediaStorage.scheduleChatAttachmentDeletion(attachmentIds, tx);
  // Receipts (V1 checklist 4.4): those of the erased plans and of the
  // account's private costs go with their files. RA-BE-178 (D112): one it
  // uploaded on another person's cost stays, from «عضو سابق».
  const receiptIds = await ports.finance.listErasedReceiptIdsInTransaction(
    tx,
    planIds,
    userId,
  );
  await ports.mediaStorage.scheduleCostReceiptDeletion(receiptIds, tx);
  await ports.finance.deleteReceiptsInTransaction(tx, receiptIds);
  if (userId !== null) {
    await ports.finance.detachReceiptUploaderInTransaction(tx, userId);
  }
  await ports.mediaStorage.scheduleInvitationCardDeletion(
    await ports.guests.listPlanInvitationCardIds(tx, planIds),
    tx,
  );

  const notificationIds =
    await ports.notificationsErasure.listOwnedNotificationIds(tx, {
      userId,
      weddingPlanIds: planIds,
      quoteRequestIds,
    });
  await purgeOutboxEventsForAggregatesInTransaction(tx, {
    notificationIds,
    conversationIds,
  });
  await ports.notificationsErasure.deleteNotificationsInTransaction(
    tx,
    notificationIds,
  );

  // QuoteRequest.conversationId is Restrict by design so ordinary quote
  // removal can never erase a shared thread. The erasure is the one explicit
  // path that removes all requests in the erased contexts first, then
  // removes only those contexts.
  await ports.marketplaceErasure.deleteQuoteRequestsInTransaction(
    tx,
    quoteRequestIds,
  );
  await ports.messagingErasure.deleteConversationsInTransaction(
    tx,
    conversationIds,
  );
  if (userId !== null) {
    // V1 checklist 4.10: no one else ever saw the account's private costs
    // and tasks; they leave with it (their receipts went above).
    await ports.finance.purgePrivateCostsInTransaction(tx, userId);
    await ports.tasks.deletePrivateTasksInTransaction(tx, userId);
  }
  const tenureEndedAt = graph.erasedAt;
  if (planIds.length > 0) {
    // Contribution history is retained independently from the live plan.
    // Close every active tenure before the plan/member graph disappears;
    // the append-only events and detached history scope remain intact.
    await ports.collaborationErasure.markPlansDeletedInTransaction(
      tx,
      planIds,
      tenureEndedAt,
    );
  }
  if (userId !== null) {
    // A contributor deleting the central account closes their tenures in
    // plans owned by other users without deleting the plan's audit trail.
    await ports.collaborationErasure.closeActorTenuresInTransaction(
      tx,
      userId,
      tenureEndedAt,
    );
  }
  if (planIds.length > 0) {
    await ports.finance.purgePlanLedgerInTransaction(tx, planIds);
    await ports.tasks.deletePlanTasksInTransaction(tx, planIds); // cascades checklist items
    await ports.guests.deletePlanGuestsInTransaction(tx, planIds);
    await ports.marketplaceErasure.deletePlanProviderLinksInTransaction(
      tx,
      planIds,
    );
    await ports.collaborationErasure.deletePlanMembersAndInvitesInTransaction(
      tx,
      planIds,
    );
    await ports.finance.deletePlanBudgetCategoriesInTransaction(tx, planIds);
    // D65: the plans' own events go with them.
    await ports.planErasure.deletePlansInTransaction(tx, planIds);
  }
}
