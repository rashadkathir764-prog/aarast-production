import { NotificationPriority, NotificationType, WeddingPersona } from "@prisma/client";
import type { CreateNotificationInput } from "../../../notifications/public/notifications.port";
import { noticeRoutes } from "../../../../shared-kernel/routes/notification-routes";
import { dayMonthWords } from "../../../../shared-kernel/voice/day-words";

// D63: what the members of an owner's plans read when he asks to delete his
// account, takes it back, or is erased after the 30 days (w05 «صالح والوالد
// يطلعون من الخطة، ويوصلهم إشعار»). Pure builders, no Prisma. The owner is
// named by his first name, in his own voice (a bride's plan speaks of her).

export interface PlanOwnerVoice {
  /** The owner's name as the members know it. */
  name: string | null;
  persona: WeddingPersona | null;
}

function firstName(name: string | null): string | null {
  return name?.trim().split(/\s+/u)[0] || null;
}

function ownerWords(owner: PlanOwnerVoice) {
  const feminine = owner.persona === WeddingPersona.BRIDE;
  const who = firstName(owner.name) ?? (feminine ? "صاحبة الخطة" : "صاحب الخطة");
  return {
    who,
    asked: feminine ? "طلبت حذف حسابها" : "طلب حذف حسابه",
    tookBack: feminine ? "تراجعت عن حذف حسابها" : "تراجع عن حذف حسابه",
    ifNot: feminine ? "لو ما تراجعت" : "لو ما تراجع",
    erased: feminine ? "حذفت حسابها" : "حذف حسابه",
  };
}

/** At the request: the plan closes to its members until the owner takes it back or it is erased. */
export function planClosedForDeletionNotice(args: {
  memberUserId: string;
  weddingPlanId: string;
  owner: PlanOwnerVoice;
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
    title: `خطة ${words.who} متوقفة`,
    body: `${words.who} ${words.asked}. ${words.ifNot} لين ${dayMonthWords(args.scheduledFor)}، تنحذف الخطة.`,
    entityType: "plan_owner_deletion",
    entityId: null,
    routeTarget: noticeRoutes.home(),
    data: { planEvent: "OWNER_DELETION_REQUESTED" },
    dedupeKey: `${args.memberUserId}:plan-closed:${args.weddingPlanId}:${args.requestedAt.getTime()}`,
  };
}

/** The owner took the request back: the plan is open again, as it was. */
export function planReopenedNotice(args: {
  memberUserId: string;
  weddingPlanId: string;
  owner: PlanOwnerVoice;
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
    entityType: "plan_owner_deletion",
    entityId: null,
    routeTarget: noticeRoutes.planHome(args.weddingPlanId),
    data: { weddingPlanId: args.weddingPlanId, planEvent: "OWNER_DELETION_CANCELLED" },
    dedupeKey: `${args.memberUserId}:plan-reopened:${args.weddingPlanId}:${args.requestedAt.getTime()}`,
  };
}

/** After the 30 days: the plan went with its owner's account; built before the purge, written after. */
export function planErasedNotice(args: {
  memberUserId: string;
  weddingPlanId: string;
  owner: PlanOwnerVoice;
  erasedAt: Date;
}): CreateNotificationInput {
  const words = ownerWords(args.owner);
  return {
    userId: args.memberUserId,
    weddingPlanId: null,
    type: NotificationType.PLAN_UPDATED,
    priority: NotificationPriority.HIGH,
    title: `انحذفت خطة ${words.who}`,
    body: `${words.who} ${words.erased}، فانحذفت الخطة وطلعت منها.`,
    entityType: "plan_owner_deletion",
    entityId: null,
    routeTarget: noticeRoutes.home(),
    data: { planEvent: "OWNER_ERASED" },
    dedupeKey: `${args.memberUserId}:plan-erased:${args.weddingPlanId}:${args.erasedAt.getTime()}`,
  };
}
