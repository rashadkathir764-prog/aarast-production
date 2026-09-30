import {
  PlanProviderLinkStatus,
  Prisma,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from '@prisma/client';
import { MARKETPLACE_QUOTE_INCLUDE } from '../../../marketplace/marketplace.contracts';

type Client = Prisma.TransactionClient;

export interface QuoteRequestCreateData {
  userId: string;
  providerId: string;
  weddingPlanId?: string | null;
  serviceId?: string | null;
  eventDate?: Date | null;
  location?: Prisma.InputJsonValue | typeof Prisma.JsonNull;
  cityId?: string | null;
  guestCount?: number | null;
  contactName?: string | null;
  contactPhone?: string | null;
  contactNormalizedPhone?: string | null;
  message?: string | null;
  budgetMin?: Prisma.Decimal | string | null;
  budgetMax?: Prisma.Decimal | string | null;
}

export function findOfferSeed(client: Client, id: string) {
  return client.quoteOffer.findUnique({
    where: { id },
    select: {
      providerId: true,
      provider: { select: { userId: true } },
      quoteRequest: { select: { userId: true, weddingPlanId: true } },
    },
  });
}

export function lockProviderForOfferAcceptance(client: Client, providerId: string) {
  return client.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "Provider" WHERE "id" = ${providerId} FOR SHARE`,
  );
}

export function findOfferForAcceptance(client: Client, id: string, weddingPlanId: string) {
  return client.quoteOffer.findUnique({
    where: { id },
    include: {
      quoteRequest: { include: { service: true } },
      provider: { select: { businessName: true, userId: true } },
      providerLinks: { where: { weddingPlanId } },
    },
  });
}

export function requireOfferForAcceptance(client: Client, id: string, weddingPlanId: string) {
  return client.quoteOffer.findUniqueOrThrow({
    where: { id },
    include: {
      quoteRequest: { include: { service: true } },
      provider: { select: { businessName: true, userId: true } },
      providerLinks: { where: { weddingPlanId } },
    },
  });
}

export function findProviderOperationalStatus(client: Client, providerId: string) {
  return client.provider.findUnique({ where: { id: providerId }, select: { status: true } });
}

export function acceptPendingOffer(client: Client, id: string) {
  return client.quoteOffer.updateMany({
    where: { id, status: QuoteOfferStatus.PENDING },
    data: { status: QuoteOfferStatus.ACCEPTED },
  });
}

export function listOtherPendingOffers(client: Client, quoteRequestId: string, acceptedOfferId: string) {
  return client.quoteOffer.findMany({
    where: { quoteRequestId, id: { not: acceptedOfferId }, status: QuoteOfferStatus.PENDING },
    select: { id: true },
  });
}

export function rejectOtherPendingOffers(client: Client, quoteRequestId: string, acceptedOfferId: string) {
  return client.quoteOffer.updateMany({
    where: { quoteRequestId, id: { not: acceptedOfferId }, status: QuoteOfferStatus.PENDING },
    data: { status: QuoteOfferStatus.REJECTED },
  });
}

export function acceptQuoteRequest(client: Client, id: string, previousStatus: QuoteRequestStatus, acceptedAt: Date) {
  return client.quoteRequest.updateMany({
    where: { id, status: previousStatus },
    data: { status: QuoteRequestStatus.ACCEPTED, acceptedAt },
  });
}

export function linkAcceptedProvider(
  client: Client,
  weddingPlanId: string,
  providerId: string,
  quoteRequestId: string,
  quoteOfferId: string,
) {
  return client.planProviderLink.upsert({
    where: { weddingPlanId_providerId: { weddingPlanId, providerId } },
    update: { quoteRequestId, quoteOfferId, status: PlanProviderLinkStatus.ACTIVE },
    create: { weddingPlanId, providerId, quoteRequestId, quoteOfferId, status: PlanProviderLinkStatus.ACTIVE },
  });
}

export function findOfferForRejection(client: Client, id: string) {
  return client.quoteOffer.findUnique({ where: { id }, include: { quoteRequest: true } });
}

export function rejectPendingOffer(client: Client, id: string) {
  return client.quoteOffer.updateMany({
    where: { id, status: QuoteOfferStatus.PENDING },
    data: { status: QuoteOfferStatus.REJECTED },
  });
}

export function rejectQuoteRequest(client: Client, id: string, previousStatus: QuoteRequestStatus, rejectedAt: Date) {
  return client.quoteRequest.updateMany({
    where: { id, status: previousStatus },
    data: { status: QuoteRequestStatus.REJECTED, rejectedAt },
  });
}

export function findProviderAccountForOffer(client: Client, providerId: string) {
  return client.provider.findUnique({ where: { id: providerId }, select: { userId: true } });
}

export function requireOfferAfterRejection(client: Client, id: string) {
  return client.quoteOffer.findUniqueOrThrow({ where: { id } });
}

export function findRequestCancellationSeed(client: Client, id: string, requesterId?: string) {
  return client.quoteRequest.findFirst({
    where: requesterId ? { id, userId: requesterId } : { id },
    select: {
      userId: true,
      weddingPlanId: true,
      providerId: true,
      conversationId: true,
      provider: { select: { userId: true } },
    },
  });
}

export function findRequestCancellationState(client: Client, id: string) {
  return client.quoteRequest.findUnique({
    where: { id },
    select: { userId: true, weddingPlanId: true, providerId: true, conversationId: true, status: true },
  });
}

export function cancelQuoteRequest(client: Client, id: string, previousStatus: QuoteRequestStatus, cancelledAt: Date) {
  return client.quoteRequest.updateMany({
    where: { id, status: previousStatus },
    data: { status: QuoteRequestStatus.CANCELLED, cancelledAt },
  });
}

export function requireCancelledQuoteRequest(client: Client, id: string) {
  return client.quoteRequest.findUniqueOrThrow({ where: { id }, include: MARKETPLACE_QUOTE_INCLUDE });
}

export function findProviderAccountForRequest(client: Client, providerId: string) {
  return client.provider.findUnique({ where: { id: providerId }, select: { userId: true } });
}

export function lockProviderForRequestCreation(client: Client, providerId: string) {
  return client.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "Provider" WHERE "id" = ${providerId} FOR UPDATE`,
  );
}

export function findActiveProviderForRequest(client: Client, providerId: string) {
  return client.provider.findFirst({ where: { id: providerId, status: ProviderStatus.ACTIVE } });
}

export function findActiveRequestCycle(
  client: Client,
  requesterId: string,
  providerId: string,
  weddingPlanId: string | null,
  serviceId: string | null,
  eventDate: Date | null,
  cityId: string | null,
) {
  return client.quoteRequest.findFirst({
    where: {
      userId: requesterId, providerId, weddingPlanId, serviceId, eventDate, cityId,
      status: { in: [QuoteRequestStatus.SENT, QuoteRequestStatus.VIEWED, QuoteRequestStatus.RESPONDED] },
    },
    orderBy: { createdAt: 'desc' },
    include: { offers: { where: { status: QuoteOfferStatus.PENDING }, orderBy: { createdAt: 'desc' } } },
  });
}

export function createQuoteRequest(client: Client, data: QuoteRequestCreateData, conversationId: string) {
  return client.quoteRequest.create({
    data: { ...data, conversationId },
    include: MARKETPLACE_QUOTE_INCLUDE,
  });
}
