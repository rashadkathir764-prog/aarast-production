import { ConflictException, NotFoundException } from '@nestjs/common';
import { ReviewStatus } from '@prisma/client';

/**
 * B-09 (p27): the provider replies once to a review («ردك (مرة وحدة، يشوفه
 * الكل)»). There is no edit: the design offers one reply and «انشر الرد»,
 * and a reply that could be rewritten after customers read it would not be
 * the one they read. The moderation team hides a reply as it hides a review
 * (a10); a reviewer cannot change a review once it has a reply (the reply
 * would answer words that are no longer there), but may still delete it.
 */
export const REVIEW_REPLY_MAX_LENGTH = 1000;

export interface ReviewReplyFields {
  replyBody: string | null;
  repliedAt: Date | null;
  replyStatus: ReviewStatus | null;
}

/** Customers read a published reply only. */
export function publicReviewReply(
  review: ReviewReplyFields,
): { body: string; repliedAt: Date } | null {
  if (
    review.replyBody == null ||
    review.repliedAt == null ||
    review.replyStatus !== ReviewStatus.PUBLISHED
  ) {
    return null;
  }
  return { body: review.replyBody, repliedAt: review.repliedAt };
}

/** The provider and the moderation team read the reply in any state. */
export function ownerReviewReply(
  review: ReviewReplyFields,
): { body: string; repliedAt: Date; status: ReviewStatus } | null {
  if (
    review.replyBody == null ||
    review.repliedAt == null ||
    review.replyStatus == null
  ) {
    return null;
  }
  return {
    body: review.replyBody,
    repliedAt: review.repliedAt,
    status: review.replyStatus,
  };
}

export function reviewAlreadyReplied(): ConflictException {
  return new ConflictException({
    statusCode: 409,
    code: 'REVIEW_ALREADY_REPLIED',
    message: 'رديت على هذا التقييم قبل، والرد يكون مرة وحدة.',
  });
}

export function reviewHasReply(): ConflictException {
  return new ConflictException({
    statusCode: 409,
    code: 'REVIEW_HAS_REPLY',
    message: 'المزود رد على هذا التقييم، فما يتعدّل. يقدر ينحذف.',
  });
}

export function reviewNotFound(): NotFoundException {
  return new NotFoundException('Review not found');
}

/** «4 نجوم», «نجمتين», «نجمة وحدة», the way p42 counts stars. */
export function starsWords(rating: number): string {
  if (rating === 1) return 'نجمة وحدة';
  if (rating === 2) return 'نجمتين';
  return `${rating} نجوم`;
}
