import {
  BookingStatus,
  Prisma,
  ProviderClaimStatus,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
  ReviewStatus,
} from '@prisma/client';
import { priceStampForNewService, priceStampForServiceUpdate } from './service-price-stamp';

type Client = Prisma.TransactionClient;

const serviceInclude = {
  images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
} satisfies Prisma.ProviderServiceInclude;

const quoteInclude = {
  service: true,
  offers: { orderBy: { createdAt: 'desc' } },
  // G25 (B-24): the booking with its asked changes.
  booking: { include: { changes: true } },
} satisfies Prisma.QuoteRequestInclude;

export interface ProviderProfileChanges {
  businessName?: string;
  ownerName?: string | null;
  phone?: string;
  whatsapp?: string | null;
  email?: string | null;
  description?: string | null;
  address?: string | null;
  cityId?: string;
  primaryCategoryId?: string;
  latitude?: string | null;
  longitude?: string | null;
  logoUrl?: string | null;
  coverUrl?: string | null;
  dailyBookingCapacity?: number;
}

export interface ServiceFields {
  providerId: string;
  categoryId: string;
  title: string;
  description: string | null;
  basePrice: string | null;
  priceUnit: string | null;
  currency: string;
  cityId: string | null;
}

export interface ServiceChanges {
  categoryId?: string;
  title?: string;
  description?: string | null;
  basePrice?: string | null;
  priceUnit?: string | null;
  currency?: string;
  cityId?: string | null;
  isActive?: boolean;
}

export interface ImageFields {
  serviceId: string;
  imageUrl: string;
  altText: string | null;
  sortOrder: number;
}

export interface ImageChanges {
  imageUrl?: string;
  altText?: string | null;
  sortOrder?: number;
}

export interface PackageFields {
  providerId: string;
  serviceId: string | null;
  title: string;
  description: string | null;
  price: string | null;
  currency: string;
  items?: Prisma.InputJsonValue;
}

export interface PackageChanges {
  serviceId?: string | null;
  title?: string;
  description?: string | null;
  price?: string | null;
  currency?: string;
  items?: Prisma.InputJsonValue;
  isActive?: boolean;
}

export interface OfferFields {
  quoteRequestId: string;
  providerId: string;
  title: string | null;
  message: string;
  amount: string;
  currency: string;
  validUntil: Date | null;
  lines: Prisma.JsonValue | null;
  deliveryDays: number | null;
}

export function lockExistingApplication(client: Client, userId: string) {
  return client.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "Provider" WHERE "userId" = ${userId} FOR UPDATE`,
  );
}

export interface JoiningServiceFields {
  title: string;
  description: string | null;
  basePrice: string;
  currency: string;
}

/**
 * The application with its priced services (B-10), in one write: the
 * services sit in the profile's category and stay hidden until approval,
 * since every customer read requires an ACTIVE provider.
 */
export function createProviderApplication(client: Client, fields: {
  userId: string; cityId: string; primaryCategoryId: string;
  businessName: string; phone: string; description: string | null;
  services: readonly JoiningServiceFields[];
}) {
  const { services, ...provider } = fields;
  return client.provider.create({
    data: {
      ...provider,
      status: ProviderStatus.PENDING,
      services: {
        create: services.map((service) => ({
          ...service,
          categoryId: provider.primaryCategoryId,
          priceUpdatedAt: priceStampForNewService(service.basePrice),
        })),
      },
    },
  });
}

export function updateProviderProfile(client: Client, providerId: string, changes: ProviderProfileChanges) {
  return client.provider.update({ where: { id: providerId }, data: changes });
}

export function countProviderDashboard(client: Client, providerId: string) {
  return Promise.all([
    client.providerService.count({ where: { providerId } }),
    client.providerService.count({ where: { providerId, isActive: true } }),
    client.quoteRequest.count({ where: { providerId } }),
    client.quoteRequest.count({ where: { providerId, status: QuoteRequestStatus.SENT } }),
  ]);
}

export function listOwnedServices(client: Client, providerId: string) {
  return client.providerService.findMany({
    where: { providerId }, include: serviceInclude, orderBy: { createdAt: 'desc' },
  });
}

export function createProviderService(client: Client, fields: ServiceFields) {
  return client.providerService.create({
    data: { ...fields, priceUpdatedAt: priceStampForNewService(fields.basePrice) },
    include: serviceInclude,
  });
}

export async function updateProviderService(client: Client, serviceId: string, changes: ServiceChanges) {
  const priceStamp = await priceStampForServiceUpdate(client, serviceId, changes);
  return client.providerService.update({
    where: { id: serviceId }, data: { ...changes, ...priceStamp }, include: serviceInclude,
  });
}

export function deactivateProviderService(client: Client, serviceId: string) {
  return client.providerService.update({
    where: { id: serviceId }, data: { isActive: false }, include: serviceInclude,
  });
}

export function createServiceImage(client: Client, fields: ImageFields) {
  return client.providerServiceImage.create({ data: fields });
}

export function updateServiceImage(client: Client, imageId: string, changes: ImageChanges) {
  return client.providerServiceImage.update({ where: { id: imageId }, data: changes });
}

export function deleteServiceImage(client: Client, imageId: string) {
  return client.providerServiceImage.delete({ where: { id: imageId } });
}

export function listOwnedPackages(client: Client, providerId: string) {
  return client.providerPackage.findMany({
    where: { providerId }, include: { service: true }, orderBy: { createdAt: 'desc' },
  });
}

export function createProviderPackage(client: Client, fields: PackageFields) {
  return client.providerPackage.create({ data: fields, include: { service: true } });
}

export function updateProviderPackage(client: Client, packageId: string, changes: PackageChanges) {
  return client.providerPackage.update({ where: { id: packageId }, data: changes, include: { service: true } });
}

export function deactivateProviderPackage(client: Client, packageId: string) {
  return client.providerPackage.update({
    where: { id: packageId }, data: { isActive: false }, include: { service: true },
  });
}

export function listProviderQuoteRequests(client: Client, providerId: string) {
  return client.quoteRequest.findMany({
    where: { providerId }, include: quoteInclude, orderBy: { createdAt: 'desc' },
  });
}

export function findProviderQuoteRequest(client: Client, id: string, providerId: string) {
  return client.quoteRequest.findFirst({ where: { id, providerId }, include: quoteInclude });
}

export function findProviderQuoteMutationSeed(client: Client, id: string) {
  return client.quoteRequest.findUnique({
    where: { id },
    select: { providerId: true, userId: true, weddingPlanId: true, conversationId: true },
  });
}

export function findLockedProviderQuoteRequest(client: Client, id: string, providerId: string) {
  return client.quoteRequest.findFirst({ where: { id, providerId } });
}

export function transitionProviderQuoteRequest(
  client: Client, id: string, previousStatus: QuoteRequestStatus,
  status: QuoteRequestStatus, rejectedAt?: Date,
  decline?: { reason: string | null; message: string | null },
) {
  return client.quoteRequest.updateMany({
    where: { id, status: previousStatus },
    data: {
      status,
      ...(rejectedAt ? { rejectedAt } : {}),
      ...(decline ? { declineReason: decline.reason, declineMessage: decline.message } : {}),
    },
  });
}

export function requireProviderQuoteRequest(client: Client, id: string) {
  return client.quoteRequest.findUniqueOrThrow({ where: { id }, include: quoteInclude });
}

/** The request's live offer; a withdrawn one (B-03) leaves room for a new offer. */
export function findExistingQuoteOffer(client: Client, quoteRequestId: string) {
  return client.quoteOffer.findFirst({
    where: { quoteRequestId, status: { not: QuoteOfferStatus.WITHDRAWN } },
    select: { id: true },
  });
}

export function createQuoteOffer(client: Client, fields: OfferFields) {
  const { lines, ...rest } = fields;
  return client.quoteOffer.create({
    data: {
      ...rest,
      lines: lines === null ? Prisma.DbNull : (lines as Prisma.InputJsonValue),
    },
  });
}

export function markQuoteRequestResponded(client: Client, quoteRequestId: string) {
  return client.quoteRequest.update({
    where: { id: quoteRequestId }, data: { status: QuoteRequestStatus.RESPONDED },
  });
}

export function findOfferMutationSeed(client: Client, id: string) {
  return client.quoteOffer.findUnique({
    where: { id },
    select: {
      providerId: true,
      quoteRequest: { select: { userId: true, weddingPlanId: true, conversationId: true } },
    },
  });
}

export function findLockedProviderOffer(client: Client, id: string, providerId: string) {
  return client.quoteOffer.findFirst({
    where: { id, providerId },
    include: {
      quoteRequest: {
        select: { status: true, weddingPlanId: true, userId: true, conversationId: true },
      },
    },
  });
}

export function requireQuoteOffer(client: Client, id: string) {
  return client.quoteOffer.findUniqueOrThrow({ where: { id } });
}

export function listProviderReviews(client: Client, providerId: string) {
  return client.providerReview.findMany({ where: { providerId }, orderBy: { createdAt: 'desc' } });
}

/** One review of this provider's, or null. */
export function findProviderReview(client: Client, reviewId: string, providerId: string) {
  return client.providerReview.findFirst({ where: { id: reviewId, providerId } });
}

/** B-09: writes his one reply; 0 rows when the review already has one. */
export function writeReviewReply(
  client: Client,
  reviewId: string,
  providerId: string,
  body: string,
  at: Date,
) {
  return client.providerReview.updateMany({
    where: { id: reviewId, providerId, replyBody: null },
    data: { replyBody: body, repliedAt: at, replyStatus: ReviewStatus.PUBLISHED },
  });
}

export function findProviderByUserId(client: Client, userId: string) {
  return client.provider.findUnique({ where: { userId } });
}

export function findPreliminaryProvider(client: Client, userId: string) {
  return client.provider.findUnique({ where: { userId }, select: { id: true } });
}

export function lockOwnedServiceRow(client: Client, providerId: string, serviceId: string, mode: 'SHARE' | 'UPDATE') {
  return mode === 'UPDATE'
    ? client.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT "id" FROM "ProviderService" WHERE "id" = ${serviceId} AND "providerId" = ${providerId} FOR UPDATE`,
      )
    : client.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT "id" FROM "ProviderService" WHERE "id" = ${serviceId} AND "providerId" = ${providerId} FOR SHARE`,
      );
}

export function findOwnedServiceAfterLock(client: Client, serviceId: string) {
  return client.providerService.findUnique({ where: { id: serviceId }, include: serviceInclude });
}

export function lockOwnedImageRow(client: Client, serviceId: string, imageId: string) {
  return client.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "ProviderServiceImage" WHERE "id" = ${imageId} AND "serviceId" = ${serviceId} FOR UPDATE`,
  );
}

export function findOwnedImageAfterLock(client: Client, imageId: string) {
  return client.providerServiceImage.findUnique({ where: { id: imageId } });
}

export function lockOwnedPackageRow(client: Client, providerId: string, packageId: string) {
  return client.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "ProviderPackage" WHERE "id" = ${packageId} AND "providerId" = ${providerId} FOR UPDATE`,
  );
}

export function findOwnedService(client: Client, serviceId: string, providerId: string) {
  return client.providerService.findFirst({ where: { id: serviceId, providerId }, include: serviceInclude });
}

export function findOwnedPackage(client: Client, packageId: string, providerId: string) {
  return client.providerPackage.findFirst({ where: { id: packageId, providerId } });
}

/** The provider's activity since `from`, and their bookings around `today` (V1 checklist 4.19). */
export function providerActivity(client: Client, providerId: string, from: Date, today: Date) {
  const decided = [QuoteOfferStatus.ACCEPTED, QuoteOfferStatus.REJECTED];
  return Promise.all([
    client.providerProfileViewDay.aggregate({
      where: { providerId, day: { gte: from } },
      _sum: { views: true },
    }),
    client.quoteRequest.count({ where: { providerId, createdAt: { gte: from } } }),
    client.quoteOffer.count({
      where: { providerId, status: QuoteOfferStatus.ACCEPTED, createdAt: { gte: from } },
    }),
    client.quoteOffer.count({
      where: { providerId, status: { in: decided }, createdAt: { gte: from } },
    }),
    client.booking.count({
      where: { providerId, status: BookingStatus.CONFIRMED, eventDate: { gte: today } },
    }),
    client.booking.count({
      where: { providerId, status: BookingStatus.CONFIRMED, eventDate: { lt: today } },
    }),
  ]);
}

/**
 * An active listing the back office made under one of these phone spellings,
 * not yet claimed (V1 checklist 4.18), with the city and category p02 names.
 */
export function findUnclaimedListing(client: Client, phones: readonly string[]) {
  return client.provider.findFirst({
    where: { userId: null, status: ProviderStatus.ACTIVE, phone: { in: [...phones] } },
    select: { id: true, businessName: true, phone: true, cityId: true, primaryCategoryId: true },
    orderBy: { createdAt: 'asc' },
  });
}

/** An open claim of this listing, or by this account (B-12): at most one of each. */
export function findPendingClaim(client: Client, where: { providerId: string } | { userId: string }) {
  return client.providerClaimRequest.findFirst({
    where: { ...where, status: ProviderClaimStatus.PENDING },
    select: { id: true, providerId: true, userId: true },
  });
}

const claimInclude = {
  provider: { select: { id: true, businessName: true } },
} satisfies Prisma.ProviderClaimRequestInclude;

/** Asks the back office to hand a locked, unclaimed listing to the account that proved its phone (B-12). */
export function createClaimRequest(client: Client, providerId: string, userId: string) {
  return client.providerClaimRequest.create({
    data: { providerId, userId },
    include: claimInclude,
  });
}

/** The account's latest claim of a listing, whatever came of it. */
export function findLatestClaim(client: Client, userId: string) {
  return client.providerClaimRequest.findFirst({
    where: { userId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    include: claimInclude,
  });
}

/** B-01: the provider sends the profile back to review. */
export function markProviderResubmitted(client: Client, providerId: string, at: Date) {
  return client.provider.update({
    where: { id: providerId },
    data: {
      status: ProviderStatus.PENDING,
      resubmittedAt: at,
      resubmitCount: { increment: 1 },
    },
  });
}

/** B-02: a refused provider reopens the profile to fix it. */
export function markProviderReopened(client: Client, providerId: string, at: Date) {
  return client.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.NEEDS_CHANGES, reopenedAt: at },
  });
}

/** Before approval every service is a joining service and follows the profile's category (B-10). */
export function moveJoiningServicesToCategory(client: Client, providerId: string, categoryId: string) {
  return client.providerService.updateMany({ where: { providerId }, data: { categoryId } });
}
