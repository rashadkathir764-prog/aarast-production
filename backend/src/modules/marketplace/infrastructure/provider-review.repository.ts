import { Prisma, ProviderReviewEventKind } from '@prisma/client';
import {
  PROVIDER_REVIEW_DECISION_KINDS,
  type ProviderFieldNote,
} from '../public/provider-review';

type Client = Prisma.TransactionClient;

/**
 * The provider's latest administrator decision with its notes, as a
 * provider include: the notes the profile shows come from it
 * (`currentProviderReviewNotes`).
 */
export const latestProviderDecisionInclude = {
  reviewEvents: {
    where: { kind: { in: [...PROVIDER_REVIEW_DECISION_KINDS] } },
    orderBy: { createdAt: 'desc' },
    take: 1,
    include: { notes: true },
  },
} satisfies Prisma.ProviderInclude;

export type ProviderReviewEventRecord = Prisma.ProviderReviewEventGetPayload<{
  include: { notes: true };
}>;

export function findLatestProviderDecision(
  client: Client,
  providerId: string,
): Promise<ProviderReviewEventRecord | null> {
  return client.providerReviewEvent.findFirst({
    where: {
      providerId,
      kind: { in: [...PROVIDER_REVIEW_DECISION_KINDS] },
    },
    orderBy: { createdAt: 'desc' },
    include: { notes: true },
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
    orderBy: { createdAt: 'asc' },
    include: { notes: true },
  });
}
