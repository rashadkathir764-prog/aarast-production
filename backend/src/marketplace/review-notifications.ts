import { NotificationPriority, NotificationType } from "@prisma/client";
import type { CreateNotificationInput } from "../modules/notifications/public/notifications.port";
import { starsWords } from "../modules/marketplace/public/review-reply";
import { noticeRoutes } from "../shared-kernel/routes/notification-routes";
import { gendered } from "../shared-kernel/voice/address-form";
import { customerFirstName } from "./quote-notifications";

// B-09: the review notices. Pure builders, no Prisma.

/** p42 «تقييم جديد · 4 نجوم من محمد», opening p27 where he replies. */
export function reviewReceivedProviderNotification(args: {
  providerUserId: string;
  providerId: string;
  reviewId: string;
  rating: number;
  reviewerName: string | null;
}): CreateNotificationInput {
  const who = customerFirstName(args.reviewerName);
  const stars = starsWords(args.rating);
  return {
    userId: args.providerUserId,
    type: NotificationType.REVIEW_RECEIVED,
    priority: NotificationPriority.NORMAL,
    title: "تقييم جديد",
    body: who ? `${stars} من ${who}` : stars,
    entityType: "provider_review",
    entityId: args.reviewId,
    routeTarget: noticeRoutes.providerReview(args.reviewId),
    data: {
      reviewId: args.reviewId,
      providerId: args.providerId,
      rating: args.rating,
      recipientAudience: "PROVIDER",
    },
    dedupeKey: `${args.providerUserId}:review-received:${args.reviewId}`,
  };
}

/** The reviewer reads that the provider answered, on the provider's page. */
export function reviewRepliedNotification(args: {
  reviewerId: string;
  providerId: string;
  providerName: string;
  reviewId: string;
}): CreateNotificationInput {
  return {
    userId: args.reviewerId,
    type: NotificationType.REVIEW_REPLIED,
    priority: NotificationPriority.NORMAL,
    title: `رد ${args.providerName} على تقييمك`,
    body: gendered(
      "رده تحت تقييمك في صفحته، وتقدر تشوفه هناك.",
      "رده تحت تقييمك في صفحته، وتقدرين تشوفينه هناك.",
    ),
    entityType: "provider_review",
    entityId: args.reviewId,
    routeTarget: noticeRoutes.providerPage(args.providerId),
    data: {
      reviewId: args.reviewId,
      providerId: args.providerId,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.reviewerId}:review-replied:${args.reviewId}`,
  };
}
