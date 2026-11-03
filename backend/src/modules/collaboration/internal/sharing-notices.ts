import {
  NotificationPriority,
  NotificationType,
  WeddingPersona,
} from "@prisma/client";
import type { CreateNotificationInput } from "../../notifications/public/notifications.port";
import { noticeRoutes } from "../../../shared-kernel/routes/notification-routes";
import { gendered } from "../../../shared-kernel/voice/address-form";

// J2-07: what a member reads when the one who manages the plan's people
// changes what they may do in it, or takes them out of it. Pure builders, no
// Prisma. The one acting is named by first name in their own voice (a bride
// «غيّرت»); the reader is spoken to in their own form (B5).

export interface SharingActorVoice {
  name: string;
  persona: WeddingPersona | null;
}

function actorWords(actor: SharingActorVoice) {
  const feminine = actor.persona === WeddingPersona.BRIDE;
  const who =
    actor.name.trim().split(/\s+/u)[0] ||
    (feminine ? "صاحبة الخطة" : "صاحب الخطة");
  return { feminine, who };
}

/** The member's rights changed: the plan opens on what they may do now. */
export function memberRightsChangedNotice(args: {
  memberUserId: string;
  sharedMemberId: string;
  weddingPlanId: string;
  planTitle: string;
  actor: SharingActorVoice;
  authorityVersion: number;
}): CreateNotificationInput {
  const { feminine, who } = actorWords(args.actor);
  const changed = feminine ? "غيّرت" : "غيّر";
  return {
    userId: args.memberUserId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.SHARING_UPDATED,
    priority: NotificationPriority.NORMAL,
    title: gendered(
      `${who} ${changed} اللي تشوفه في ${args.planTitle}`,
      `${who} ${changed} اللي تشوفيه في ${args.planTitle}`,
    ),
    body: gendered(
      "افتح الخطة وشوف ايش عليك فيها الحين.",
      "افتحي الخطة وشوفي ايش عليك فيها الحين.",
    ),
    entityType: "shared_member",
    entityId: args.sharedMemberId,
    routeTarget: noticeRoutes.planHome(args.weddingPlanId),
    data: {
      weddingPlanId: args.weddingPlanId,
      sharedMemberId: args.sharedMemberId,
      change: "RIGHTS",
    },
    dedupeKey: `${args.memberUserId}:sharing:${args.sharedMemberId}:updated:${args.authorityVersion}`,
  };
}

/**
 * The member was taken out of the plan. The plan is closed to them now, so
 * the notice carries no plan (as D63's do) and opens the participant's plan
 * state screen, which the phone shows without the membership.
 */
export function memberRemovedNotice(args: {
  memberUserId: string;
  sharedMemberId: string;
  weddingPlanId: string;
  planTitle: string;
  actor: SharingActorVoice;
}): CreateNotificationInput {
  const { feminine, who } = actorWords(args.actor);
  return {
    userId: args.memberUserId,
    weddingPlanId: null,
    type: NotificationType.SHARING_UPDATED,
    priority: NotificationPriority.HIGH,
    title: gendered(
      `${who} ${feminine ? "شالتك" : "شالك"} من ${args.planTitle}`,
      `${who} ${feminine ? "شالتِك" : "شالكِ"} من ${args.planTitle}`,
    ),
    body: gendered(
      "ما عاد تشوف الخطة، واللي سوّيته فيها باقي.",
      "ما عاد تشوفي الخطة، واللي سوّيتيه فيها باقي.",
    ),
    entityType: "shared_member",
    entityId: args.sharedMemberId,
    routeTarget: noticeRoutes.sharedPlanState(args.weddingPlanId),
    data: {
      weddingPlanId: args.weddingPlanId,
      sharedMemberId: args.sharedMemberId,
      change: "REMOVED",
    },
    dedupeKey: `${args.memberUserId}:sharing:${args.sharedMemberId}:removed`,
  };
}
