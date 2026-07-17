import {
  ApplicationNameSource,
  applicationDisplayName,
} from "../../users/application-user-identity";

export interface ReviewIdentity {
  id: string;
  name: string;
}

export interface ReviewIdentitySource extends ApplicationNameSource {
  id: string;
}

/**
 * Reviews are public content, but reviewer contact details are not. Keep an
 * explicit allowlist so a broader Prisma select cannot silently leak phone or
 * email in a future response.
 */
export function toReviewIdentity(user: ReviewIdentitySource): ReviewIdentity {
  return { id: user.id, name: applicationDisplayName(user) };
}
