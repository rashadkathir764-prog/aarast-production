import { UnprocessableEntityException } from '@nestjs/common';
import {
  ProviderReviewEventKind,
  ProviderReviewField,
  ProviderStatus,
} from '@prisma/client';

/** The joining service is priced in Yemeni riyals (D48). */
export const JOINING_SERVICE_CURRENCY = 'YER';

/**
 * The joining rule refused (B-10, D41): no active service priced above
 * zero. Apply, resubmit, the joining service added before approval and the
 * approval itself refuse with this one error.
 */
export function providerServiceRequired(): UnprocessableEntityException {
  return new UnprocessableEntityException({
    statusCode: 422,
    code: 'PROVIDER_SERVICE_REQUIRED',
    message: 'At least one active service with its price is required before review',
  });
}

/** The joining service is priced in another currency than YER (D48). */
export function joiningCurrencyRequired(): UnprocessableEntityException {
  return new UnprocessableEntityException({
    statusCode: 422,
    code: 'PROVIDER_JOINING_CURRENCY',
    message: `The joining service is priced in ${JOINING_SERVICE_CURRENCY}`,
  });
}

/** The latest decision as the profile and the admin rows name it (B-01). */
export interface ProviderLatestDecision {
  id: string;
  kind: ProviderReviewEventKind;
  at: Date;
}

export function toProviderLatestDecision(
  decision: { id: string; kind: ProviderReviewEventKind; createdAt: Date } | null | undefined,
): ProviderLatestDecision | null {
  return decision
    ? { id: decision.id, kind: decision.kind, at: decision.createdAt }
    : null;
}

/**
 * Waiting for approval: the review has the profile (PENDING) or the provider
 * is fixing it (NEEDS_CHANGES). He can edit the profile and the service he
 * joined with, and nothing operational (B-10).
 */
export function isProviderAwaitingApproval(
  provider: { status: ProviderStatus } | null | undefined,
): boolean {
  return (
    provider?.status === ProviderStatus.PENDING ||
    provider?.status === ProviderStatus.NEEDS_CHANGES
  );
}

/** The review steps an administrator takes; the provider's own are RESUBMITTED and REOPENED. */
export const PROVIDER_REVIEW_DECISION_KINDS: readonly ProviderReviewEventKind[] = [
  ProviderReviewEventKind.CHANGES_REQUESTED,
  ProviderReviewEventKind.REJECTED,
  ProviderReviewEventKind.APPROVED,
  ProviderReviewEventKind.SUSPENDED,
  ProviderReviewEventKind.ACTIVATED,
];

/** The decisions that explain themselves with notes. */
const NOTED_DECISIONS: ReadonlySet<ProviderReviewEventKind> = new Set([
  ProviderReviewEventKind.CHANGES_REQUESTED,
  ProviderReviewEventKind.REJECTED,
  ProviderReviewEventKind.SUSPENDED,
]);

/** The states a decision's notes explain to the provider. */
const NOTED_STATUSES: ReadonlySet<ProviderStatus> = new Set([
  ProviderStatus.NEEDS_CHANGES,
  ProviderStatus.REJECTED,
  ProviderStatus.SUSPENDED,
]);

/** The fields a note can point at, in the order the profile shows them. */
export const PROVIDER_REVIEW_FIELD_ORDER: readonly ProviderReviewField[] = [
  ProviderReviewField.GENERAL,
  ProviderReviewField.BUSINESS_NAME,
  ProviderReviewField.CATEGORY,
  ProviderReviewField.CITY,
  ProviderReviewField.DESCRIPTION,
  ProviderReviewField.SERVICE,
];

export interface ProviderFieldNote {
  field: ProviderReviewField;
  note: string;
}

export interface ProviderReviewDecisionView {
  kind: ProviderReviewEventKind;
  notes: readonly ProviderFieldNote[];
}

export interface CurrentProviderReviewNotes {
  /** The note about the whole profile, or null. */
  reviewNote: string | null;
  /** One note per field to fix (B-01), in the profile's order. */
  fieldNotes: ProviderFieldNote[];
}

export function sortProviderFieldNotes<T extends { field: ProviderReviewField }>(
  notes: readonly T[],
): T[] {
  return [...notes].sort(
    (left, right) =>
      PROVIDER_REVIEW_FIELD_ORDER.indexOf(left.field) -
      PROVIDER_REVIEW_FIELD_ORDER.indexOf(right.field),
  );
}

/**
 * The notes the provider and the review team read now: those of the latest
 * administrator decision, while the profile is in a state that decision
 * explains. A refused profile the provider reopened (B-02) is NEEDS_CHANGES
 * and still reads the refusal's reason, which stays its first note until the
 * next decision.
 */
export function currentProviderReviewNotes(
  status: ProviderStatus,
  latestDecision: ProviderReviewDecisionView | null,
): CurrentProviderReviewNotes {
  if (
    !latestDecision ||
    !NOTED_STATUSES.has(status) ||
    !NOTED_DECISIONS.has(latestDecision.kind)
  ) {
    return { reviewNote: null, fieldNotes: [] };
  }
  const general = latestDecision.notes.find(
    (note) => note.field === ProviderReviewField.GENERAL,
  );
  return {
    reviewNote: general?.note ?? null,
    fieldNotes: sortProviderFieldNotes(
      latestDecision.notes
        .filter((note) => note.field !== ProviderReviewField.GENERAL)
        .map((note) => ({ field: note.field, note: note.note })),
    ),
  };
}
