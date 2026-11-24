import type { ProviderProfileChange } from '@prisma/client';

/**
 * RA-BE-152 (Q-39 (أ), D124): what an approved provider's listing shows
 * customers as who he is: his name, logo, cover, city and category. A change
 * of any of them waits for the team as one request per provider; the
 * listing keeps its live values and images until the team approves. Every
 * other field (description, phone, prices, packages) stays live as before.
 */
export interface ProfileChangeFields {
  businessName: string | null;
  cityId: string | null;
  primaryCategoryId: string | null;
  logoUrl: string | null;
  coverUrl: string | null;
}

export const PROFILE_CHANGE_FIELDS = [
  'businessName',
  'cityId',
  'primaryCategoryId',
  'logoUrl',
  'coverUrl',
] as const satisfies ReadonlyArray<keyof ProfileChangeFields>;

export type ProfileChangeField = (typeof PROFILE_CHANGE_FIELDS)[number];

/** The longest reason the team gives with a refusal (the provider reads it). */
export const PROFILE_CHANGE_REJECTION_REASON_MAX_LENGTH = 400;

export const NO_PROFILE_CHANGE: ProfileChangeFields = {
  businessName: null,
  cityId: null,
  primaryCategoryId: null,
  logoUrl: null,
  coverUrl: null,
};

/**
 * The request after the provider's edit: each field he sent is asked for,
 * unless it is what the listing already shows, which takes that field out
 * of the request (he set it back). A field he did not send keeps what the
 * request held.
 */
export function mergeProfileChange(
  live: ProfileChangeFields,
  pending: ProfileChangeFields | null,
  asked: Partial<ProfileChangeFields>,
): ProfileChangeFields {
  const next = { ...(pending ?? NO_PROFILE_CHANGE) };
  for (const field of PROFILE_CHANGE_FIELDS) {
    const value = asked[field];
    if (value === undefined || value === null) continue;
    next[field] = value === live[field] ? null : value;
  }
  return next;
}

export function asksForChange(fields: ProfileChangeFields): boolean {
  return PROFILE_CHANGE_FIELDS.some((field) => fields[field] !== null);
}

/** The asked fields of a stored request. */
export function profileChangeFields(
  change: Pick<ProviderProfileChange, ProfileChangeField>,
): ProfileChangeFields {
  return {
    businessName: change.businessName,
    cityId: change.cityId,
    primaryCategoryId: change.primaryCategoryId,
    logoUrl: change.logoUrl,
    coverUrl: change.coverUrl,
  };
}

/** The media target that holds a request's new logo or cover until the decision. */
export function profileChangeMediaTarget(changeId: string, image: 'logo' | 'cover') {
  return {
    type: image === 'logo' ? 'PROVIDER_PROFILE_CHANGE_LOGO' : 'PROVIDER_PROFILE_CHANGE_COVER',
    id: changeId,
  } as const;
}

/** «الاسم والشعار»: what the request asks for, in the portal's words. */
export function profileChangeSubject(fields: ProfileChangeFields): string {
  const names = [
    fields.businessName !== null ? 'الاسم' : null,
    fields.logoUrl !== null ? 'الشعار' : null,
    fields.coverUrl !== null ? 'الغلاف' : null,
    fields.cityId !== null ? 'المدينة' : null,
    fields.primaryCategoryId !== null ? 'الفئة' : null,
  ].filter((name): name is string => name !== null);
  if (names.length <= 1) return names[0] ?? 'ملفك';
  return `${names.slice(0, -1).join(' و')} و${names[names.length - 1]}`;
}

/** The sentence the provider reads (the portal speaks to the business in the masculine, D55). */
export function profileChangeDecisionNotice(
  fields: ProfileChangeFields,
  decision: 'APPROVED' | 'REJECTED',
  reason: string | null,
): { title: string; body: string } {
  const subject = profileChangeSubject(fields);
  if (decision === 'APPROVED') {
    return {
      title: 'وافقنا على تعديل ملفك',
      body: `تعديل ${subject} صار ظاهر للعرسان.`,
    };
  }
  return {
    title: 'ما وافقنا على تعديل ملفك',
    body: `تعديل ${subject} ما نزل، وملفك باقي مثل ما كان. السبب: ${reason ?? ''}`,
  };
}
