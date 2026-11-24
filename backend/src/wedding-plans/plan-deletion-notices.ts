import { NotificationPriority, NotificationType, WeddingPersona } from "@prisma/client";
import type { CreateNotificationInput } from "../modules/notifications/public/notifications.port";
import { noticeRoutes } from "../shared-kernel/routes/notification-routes";
import { dayMonthWords } from "../shared-kernel/voice/day-words";

// Q-45 (D124): what the members of a plan read when its owner asks to delete
// it, or takes the request back. Pure builders, no Prisma. The owner is
// named by the first name, in the plan's voice (a bride's plan speaks of
// her), as the account's deletion notices do (D63).

export interface PlanDeletionOwner {
  name: string | null;
  persona: WeddingPersona | null;
}

function ownerWords(owner: PlanDeletionOwner) {
  const feminine = owner.persona === WeddingPersona.BRIDE;
  const first = owner.name?.trim().split(/\s+/u)[0] || null;
  return {
    who: first ?? (feminine ? "صاحبة الخطة" : "صاحب الخطة"),
    asked: feminine ? "طلبت حذف الخطة" : "طلب حذف الخطة",
    ifNot: feminine ? "لو ما تراجعت" : "لو ما تراجع",
    tookBack: feminine ? "تراجعت عن حذف الخطة" : "تراجع عن حذف الخطة",
  };
}

/** At the request: the plan closes to its members, and is erased on `scheduledFor`. */
export function planDeletionRequestedNotice(args: {
  memberUserId: string;
  weddingPlanId: string;
  owner: PlanDeletionOwner;
  scheduledFor: Date;
  requestedAt: Date;
}): CreateNotificationInput {
  const words = ownerWords(args.owner);
  return {
    userId: args.memberUserId,
    // The plan is closed to the member, so the notice carries no plan.
    weddingPlanId: null,
    type: NotificationType.PLAN_UPDATED,
    priority: NotificationPriority.HIGH,
    title: `خطة ${words.who} بتنحذف`,
    body: `${words.who} ${words.asked}. ${words.ifNot} لين ${dayMonthWords(args.scheduledFor)}، تنحذف الخطة كلها.`,
    entityType: "plan_deletion",
    entityId: null,
    routeTarget: noticeRoutes.home(),
    data: { planEvent: "PLAN_DELETION_REQUESTED" },
    dedupeKey: `${args.memberUserId}:plan-deletion:${args.weddingPlanId}:${args.requestedAt.getTime()}`,
  };
}

/** The owner took the request back: the plan is open again, as it was. */
export function planDeletionCancelledNotice(args: {
  memberUserId: string;
  weddingPlanId: string;
  owner: PlanDeletionOwner;
  requestedAt: Date;
}): CreateNotificationInput {
  const words = ownerWords(args.owner);
  return {
    userId: args.memberUserId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.PLAN_UPDATED,
    priority: NotificationPriority.NORMAL,
    title: `رجعت خطة ${words.who}`,
    body: `${words.who} ${words.tookBack}، والخطة رجعت كما هي.`,
    entityType: "plan_deletion",
    entityId: null,
    routeTarget: noticeRoutes.planHome(args.weddingPlanId),
    data: { weddingPlanId: args.weddingPlanId, planEvent: "PLAN_DELETION_CANCELLED" },
    dedupeKey: `${args.memberUserId}:plan-deletion-cancelled:${args.weddingPlanId}:${args.requestedAt.getTime()}`,
  };
}
