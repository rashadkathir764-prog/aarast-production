import {
  ApplicationNameSource,
  applicationDisplayName,
} from "./application-user-identity";

export interface ReviewIdentity {
  id: string;
  name: string;
}

export interface ModeratedReviewIdentitySource extends ApplicationNameSource {
  id: string;
}

export interface ReviewIdentitySource extends ModeratedReviewIdentitySource {
  /** D63 (w40 «اسمي في التقييمات · الاسم الأول بس»): on by default. */
  reviewFirstNameOnly: boolean;
}

/**
 * Reviews are public content, but reviewer contact details are not. Keep an
 * explicit allowlist so a broader Prisma select cannot silently leak phone or
 * email in a future response. The reviewer chooses whether customers and
 * providers read the first name only (w40).
 */
export function toReviewIdentity(user: ReviewIdentitySource): ReviewIdentity {
  const name = applicationDisplayName(user);
  if (!user.reviewFirstNameOnly) return { id: user.id, name };
  return { id: user.id, name: name.trim().split(/\s+/u)[0] || name };
}

/** The back office moderates a review knowing the whole name (a10). */
export function toModeratedReviewIdentity(
  user: ModeratedReviewIdentitySource,
): ReviewIdentity {
  return { id: user.id, name: applicationDisplayName(user) };
}
