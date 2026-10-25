import { Prisma, ProviderReviewEventKind } from '@prisma/client';
import {
  PROVIDER_REVIEW_DECISION_KINDS,
  type ProviderFieldNote,
} from '../public/provider-review';

type Client = Prisma.TransactionClient;

/**
 * The review steps in the order they happened. Every step is written under
 * the provider's row lock, so its `sequence` grows in that order even when
 * two steps share a `createdAt`; this is the one ordering every read uses.
 */
const NEWEST_STEP_FIRST = { sequence: 'desc' } as const;
const OLDEST_STEP_FIRST = { sequence: 'asc' } as const;

/** The latest administrator decision with its notes. */
const latestDecisionQuery = {
  where: { kind: { in: [...PROVIDER_REVIEW_DECISION_KINDS] } },
  orderBy: NEWEST_STEP_FIRST,
  include: { notes: true },
} satisfies Prisma.ProviderReviewEventFindFirstArgs;

/**
 * The provider's latest administrator decision with its notes, as a
 * provider include: the notes the profile shows come from it
 * (`currentProviderReviewNotes`).
 */
export const latestProviderDecisionInclude = {
  reviewEvents: { ...latestDecisionQuery, take: 1 },
} satisfies Prisma.ProviderInclude;

export type ProviderReviewEventRecord = Prisma.ProviderReviewEventGetPayload<{
  include: { notes: true };
}>;

export function findLatestProviderDecision(
  client: Client,
  providerId: string,
): Promise<ProviderReviewEventRecord | null> {
  return client.providerReviewEvent.findFirst({
    ...latestDecisionQuery,
    where: { ...latestDecisionQuery.where, providerId },
  });
}

export function recordProviderReviewEvent(
  client: Client,
  event: {
    providerId: string;
    kind: ProviderReviewEventKind;
    actorId: string | null;
    createdAt: Date;
    notes?: readonly ProviderFieldNote[];
  },
): Promise<ProviderReviewEventRecord> {
  return client.providerReviewEvent.create({
    data: {
      providerId: event.providerId,
      kind: event.kind,
      actorId: event.actorId,
      createdAt: event.createdAt,
      notes: {
        create: (event.notes ?? []).map((note) => ({
          field: note.field,
          note: note.note,
        })),
      },
    },
    include: { notes: true },
  });
}

/** Oldest first. */
export function listProviderReviewEvents(
  client: Client,
  providerId: string,
): Promise<ProviderReviewEventRecord[]> {
  return client.providerReviewEvent.findMany({
    where: { providerId },
    orderBy: OLDEST_STEP_FIRST,
    include: { notes: true },
  });
}

/**
 * The joining rule (B-10, D41): a profile goes to review, and is approved,
 * only while it has an active service priced above zero. Resubmitting,
 * approving and adding the joining service before approval all read this
 * one rule; apply creates such a service in the same write.
 */
export async function hasJoiningService(
  client: Client,
  providerId: string,
): Promise<boolean> {
  const priced = await client.providerService.count({
    where: { providerId, isActive: true, basePrice: { gt: 0 } },
  });
  return priced > 0;
}
