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
  lines?: Prisma.JsonValue | null;
  deliveryDays?: number | null;
  changes: Prisma.InputJsonValue | typeof Prisma.DbNull;
}

/** B-07: lines as stored, or the database null. */
export function offerLinesJson(
  lines: Prisma.JsonValue | null | undefined,
): Prisma.InputJsonValue | typeof Prisma.DbNull {
  return lines === null || lines === undefined
    ? Prisma.DbNull
    : (lines as Prisma.InputJsonValue);
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
      lines: offerLinesJson(fields.lines),
      deliveryDays: fields.deliveryDays ?? null,
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
  lines: Prisma.JsonValue | null;
  deliveryDays: number | null;
  currentVersionNo: number;
  versionChanges: Prisma.InputJsonValue;
  revisedAt: Date;
  /** Set when this version is told to the customer; kept otherwise. */
  revisionNoticeAt?: Date;
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
      lines: offerLinesJson(revision.lines),
      deliveryDays: revision.deliveryDays,
      currentVersionNo: revision.currentVersionNo,
      versionChanges: revision.versionChanges,
      revisedAt: revision.revisedAt,
      ...(revision.revisionNoticeAt
        ? { revisionNoticeAt: revision.revisionNoticeAt }
        : {}),
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

/** Where a batch of the hourly job stopped: the last request it listed. */
export interface QuoteRequestDeadlineCursor {
  expiresAt: Date;
  id: string;
}

/**
 * Requests still waiting for the provider whose deadline has passed, oldest
 * first, after the cursor in (expiresAt, id) order: every request is listed
 * once per run.
 */
export function listOverdueQuoteRequestIds(
  client: Client,
  now: Date,
  take: number,
  cursor: QuoteRequestDeadlineCursor | null = null,
) {
  return client.quoteRequest.findMany({
    where: {
      status: { in: WAITING_FOR_PROVIDER },
      expiresAt: { lte: now },
      OR: cursor
        ? [
            { expiresAt: { gt: cursor.expiresAt } },
            { expiresAt: cursor.expiresAt, id: { gt: cursor.id } },
          ]
        : undefined,
    },
    select: { id: true, expiresAt: true },
    orderBy: [{ expiresAt: 'asc' }, { id: 'asc' }],
    take,
  });
}

/**
 * Requests waiting for the provider that end within the window and were not
 * warned yet, after the cursor as above.
 */
export function listQuoteRequestIdsToWarn(
  client: Client,
  now: Date,
  until: Date,
  take: number,
  cursor: QuoteRequestDeadlineCursor | null = null,
) {
  return client.quoteRequest.findMany({
    where: {
      status: { in: WAITING_FOR_PROVIDER },
      expiresAt: { gt: now, lte: until },
      expiryWarnedAt: null,
      OR: cursor
        ? [
            { expiresAt: { gt: cursor.expiresAt } },
            { expiresAt: cursor.expiresAt, id: { gt: cursor.id } },
          ]
        : undefined,
    },
    select: { id: true, expiresAt: true },
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
