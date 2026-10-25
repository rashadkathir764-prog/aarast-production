import { Prisma, QuoteOfferStatus, QuoteRequestStatus } from '@prisma/client';

// Marketplace's own writes for an offer's versions (B-06), its withdrawal
// (B-03) and a request's answer deadline (B-04). Every transition is
// conditional on the state it leaves, so a retry or a second instance of the
// hourly job changes nothing twice.

type Client = Prisma.TransactionClient;

const WAITING_FOR_PROVIDER = [QuoteRequestStatus.SENT, QuoteRequestStatus.VIEWED];

export interface QuoteOfferVersionFields {
  quoteOfferId: string;
  versionNo: number;
  title: string | null;
  message: string | null;
  amount: Prisma.Decimal | string | null;
  currency: string;
  validUntil: Date | null;
  changes: Prisma.InputJsonValue | typeof Prisma.DbNull;
}

export function createQuoteOfferVersion(client: Client, fields: QuoteOfferVersionFields) {
  return client.quoteOfferVersion.create({
    data: {
      quoteOfferId: fields.quoteOfferId,
      versionNo: fields.versionNo,
      title: fields.title,
      message: fields.message,
      amount: fields.amount,
      currency: fields.currency,
      validUntil: fields.validUntil,
      changes: fields.changes,
    },
  });
}

export interface QuoteOfferRevision {
  title: string | null;
  message: string | null;
  amount: string;
  currency: string;
  validUntil: Date | null;
  currentVersionNo: number;
  versionChanges: Prisma.InputJsonValue;
  revisedAt: Date;
}

/** The new current version, only while the offer is still the one read (PENDING, that version). */
export function reviseQuoteOffer(
  client: Client,
  id: string,
  previousVersionNo: number,
  revision: QuoteOfferRevision,
) {
  return client.quoteOffer.updateMany({
    where: { id, status: QuoteOfferStatus.PENDING, currentVersionNo: previousVersionNo },
    data: {
      title: revision.title,
      message: revision.message,
      amount: revision.amount,
      currency: revision.currency,
      validUntil: revision.validUntil,
      currentVersionNo: revision.currentVersionNo,
      versionChanges: revision.versionChanges,
      revisedAt: revision.revisedAt,
    },
  });
}

export function withdrawPendingOffer(client: Client, id: string, at: Date, reason: string | null) {
  return client.quoteOffer.updateMany({
    where: { id, status: QuoteOfferStatus.PENDING },
    data: { status: QuoteOfferStatus.WITHDRAWN, withdrawnAt: at, withdrawnReason: reason },
  });
}

/** After a withdrawal the customer waits again: a new answer window and a new warning. */
export function reopenAnsweredRequest(client: Client, id: string, expiresAt: Date) {
  return client.quoteRequest.updateMany({
    where: { id, status: QuoteRequestStatus.RESPONDED },
    data: { status: QuoteRequestStatus.VIEWED, expiresAt, expiryWarnedAt: null },
  });
}

/** Requests still waiting for the provider whose deadline has passed, oldest first. */
export function listOverdueQuoteRequestIds(client: Client, now: Date, take: number) {
  return client.quoteRequest.findMany({
    where: { status: { in: WAITING_FOR_PROVIDER }, expiresAt: { lte: now } },
    select: { id: true },
    orderBy: [{ expiresAt: 'asc' }, { id: 'asc' }],
    take,
  });
}

/** Requests waiting for the provider that end within the window and were not warned yet. */
export function listQuoteRequestIdsToWarn(client: Client, now: Date, until: Date, take: number) {
  return client.quoteRequest.findMany({
    where: {
      status: { in: WAITING_FOR_PROVIDER },
      expiresAt: { gt: now, lte: until },
      expiryWarnedAt: null,
    },
    select: { id: true },
    orderBy: [{ expiresAt: 'asc' }, { id: 'asc' }],
    take,
  });
}

export function findQuoteRequestDeadline(client: Client, id: string) {
  return client.quoteRequest.findUnique({
    where: { id },
    select: {
      id: true,
      status: true,
      expiresAt: true,
      expiryWarnedAt: true,
      userId: true,
      weddingPlanId: true,
      providerId: true,
      conversationId: true,
      contactName: true,
      provider: { select: { userId: true, businessName: true } },
    },
  });
}

export function expireOverdueQuoteRequest(
  client: Client,
  id: string,
  previousStatus: QuoteRequestStatus,
  now: Date,
) {
  return client.quoteRequest.updateMany({
    where: { id, status: previousStatus, expiresAt: { lte: now } },
    data: { status: QuoteRequestStatus.EXPIRED, expiredAt: now },
  });
}

export function markQuoteRequestExpiryWarned(
  client: Client,
  id: string,
  expiresAt: Date,
  now: Date,
) {
  return client.quoteRequest.updateMany({
    where: {
      id,
      status: { in: WAITING_FOR_PROVIDER },
      expiresAt,
      expiryWarnedAt: null,
    },
    data: { expiryWarnedAt: now },
  });
}
