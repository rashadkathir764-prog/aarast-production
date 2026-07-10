export interface ReviewIdentity {
  id: string;
  name: string;
}

/**
 * Reviews are public content, but reviewer contact details are not. Keep an
 * explicit allowlist so a broader Prisma select cannot silently leak phone or
 * email in a future response.
 */
export function toReviewIdentity(user: ReviewIdentity): ReviewIdentity {
  return { id: user.id, name: user.name };
}
