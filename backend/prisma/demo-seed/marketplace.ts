// Providers and everything customers did with them: requests, offers,
// conversations, bookings, links to plans, reviews and the studio's calendar.
import {
  BookingStatus,
  ConversationEventType,
  ConversationScope,
  PlanProviderLinkStatus,
  Prisma,
  PrismaClient,
  ProviderReviewEventKind,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
  ReviewStatus,
} from '@prisma/client';
import { DEMO_ACCOUNTS, userId } from './accounts';
import {
  CLAIMS,
  offerId,
  PROVIDERS,
  providerId,
  REQUESTS,
  requestId,
  serviceId,
  STUDIO_BLOCKED_DAYS,
  STUDIO_ID,
  STUDIO_REVIEW,
  type ProviderSpec,
  type RequestSpec,
  type ReviewStepSpec,
} from './market-data';
import { planId } from './plan';
import { day, demoId, demoUuid, inDays } from './support';
import { quoteRequestAnswerDeadline } from '../../src/marketplace/quote-lifecycle';
import {
  quoteOfferChanges,
  toQuoteOfferChangesJson,
} from '../../src/modules/marketplace/public/quote-offer-versions';

const DAY_MS = 24 * 60 * 60 * 1000;

async function resolveCities(prisma: PrismaClient): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  const names = new Set(PROVIDERS.map((provider) => provider.city));
  for (const nameAr of names) {
    const found = await prisma.city.findFirst({ where: { nameAr, countryCode: 'YE' } });
    if (found) {
      result.set(nameAr, found.id);
      continue;
    }
    // Only Dhamar is missing from the stock catalog; anything else means an unmigrated database.
    if (nameAr !== 'ذمار') {
      throw new Error(`City ${nameAr} is missing. Run the migrations first.`);
    }
    const created = await prisma.city.create({
      data: { nameAr, nameEn: 'Dhamar', countryCode: 'YE', isActive: true, sortOrder: 70 },
    });
    result.set(nameAr, created.id);
  }
  return result;
}

async function resolveCategories(prisma: PrismaClient): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  for (const slug of new Set(PROVIDERS.map((provider) => provider.categorySlug))) {
    const found = await prisma.providerCategory.findUnique({ where: { slug } });
    if (!found) {
      throw new Error(`Provider category ${slug} is missing. Run the migrations first.`);
    }
    result.set(slug, found.id);
  }
  return result;
}

export async function seedMarketplace(prisma: PrismaClient): Promise<void> {
  const cities = await resolveCities(prisma);
  const categories = await resolveCategories(prisma);

  for (const spec of PROVIDERS) await seedProvider(prisma, spec, cities, categories);
  await seedClaims(prisma);
  await seedStudioCalendar(prisma);
  await seedProfileViews(prisma);

  const sanaa = cities.get('صنعاء')!;
  for (const request of REQUESTS) await seedRequest(prisma, request, sanaa);

  await seedStudioReview(prisma);
  await seedFavorites(prisma);
}

async function seedProvider(
  prisma: PrismaClient,
  spec: ProviderSpec,
  cities: Map<string, string>,
  categories: Map<string, string>,
): Promise<void> {
  const id = providerId(spec);
  const reviewer = userId('adminNadia');
  const steps = reviewSteps(spec);
  const decisions = steps.filter((step) => !PROVIDER_STEPS.has(step.kind));
  const lastDecision = decisions[decisions.length - 1];
  const resubmits = steps.filter((step) => step.kind === ProviderReviewEventKind.RESUBMITTED);
  const reopens = steps.filter((step) => step.kind === ProviderReviewEventKind.REOPENED);
  const data = {
    userId: spec.owner ? userId(spec.owner) : null,
    cityId: cities.get(spec.city)!,
    primaryCategoryId: categories.get(spec.categorySlug)!,
    businessName: spec.businessName,
    ownerName: spec.ownerName,
    phone: spec.phone,
    whatsapp: spec.phone,
    description: spec.description,
    address: spec.address,
    status: spec.status,
    reviewedAt: lastDecision ? stepAt(lastDecision) : null,
    reviewedById: lastDecision ? reviewer : null,
    resubmittedAt: resubmits.length ? stepAt(resubmits[resubmits.length - 1]!) : null,
    resubmitCount: resubmits.length,
    reopenedAt: reopens.length ? stepAt(reopens[reopens.length - 1]!) : null,
    verifiedAt: spec.verified ? inDays(-14) : null,
    verifiedById: spec.verified ? reviewer : null,
    isFeatured: spec.featured ?? false,
  };
  await prisma.provider.upsert({ where: { id }, create: { id, ...data }, update: data });

  // The history is rewritten whole on every run, so it never doubles.
  await prisma.providerReviewEvent.deleteMany({ where: { providerId: id } });
  for (const [index, step] of steps.entries()) {
    await prisma.providerReviewEvent.create({
      data: {
        id: demoUuid(`review:${spec.key}:${index}`),
        providerId: id,
        kind: step.kind,
        actorId: PROVIDER_STEPS.has(step.kind)
          ? (spec.owner ? userId(spec.owner) : null)
          : reviewer,
        createdAt: stepAt(step),
        notes: {
          create: (step.notes ?? []).map((note) => ({ field: note.field, note: note.note })),
        },
      },
    });
  }

  const keepServices: string[] = [];
  const keepPackages: string[] = [];
  for (const service of spec.services) {
    const sid = serviceId(spec, service);
    keepServices.push(sid);
    const serviceData = {
      providerId: id,
      categoryId: categories.get(spec.categorySlug)!,
      title: service.title,
      description: service.description,
      basePrice: service.price,
      priceUnit: service.unit,
      currency: 'YER',
      priceUpdatedAt: inDays(-14),
      cityId: cities.get(spec.city)!,
      isActive: true,
      isFeatured: false,
    };
    await prisma.providerService.upsert({
      where: { id: sid },
      create: { id: sid, ...serviceData },
      update: serviceData,
    });
    if (service.packageItems) {
      const pid = demoUuid(`package:${spec.key}:${service.key}`);
      keepPackages.push(pid);
      const packageData = {
        providerId: id,
        serviceId: sid,
        title: service.title,
        description: service.description,
        price: service.price,
        currency: 'YER',
        items: service.packageItems,
        isActive: true,
      };
      await prisma.providerPackage.upsert({
        where: { id: pid },
        create: { id: pid, ...packageData },
        update: packageData,
      });
    }
  }
  if (id === STUDIO_ID) {
    // The studio's earlier hand-made rows: keep exactly the designed services and packages.
    await prisma.providerPackage.deleteMany({ where: { providerId: id, id: { notIn: keepPackages } } });
    await prisma.providerService.deleteMany({ where: { providerId: id, id: { notIn: keepServices } } });
  }
}

/** The steps the provider takes himself; the rest are an administrator's decisions. */
const PROVIDER_STEPS: ReadonlySet<ProviderReviewEventKind> = new Set([
  ProviderReviewEventKind.RESUBMITTED,
  ProviderReviewEventKind.REOPENED,
]);

/**
 * The provider's review history: as written, or one approval 30 days ago
 * for an owned provider that was decided. A listing nobody claimed was
 * made by the back office and was never reviewed.
 */
function reviewSteps(spec: ProviderSpec): ReviewStepSpec[] {
  if (spec.review) return spec.review;
  if (!spec.owner || spec.status !== ProviderStatus.ACTIVE) return [];
  return [{ kind: ProviderReviewEventKind.APPROVED, daysAgo: 30 }];
}

/** A step's time: its day at 10:02 (a04's «اليوم 10:02»), never later than now. */
function stepAt(step: ReviewStepSpec): Date {
  const at = inDays(-step.daysAgo);
  at.setHours(10, 2, 0, 0);
  const now = Date.now() - 60_000;
  return at.getTime() > now ? new Date(now) : at;
}

/** B-12: claims of listings, rewritten on every run. */
async function seedClaims(prisma: PrismaClient): Promise<void> {
  const claimants = CLAIMS.map((claim) => userId(claim.claimant));
  await prisma.providerClaimRequest.deleteMany({ where: { userId: { in: claimants } } });
  for (const claim of CLAIMS) {
    const listing = PROVIDERS.find((spec) => spec.key === claim.provider)!;
    await prisma.providerClaimRequest.create({
      data: {
        id: demoUuid(`claim:${claim.provider}`),
        providerId: providerId(listing),
        userId: userId(claim.claimant),
        createdAt: inDays(-claim.daysAgo),
      },
    });
  }
}

async function seedStudioCalendar(prisma: PrismaClient): Promise<void> {
  for (const date of STUDIO_BLOCKED_DAYS) {
    const id = demoUuid(`blocked:studio:${date}`);
    await prisma.providerBlockedDate.upsert({
      where: { id },
      create: { id, providerId: STUDIO_ID, date: day(date) },
      update: { providerId: STUDIO_ID, date: day(date) },
    });
  }
}

/** 30 days of profile views for the studio (412 in all, as p39 draws) and a lighter hall. */
async function seedProfileViews(prisma: PrismaClient): Promise<void> {
  const plans: Array<{ provider: string; perDay: number; extra: number }> = [
    { provider: STUDIO_ID, perDay: 13, extra: 22 },
    { provider: providerId(PROVIDERS.find((entry) => entry.key === 'hall')!), perDay: 9, extra: 0 },
  ];
  for (const plan of plans) {
    for (let offset = 0; offset < 30; offset += 1) {
      const dayValue = inDays(-offset);
      const views = plan.perDay + (offset < plan.extra ? 1 : 0);
      await prisma.providerProfileViewDay.upsert({
        where: { providerId_day: { providerId: plan.provider, day: dayValue } },
        create: { providerId: plan.provider, day: dayValue, views },
        update: { views },
      });
    }
  }
}

function serviceForRequest(provider: ProviderSpec, request: RequestSpec) {
  return (
    provider.services.find((service) => service.title === request.offer?.title) ??
    provider.services[provider.services.length - 1]
  );
}

async function seedRequest(prisma: PrismaClient, request: RequestSpec, cityId: string): Promise<void> {
  const provider = PROVIDERS.find((entry) => entry.key === request.provider);
  if (!provider) throw new Error(`Unknown provider ${request.provider}`);
  const customer = DEMO_ACCOUNTS.find((account) => account.key === request.customer)!;
  const customerId = userId(request.customer);
  const providerUserId = provider.owner ? userId(provider.owner) : null;
  const pid = providerId(provider);
  const rid = requestId(request.key);
  // A later request to the same provider in the same plan joins the earlier
  // request's conversation, which that request created and keeps current.
  const conversationId = demoId('conv', request.conversationOf ?? request.key);
  const weddingPlanId = request.plan ? planId(request.plan) : null;
  const lastMessageAt = request.messages?.length
    ? new Date(Math.max(...request.messages.map((message) => message.at.getTime())))
    : new Date(request.createdAt.getTime() + (request.offer ? DAY_MS : 0));

  if (!request.conversationOf) {
    const conversationData = {
      scope: weddingPlanId ? ConversationScope.PLAN : ConversationScope.ACCOUNT,
      weddingPlanId,
      accountRequesterUserId: weddingPlanId ? null : customerId,
      providerId: pid,
      createdByUserId: customerId,
      lastActivityAt: lastMessageAt,
    };
    await prisma.conversation.upsert({
      where: { id: conversationId },
      create: { id: conversationId, createdAt: request.createdAt, ...conversationData },
      update: conversationData,
    });

    const unreadForCustomer = request.messages?.some((message) => message.unread) ?? false;
    await upsertParticipant(prisma, conversationId, customerId, unreadForCustomer ? null : lastMessageAt);
    if (providerUserId) await upsertParticipant(prisma, conversationId, providerUserId, lastMessageAt);
  }

  const service = serviceForRequest(provider, request);
  const accepted = request.status === QuoteRequestStatus.ACCEPTED;
  const requestData = {
    userId: customerId,
    weddingPlanId,
    providerId: pid,
    serviceId: serviceId(provider, service),
    eventDate: request.eventDate,
    cityId,
    guestCount: request.guestCount ?? null,
    contactName: customer.name,
    contactPhone: customer.phone,
    contactNormalizedPhone: customer.phone,
    message: request.message,
    budgetMin: request.budget ? String(request.budget.min) : null,
    budgetMax: request.budget ? String(request.budget.max) : null,
    shareBudget: request.shareBudget ?? false,
    shareContact: request.shareContact ?? false,
    status: request.status,
    acceptedAt: accepted ? new Date(request.createdAt.getTime() + 2 * DAY_MS) : null,
    // B-04: seven days from the request, or from a withdrawn offer (B-03).
    expiresAt: quoteRequestAnswerDeadline(request.offer?.withdrawnAt ?? request.createdAt),
    expiryWarnedAt: null,
    expiredAt: request.expiredAt ?? null,
    conversationId,
  };
  await prisma.quoteRequest.upsert({
    where: { id: rid },
    create: { id: rid, createdAt: request.createdAt, ...requestData },
    update: requestData,
  });
  await upsertEvent(prisma, {
    conversationId,
    quoteRequestId: rid,
    actorUserId: customerId,
    type: ConversationEventType.QUOTE_REQUEST_CREATED,
    occurredAt: request.createdAt,
    dedupeKey: `demo:${request.key}:request-created`,
    data: { status: QuoteRequestStatus.SENT },
  });
  if (request.expiredAt) {
    await upsertEvent(prisma, {
      conversationId,
      quoteRequestId: rid,
      actorUserId: null,
      type: ConversationEventType.QUOTE_REQUEST_EXPIRED,
      occurredAt: request.expiredAt,
      dedupeKey: `demo:${request.key}:request-expired`,
      data: { status: QuoteRequestStatus.EXPIRED, answerDays: 7 },
    });
  }

  if (request.offer) {
    const oid = offerId(request.key);
    const offerCreated = new Date(request.createdAt.getTime() + DAY_MS);
    // B-06: the offer row is its current version; a revised offer keeps its
    // first version and «ايش تغيّر» between the two.
    const current = {
      title: request.offer.title,
      message: request.offer.message,
      amount: String(request.offer.amount),
      currency: 'YER',
      validUntil: request.offer.validUntil,
    };
    const firstSpec = request.offer.firstVersion;
    const first = firstSpec
      ? {
          ...current,
          title: firstSpec.title ?? current.title,
          message: firstSpec.message ?? current.message,
          amount: firstSpec.amount === undefined ? current.amount : String(firstSpec.amount),
        }
      : null;
    const changes = first ? toQuoteOfferChangesJson(quoteOfferChanges(first, current)) : null;
    const versionNo = first ? 2 : 1;
    const withdrawnAt = request.offer.withdrawnAt ?? null;
    const offerData = {
      quoteRequestId: rid,
      providerId: pid,
      ...current,
      status: request.offer.status,
      currentVersionNo: versionNo,
      versionChanges: changes ?? Prisma.DbNull,
      revisedAt: firstSpec?.revisedAt ?? null,
      withdrawnAt,
      withdrawnReason: null,
    };
    await prisma.quoteOffer.upsert({
      where: { id: oid },
      create: { id: oid, createdAt: offerCreated, ...offerData },
      update: offerData,
    });
    const versions = [
      ...(first ? [{ versionNo: 1, terms: first, changes: null, at: offerCreated }] : []),
      { versionNo, terms: current, changes, at: firstSpec?.revisedAt ?? offerCreated },
    ];
    for (const version of versions) {
      const versionData = {
        ...version.terms,
        changes: version.changes ?? Prisma.DbNull,
        createdAt: version.at,
      };
      await prisma.quoteOfferVersion.upsert({
        where: { quoteOfferId_versionNo: { quoteOfferId: oid, versionNo: version.versionNo } },
        create: { quoteOfferId: oid, versionNo: version.versionNo, ...versionData },
        update: versionData,
      });
    }
    await prisma.quoteOfferVersion.deleteMany({
      where: { quoteOfferId: oid, versionNo: { gt: versionNo } },
    });
    await upsertEvent(prisma, {
      conversationId,
      quoteRequestId: rid,
      quoteOfferId: oid,
      actorUserId: providerUserId,
      type: ConversationEventType.QUOTE_OFFER_RECEIVED,
      occurredAt: offerCreated,
      dedupeKey: `demo:${request.key}:offer-received`,
      data: { amount: request.offer.amount },
    });
    if (firstSpec && changes) {
      await upsertEvent(prisma, {
        conversationId,
        quoteRequestId: rid,
        quoteOfferId: oid,
        actorUserId: providerUserId,
        type: ConversationEventType.QUOTE_OFFER_REVISED,
        occurredAt: firstSpec.revisedAt,
        dedupeKey: `demo:${request.key}:offer-revised:2`,
        data: { versionNo: 2, changes },
      });
    }
    if (withdrawnAt) {
      await upsertEvent(prisma, {
        conversationId,
        quoteRequestId: rid,
        quoteOfferId: oid,
        actorUserId: providerUserId,
        type: ConversationEventType.QUOTE_OFFER_WITHDRAWN,
        occurredAt: withdrawnAt,
        dedupeKey: `demo:${request.key}:offer-withdrawn`,
        data: { status: QuoteOfferStatus.WITHDRAWN },
      });
    }
    if (request.offer.status === QuoteOfferStatus.ACCEPTED) {
      await upsertEvent(prisma, {
        conversationId,
        quoteRequestId: rid,
        quoteOfferId: oid,
        actorUserId: customerId,
        type: ConversationEventType.QUOTE_OFFER_ACCEPTED,
        occurredAt: new Date(request.createdAt.getTime() + 2 * DAY_MS),
        dedupeKey: `demo:${request.key}:offer-accepted`,
        data: { amount: request.offer.amount },
      });
      if (weddingPlanId) {
        await prisma.planProviderLink.upsert({
          where: { weddingPlanId_providerId: { weddingPlanId, providerId: pid } },
          create: {
            id: demoUuid(`link:${request.key}`),
            weddingPlanId,
            providerId: pid,
            quoteRequestId: rid,
            quoteOfferId: oid,
            status: PlanProviderLinkStatus.ACTIVE,
          },
          update: { quoteRequestId: rid, quoteOfferId: oid, status: PlanProviderLinkStatus.ACTIVE },
        });
      }
    }
    if (request.booking) {
      const bookingData = {
        quoteRequestId: rid,
        quoteOfferId: oid,
        providerId: pid,
        eventDate: request.booking.date,
        status: request.booking.status,
        requestedByUserId: customerId,
        note: request.booking.note ?? null,
        confirmedAt:
          request.booking.status === BookingStatus.CONFIRMED
            ? new Date(request.createdAt.getTime() + 3 * DAY_MS)
            : null,
      };
      const bid = demoUuid(`booking:${request.key}`);
      await prisma.booking.upsert({
        where: { id: bid },
        create: { id: bid, createdAt: new Date(request.createdAt.getTime() + 2 * DAY_MS), ...bookingData },
        update: bookingData,
      });
    }
  }

  for (const [index, message] of (request.messages ?? []).entries()) {
    const senderId = message.from === 'customer' ? customerId : providerUserId;
    if (!senderId) throw new Error(`Request ${request.key} has a provider message but the provider has no account`);
    const mid = demoId('msg', `${request.key}-${index + 1}`);
    const messageData = { conversationId, senderUserId: senderId, body: message.body };
    await prisma.chatMessage.upsert({
      where: { id: mid },
      create: { id: mid, createdAt: message.at, ...messageData },
      update: messageData,
    });
  }
}

async function upsertParticipant(
  prisma: PrismaClient,
  conversationId: string,
  participantId: string,
  lastReadAt: Date | null,
): Promise<void> {
  await prisma.conversationParticipant.upsert({
    where: { conversationId_userId: { conversationId, userId: participantId } },
    create: { conversationId, userId: participantId, lastReadAt },
    update: { lastReadAt, revokedAt: null },
  });
}

async function upsertEvent(
  prisma: PrismaClient,
  event: {
    conversationId: string;
    quoteRequestId: string;
    quoteOfferId?: string;
    actorUserId: string | null;
    type: ConversationEventType;
    occurredAt: Date;
    dedupeKey: string;
    data: Prisma.InputJsonObject;
  },
): Promise<void> {
  await prisma.conversationEvent.upsert({
    where: { dedupeKey: event.dedupeKey },
    create: event,
    update: { occurredAt: event.occurredAt, data: event.data },
  });
}

/** The past customer's 4-star review, and the rating cache the provider list reads. */
async function seedStudioReview(prisma: PrismaClient): Promise<void> {
  const reviewerId = userId(STUDIO_REVIEW.customer);
  const id = demoUuid('review:studio:khaled');
  const data = {
    userId: reviewerId,
    providerId: STUDIO_ID,
    rating: STUDIO_REVIEW.rating,
    comment: STUDIO_REVIEW.comment,
    status: ReviewStatus.PUBLISHED,
  };
  await prisma.providerReview.upsert({ where: { id }, create: { id, ...data }, update: data });
  const aggregate = await prisma.providerReview.aggregate({
    where: { providerId: STUDIO_ID, status: ReviewStatus.PUBLISHED },
    _avg: { rating: true },
    _count: { _all: true },
  });
  await prisma.provider.update({
    where: { id: STUDIO_ID },
    data: {
      ratingAverage: (aggregate._avg.rating ?? 0).toFixed(2),
      ratingCount: aggregate._count._all,
    },
  });
}

async function seedFavorites(prisma: PrismaClient): Promise<void> {
  const favorites: Array<[Parameters<typeof userId>[0], string]> = [
    ['groom', 'studio'],
    ['groom', 'lens'],
    ['bride', 'studio'],
  ];
  for (const [account, key] of favorites) {
    const provider = PROVIDERS.find((entry) => entry.key === key)!;
    const id = demoUuid(`favorite:${account}:${key}`);
    const data = { userId: userId(account), providerId: providerId(provider) };
    await prisma.favoriteProvider.upsert({
      where: { userId_providerId: data },
      create: { id, ...data },
      update: {},
    });
  }
}
