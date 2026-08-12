import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AppRole,
  City,
  ConversationEventType,
  Prisma,
  Provider,
  ProviderCategory,
  ProviderPackage,
  ProviderReview,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  QuoteOffer,
  QuoteOfferStatus,
  QuoteRequest,
  QuoteRequestStatus,
  User,
  UserRole,
  UserStatus,
  WeddingPlan,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { toReviewIdentity } from '../common/privacy/review-identity';
import { PhoneNormalizer } from '../common/phone/phone-normalizer';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import {
  optionalMoneyAmount,
  requiredMoneyAmount,
} from '../common/validation/money';
import { recordConversationEvent } from '../conversations/conversation-lifecycle';
import {
  assertQuoteRequestTransition,
  lockQuoteOfferTransitionRows,
  lockQuoteRequestTransitionRow,
  quoteLifecycleStatus,
} from '../marketplace/quote-lifecycle';
import { isQuoteOfferExpired } from '../marketplace/quote-offer-expiry';
import {
  providerRejectedRequestNotification,
  quoteOfferReceivedNotification,
} from '../marketplace/quote-notifications';
import { MediaStorageService } from '../media/media-storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../platform/database/prisma.service';
import { assertWeddingPlanWritable } from '../sharing/permission.service';
import {
  applicationNameFields,
  toApplicationUserContact,
} from '../users/application-user-identity';
import { weddingLocationResponse } from '../wedding-plans/wedding-location';
import { ApplyProviderDto } from './dto/apply-provider.dto';
import { CreateProviderPackageDto } from './dto/create-provider-package.dto';
import { CreateProviderServiceDto } from './dto/create-provider-service.dto';
import { CreateQuoteOfferDto } from './dto/create-quote-offer.dto';
import { UpdateProviderPackageDto } from './dto/update-provider-package.dto';
import { UpdateProviderProfileDto } from './dto/update-provider-profile.dto';
import { UpdateProviderQuoteStatusDto } from './dto/update-provider-quote-status.dto';
import { UpdateProviderServiceDto } from './dto/update-provider-service.dto';
import { UpdateQuoteOfferDto } from './dto/update-quote-offer.dto';
import {
  CreateServiceImageDto,
  UpdateServiceImageDto,
} from './dto/upsert-service-image.dto';
import {
  assertProviderOperational,
} from './provider-access-policy';
import {
  lockOwnedProviderAfterUsersInTransaction,
  lockOwnedProviderForMutationInTransaction,
  lockProviderMutationUsersInTransaction,
} from './provider-mutation-locks';

type ProviderProfile = Provider & {
  city: City;
  primaryCategory?: ProviderCategory | null;
};
type ProviderDashboardServiceRecord = ProviderService & {
  category: ProviderCategory;
  city: City | null;
  images: ProviderServiceImage[];
};
type ProviderPackageRecord = ProviderPackage & {
  service: ProviderService | null;
};
type ProviderQuoteRecord = QuoteRequest & {
  user: Pick<User, 'id' | 'name' | 'appName' | 'phone' | 'role'>;
  service?: (ProviderService & { category: ProviderCategory }) | null;
  weddingPlan?: Pick<
    WeddingPlan,
    'id' | 'title' | 'city' | 'weddingDate' | 'currency'
  > | null;
  offers?: QuoteOffer[];
};
type ProviderReviewRecord = ProviderReview & {
  user: Pick<User, 'id' | 'name' | 'appName' | 'role'>;
};

@Injectable()
export class ProviderDashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly mediaStorage: MediaStorageService,
  ) {}

  async apply(currentUser: AuthenticatedUser, dto: ApplyProviderDto) {
    const categoryIds = [...new Set(dto.categoryIds ?? [])];
    const primaryCategoryId = categoryIds[0] ?? null;
    const businessName = this.requiredText(dto.businessName, 'businessName');
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const description = this.optionalText(dto.description);

    const provider = await runSerializableTransaction(this.prisma, async (tx) => {
      const users = await tx.$queryRaw<
        Array<{
          id: string;
          role: UserRole;
          status: UserStatus;
          appPasswordHash: string | null;
        }>
      >(
        Prisma.sql`
          SELECT "id", "role", "status", "appPasswordHash"
          FROM "User"
          WHERE "id" = ${currentUser.id}
          FOR UPDATE
        `,
      );
      const actor = users[0];
      if (!actor || actor.status !== UserStatus.ACTIVE) {
        throw new NotFoundException('User not found');
      }

      const existingProviders = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "Provider"
          WHERE "userId" = ${currentUser.id}
          FOR UPDATE
        `,
      );
      if (existingProviders.length > 0) {
        throw new ConflictException(
          'Provider profile already exists for this user',
        );
      }

      await this.lockActiveCategoriesInTransaction(tx, categoryIds);
      await this.lockActiveCityInTransaction(tx, dto.cityId);

      let applicationIdentity = await tx.user.updateMany({
        where: {
          id: currentUser.id,
          status: UserStatus.ACTIVE,
          role: { in: [UserRole.USER, UserRole.PROVIDER] },
        },
        data: {
          role: UserRole.PROVIDER,
          appRole: AppRole.PROVIDER,
        },
      });
      if (applicationIdentity.count === 0) {
        applicationIdentity = await tx.user.updateMany({
          where: {
            id: currentUser.id,
            status: UserStatus.ACTIVE,
            role: UserRole.ADMIN,
            appPasswordHash: { not: null },
          },
          data: { appRole: AppRole.PROVIDER },
        });
      }
      if (applicationIdentity.count !== 1) {
        throw new ConflictException(
          'The application identity is not eligible for a provider account',
        );
      }

      const created = await tx.provider.create({
        data: {
          userId: currentUser.id,
          cityId: dto.cityId,
          primaryCategoryId,
          businessName,
          phone,
          description,
          status: ProviderStatus.PENDING,
        },
        include: { city: true, primaryCategory: true },
      });

      return created;
    });

    return this.toProviderProfileResponse(provider);
  }

  async getProfile(currentUser: AuthenticatedUser) {
    const provider = await this.findOwnedProviderProfileOrThrow(currentUser.id);
    return this.toProviderProfileResponse(provider);
  }

  async updateProfile(
    currentUser: AuthenticatedUser,
    dto: UpdateProviderProfileDto,
  ) {
    const logoUrl =
      dto.logoUrl !== undefined
        ? await this.mediaStorage.verifyPublicMediaUrl(
            currentUser,
            dto.logoUrl,
            'provider-logo',
          )
        : undefined;
    const coverUrl =
      dto.coverUrl !== undefined
        ? await this.mediaStorage.verifyPublicMediaUrl(
            currentUser,
            dto.coverUrl,
            'provider-cover',
          )
        : undefined;

    const updated = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'PROFILE',
        'UPDATE',
      );
      if (dto.cityId !== undefined) {
        await this.lockActiveCityInTransaction(tx, dto.cityId);
      }

      const logoChanged =
        dto.logoUrl !== undefined && logoUrl !== provider.logoUrl;
      const coverChanged =
        dto.coverUrl !== undefined && coverUrl !== provider.coverUrl;
      if (logoChanged) {
        await this.mediaStorage.scheduleTargetDeletion(
          { type: 'PROVIDER_LOGO', id: provider.id },
          tx,
        );
        if (logoUrl) {
          await this.mediaStorage.consumePublicMediaUrl(
            currentUser,
            logoUrl,
            'provider-logo',
            { type: 'PROVIDER_LOGO', id: provider.id },
            tx,
          );
        }
      }
      if (coverChanged) {
        await this.mediaStorage.scheduleTargetDeletion(
          { type: 'PROVIDER_COVER', id: provider.id },
          tx,
        );
        if (coverUrl) {
          await this.mediaStorage.consumePublicMediaUrl(
            currentUser,
            coverUrl,
            'provider-cover',
            { type: 'PROVIDER_COVER', id: provider.id },
            tx,
          );
        }
      }
      return tx.provider.update({
        where: { id: provider.id },
        data: {
        ...(dto.businessName !== undefined
          ? { businessName: this.requiredText(dto.businessName, 'businessName') }
          : {}),
        ...(dto.ownerName !== undefined
          ? { ownerName: this.optionalText(dto.ownerName) }
          : {}),
        ...(dto.phone !== undefined
          ? { phone: PhoneNormalizer.normalizeRequired(dto.phone) }
          : {}),
        ...(dto.whatsapp !== undefined
          ? {
              whatsapp: PhoneNormalizer.normalizeOptional(
                dto.whatsapp,
                'whatsapp',
              ),
            }
          : {}),
        ...(dto.email !== undefined ? { email: this.optionalText(dto.email) } : {}),
        ...(dto.description !== undefined
          ? { description: this.optionalText(dto.description) }
          : {}),
        ...(dto.address !== undefined
          ? { address: this.optionalText(dto.address) }
          : {}),
        ...(dto.cityId !== undefined ? { cityId: dto.cityId } : {}),
        ...(dto.latitude !== undefined
          ? { latitude: this.optionalSignedDecimal(dto.latitude, 'latitude') }
          : {}),
        ...(dto.longitude !== undefined
          ? { longitude: this.optionalSignedDecimal(dto.longitude, 'longitude') }
          : {}),
        ...(dto.logoUrl !== undefined ? { logoUrl } : {}),
        ...(dto.coverUrl !== undefined ? { coverUrl } : {}),
        },
        include: { city: true, primaryCategory: true },
      });
    });

    return this.toProviderProfileResponse(updated);
  }

  async getSummary(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const [
      servicesCount,
      activeServicesCount,
      quoteRequestsCount,
      newQuoteRequestsCount,
    ] = await Promise.all([
      this.prisma.providerService.count({ where: { providerId: provider.id } }),
      this.prisma.providerService.count({
        where: { providerId: provider.id, isActive: true },
      }),
      this.prisma.quoteRequest.count({ where: { providerId: provider.id } }),
      this.prisma.quoteRequest.count({
        where: { providerId: provider.id, status: QuoteRequestStatus.SENT },
      }),
    ]);

    return {
      servicesCount,
      activeServicesCount,
      quoteRequestsCount,
      newQuoteRequestsCount,
      averageRating: provider.ratingAverage.toString(),
      ratingCount: provider.ratingCount,
    };
  }

  async findServices(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const services = await this.prisma.providerService.findMany({
      where: { providerId: provider.id },
      include: this.serviceInclude(),
      orderBy: { createdAt: 'desc' },
    });

    return services.map((service) => this.toServiceResponse(service));
  }

  async createService(
    currentUser: AuthenticatedUser,
    dto: CreateProviderServiceDto,
  ) {
    const basePrice = optionalMoneyAmount(dto.basePrice, 'basePrice');
    const service = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockActiveCategoryInTransaction(tx, dto.categoryId);
      if (dto.cityId) {
        await this.lockActiveCityInTransaction(tx, dto.cityId);
      }

      return tx.providerService.create({
        data: {
          providerId: provider.id,
          categoryId: dto.categoryId,
          title: this.requiredText(dto.title, 'title'),
          description: this.optionalText(dto.description),
          basePrice,
          priceUnit: this.optionalText(dto.priceUnit),
          currency: this.optionalText(dto.currency) ?? 'YER',
          cityId: this.optionalText(dto.cityId),
        },
        include: this.serviceInclude(),
      });
    });

    return this.toServiceResponse(service);
  }

  async findService(currentUser: AuthenticatedUser, id: string) {
    const service = await this.findOwnedServiceOrThrow(currentUser.id, id);
    return this.toServiceResponse(service);
  }

  async updateService(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateProviderServiceDto,
  ) {
    this.assertUuid(id, 'serviceId');
    const basePrice =
      dto.basePrice !== undefined
        ? optionalMoneyAmount(dto.basePrice, 'basePrice')
        : undefined;
    const service = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      if (dto.categoryId !== undefined) {
        await this.lockActiveCategoryInTransaction(tx, dto.categoryId);
      }
      if (dto.cityId) {
        await this.lockActiveCityInTransaction(tx, dto.cityId);
      }
      await this.lockOwnedServiceInTransaction(tx, provider.id, id, 'UPDATE');

      return tx.providerService.update({
        where: { id },
        data: {
          ...(dto.categoryId !== undefined ? { categoryId: dto.categoryId } : {}),
          ...(dto.title !== undefined
            ? { title: this.requiredText(dto.title, 'title') }
            : {}),
          ...(dto.description !== undefined
            ? { description: this.optionalText(dto.description) }
            : {}),
          ...(dto.basePrice !== undefined
            ? { basePrice }
            : {}),
          ...(dto.priceUnit !== undefined
            ? { priceUnit: this.optionalText(dto.priceUnit) }
            : {}),
          ...(dto.currency !== undefined
            ? { currency: this.requiredText(dto.currency, 'currency') }
            : {}),
          ...(dto.cityId !== undefined
            ? { cityId: this.optionalText(dto.cityId) }
            : {}),
          ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        },
        include: this.serviceInclude(),
      });
    });

    return this.toServiceResponse(service);
  }

  async deactivateService(currentUser: AuthenticatedUser, id: string) {
    this.assertUuid(id, 'serviceId');
    const service = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockOwnedServiceInTransaction(tx, provider.id, id, 'UPDATE');
      return tx.providerService.update({
        where: { id },
        data: { isActive: false },
        include: this.serviceInclude(),
      });
    });

    return this.toServiceResponse(service);
  }

  async createServiceImage(
    currentUser: AuthenticatedUser,
    serviceId: string,
    dto: CreateServiceImageDto,
  ) {
    this.assertUuid(serviceId, 'serviceId');
    const imageUrl = await this.mediaStorage.verifyPublicMediaUrl(
      currentUser,
      dto.imageUrl,
      'service-image',
    );
    if (!imageUrl) throw new BadRequestException('imageUrl is required');
    const image = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockOwnedServiceInTransaction(
        tx,
        provider.id,
        serviceId,
        'SHARE',
      );
      const created = await tx.providerServiceImage.create({
        data: {
          serviceId,
          imageUrl,
          altText: this.optionalText(dto.altText),
          sortOrder: dto.sortOrder ?? 0,
        },
      });
      await this.mediaStorage.consumePublicMediaUrl(
        currentUser,
        imageUrl,
        'service-image',
        { type: 'SERVICE_IMAGE', id: created.id },
        tx,
      );
      return created;
    });

    return this.toImageResponse(image);
  }

  async updateServiceImage(
    currentUser: AuthenticatedUser,
    serviceId: string,
    imageId: string,
    dto: UpdateServiceImageDto,
  ) {
    this.assertUuid(serviceId, 'serviceId');
    this.assertUuid(imageId, 'imageId');
    const imageUrl =
      dto.imageUrl !== undefined
        ? await this.mediaStorage.verifyPublicMediaUrl(
            currentUser,
            dto.imageUrl,
            'service-image',
          )
        : undefined;
    if (dto.imageUrl !== undefined && !imageUrl) {
      throw new BadRequestException('imageUrl is required');
    }

    const image = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockOwnedServiceInTransaction(
        tx,
        provider.id,
        serviceId,
        'SHARE',
      );
      const existing = await this.lockOwnedServiceImageInTransaction(
        tx,
        serviceId,
        imageId,
      );
      const imageChanged =
        dto.imageUrl !== undefined && imageUrl !== existing.imageUrl;
      if (imageChanged) {
        await this.mediaStorage.scheduleTargetDeletion(
          { type: 'SERVICE_IMAGE', id: imageId },
          tx,
        );
        await this.mediaStorage.consumePublicMediaUrl(
          currentUser,
          imageUrl!,
          'service-image',
          { type: 'SERVICE_IMAGE', id: imageId },
          tx,
        );
      }
      return tx.providerServiceImage.update({
        where: { id: imageId },
        data: {
          ...(dto.imageUrl !== undefined ? { imageUrl: imageUrl! } : {}),
          ...(dto.altText !== undefined
            ? { altText: this.optionalText(dto.altText) }
            : {}),
          ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
        },
      });
    });

    return this.toImageResponse(image);
  }

  async deleteServiceImage(
    currentUser: AuthenticatedUser,
    serviceId: string,
    imageId: string,
  ) {
    this.assertUuid(serviceId, 'serviceId');
    this.assertUuid(imageId, 'imageId');
    await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockOwnedServiceInTransaction(
        tx,
        provider.id,
        serviceId,
        'SHARE',
      );
      await this.lockOwnedServiceImageInTransaction(tx, serviceId, imageId);
      await this.mediaStorage.scheduleTargetDeletion(
        { type: 'SERVICE_IMAGE', id: imageId },
        tx,
      );
      await tx.providerServiceImage.delete({ where: { id: imageId } });
    });

    return { id: imageId, deleted: true };
  }

  async findPackages(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const packages = await this.prisma.providerPackage.findMany({
      where: { providerId: provider.id },
      include: { service: true },
      orderBy: { createdAt: 'desc' },
    });

    return packages.map((providerPackage) =>
      this.toPackageResponse(providerPackage),
    );
  }

  async createPackage(
    currentUser: AuthenticatedUser,
    dto: CreateProviderPackageDto,
  ) {
    if (dto.serviceId) this.assertUuid(dto.serviceId, 'serviceId');
    const price = optionalMoneyAmount(dto.price, 'price');
    const providerPackage = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const provider = await lockOwnedProviderForMutationInTransaction(
          tx,
          currentUser.id,
          'OPERATIONAL',
        );
        if (dto.serviceId) {
          await this.lockOwnedServiceInTransaction(
            tx,
            provider.id,
            dto.serviceId,
            'SHARE',
          );
        }

        return tx.providerPackage.create({
          data: {
            providerId: provider.id,
            serviceId: this.optionalText(dto.serviceId),
            title: this.requiredText(dto.title, 'title'),
            description: this.optionalText(dto.description),
            price,
            currency: this.optionalText(dto.currency) ?? 'YER',
            ...(dto.items !== undefined
              ? { items: dto.items as Prisma.InputJsonValue }
              : {}),
          },
          include: { service: true },
        });
      },
    );

    return this.toPackageResponse(providerPackage);
  }

  async updatePackage(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateProviderPackageDto,
  ) {
    this.assertUuid(id, 'packageId');
    if (dto.serviceId) this.assertUuid(dto.serviceId, 'serviceId');
    const price =
      dto.price !== undefined
        ? optionalMoneyAmount(dto.price, 'price')
        : undefined;
    const providerPackage = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const provider = await lockOwnedProviderForMutationInTransaction(
          tx,
          currentUser.id,
          'OPERATIONAL',
        );
        if (dto.serviceId) {
          await this.lockOwnedServiceInTransaction(
            tx,
            provider.id,
            dto.serviceId,
            'SHARE',
          );
        }
        await this.lockOwnedPackageInTransaction(tx, provider.id, id);

        return tx.providerPackage.update({
          where: { id },
          data: {
            ...(dto.serviceId !== undefined
              ? { serviceId: this.optionalText(dto.serviceId) }
              : {}),
            ...(dto.title !== undefined
              ? { title: this.requiredText(dto.title, 'title') }
              : {}),
            ...(dto.description !== undefined
              ? { description: this.optionalText(dto.description) }
              : {}),
          ...(dto.price !== undefined
              ? { price }
              : {}),
            ...(dto.currency !== undefined
              ? { currency: this.requiredText(dto.currency, 'currency') }
              : {}),
            ...(dto.items !== undefined
              ? { items: dto.items as Prisma.InputJsonValue }
              : {}),
            ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
          },
          include: { service: true },
        });
      },
    );

    return this.toPackageResponse(providerPackage);
  }

  async deactivatePackage(currentUser: AuthenticatedUser, id: string) {
    this.assertUuid(id, 'packageId');
    const providerPackage = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const provider = await lockOwnedProviderForMutationInTransaction(
          tx,
          currentUser.id,
          'OPERATIONAL',
        );
        await this.lockOwnedPackageInTransaction(tx, provider.id, id);
        return tx.providerPackage.update({
          where: { id },
          data: { isActive: false },
          include: { service: true },
        });
      },
    );

    return this.toPackageResponse(providerPackage);
  }

  async findQuoteRequests(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const quotes = await this.prisma.quoteRequest.findMany({
      where: { providerId: provider.id },
      include: this.quoteInclude(),
      orderBy: { createdAt: 'desc' },
    });

    return quotes.map((quote) => this.toQuoteResponse(quote));
  }

  async findQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    this.assertUuid(id, 'quoteRequestId');
    const quote = await this.prisma.quoteRequest.findFirst({
      where: { id, providerId: provider.id },
      include: this.quoteInclude(),
    });

    if (!quote) {
      throw new NotFoundException('Quote request not found');
    }

    return this.toQuoteResponse(quote);
  }

  async updateQuoteRequestStatus(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateProviderQuoteStatusDto,
  ) {
    this.assertUuid(id, 'quoteRequestId');
    const quote = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await tx.quoteRequest.findUnique({
        where: { id },
        select: {
          providerId: true,
          userId: true,
          weddingPlanId: true,
          conversationId: true,
        },
      });
      if (!seed) {
        throw new NotFoundException('Quote request not found');
      }
      const provider = await this.lockQuoteMutationContext(
        tx,
        currentUser.id,
        seed,
      );
      if (!(await lockQuoteRequestTransitionRow(tx, id))) {
        throw new NotFoundException('Quote request not found');
      }
      const existing = await tx.quoteRequest.findFirst({
        where: { id, providerId: provider.id },
        include: {
          weddingPlan: { select: { status: true } },
        },
      });
      if (!existing) {
        throw new NotFoundException('Quote request not found');
      }
      if (existing.weddingPlan) {
        assertWeddingPlanWritable(existing.weddingPlan);
      }
      assertQuoteRequestTransition(existing.status, dto.status, 'provider');

      const transition = await tx.quoteRequest.updateMany({
        where: { id, status: existing.status },
        data: {
          status: dto.status,
          ...(dto.status === QuoteRequestStatus.REJECTED
            ? { rejectedAt: new Date() }
            : {}),
        },
      });
      if (transition.count !== 1) {
        throw new ConflictException('Quote request status changed');
      }
      const updated = await tx.quoteRequest.findUniqueOrThrow({
        where: { id },
        include: this.quoteInclude(),
      });
      if (dto.status === QuoteRequestStatus.REJECTED) {
        await recordConversationEvent(tx, {
          conversationId: existing.conversationId,
          quoteRequestId: existing.id,
          actorUserId: currentUser.id,
          type: ConversationEventType.QUOTE_REQUEST_REJECTED,
          dedupeKey: `quote-request:${existing.id}:rejected`,
          data: { status: QuoteRequestStatus.REJECTED },
        });
        const recipientId =
          await this.notifications.resolveProviderUpdateRecipientInTransaction(
            tx,
            existing.weddingPlanId,
            existing.userId,
          );
        await this.notifications.createNotificationInTransaction(
          tx,
          providerRejectedRequestNotification({
            requesterId: recipientId,
            weddingPlanId: existing.weddingPlanId,
            quoteRequestId: existing.id,
            providerId: provider.id,
            providerName: provider.businessName,
          }),
        );
      }
      return updated;
    });

    return this.toQuoteResponse(quote);
  }

  async createQuoteOffer(
    currentUser: AuthenticatedUser,
    quoteRequestId: string,
    dto: CreateQuoteOfferDto,
  ) {
    this.assertUuid(quoteRequestId, 'quoteRequestId');
    const amount = this.requiredPositiveMoneyAmount(dto.amount, 'amount');
    const offer = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await tx.quoteRequest.findUnique({
        where: { id: quoteRequestId },
        select: {
          providerId: true,
          userId: true,
          weddingPlanId: true,
          conversationId: true,
        },
      });
      if (!seed) {
        throw new NotFoundException('Quote request not found');
      }
      const provider = await this.lockQuoteMutationContext(
        tx,
        currentUser.id,
        seed,
      );
      if (!(await lockQuoteRequestTransitionRow(tx, quoteRequestId))) {
        throw new NotFoundException('Quote request not found');
      }
      const quote = await tx.quoteRequest.findFirst({
        where: { id: quoteRequestId, providerId: provider.id },
        include: {
          weddingPlan: { select: { status: true, currency: true } },
        },
      });
      if (!quote) {
        throw new NotFoundException('Quote request not found');
      }
      if (quote.weddingPlan) {
        assertWeddingPlanWritable(quote.weddingPlan);
      }
      assertQuoteRequestTransition(
        quote.status,
        QuoteRequestStatus.RESPONDED,
        'provider_offer',
      );
      const existingOffer = await tx.quoteOffer.findFirst({
        where: { quoteRequestId },
        select: { id: true },
      });
      if (existingOffer) {
        throw new ConflictException({
          code: 'QUOTE_OFFER_ALREADY_EXISTS',
          message: 'يوجد عرض سعر لهذا الطلب بالفعل.',
          quoteOfferId: existingOffer.id,
        });
      }
      const currency = this.quoteOfferCurrency(
        dto.currency,
        quote.weddingPlan?.currency,
      );

      const created = await tx.quoteOffer.create({
        data: {
          quoteRequestId,
          providerId: provider.id,
          title: this.optionalText(dto.title),
          message: this.requiredText(dto.message, 'message'),
          amount,
          currency,
          validUntil: this.optionalDate(dto.validUntil, 'validUntil'),
        },
      });

      await tx.quoteRequest.update({
        where: { id: quoteRequestId },
        data: { status: QuoteRequestStatus.RESPONDED },
      });

      await recordConversationEvent(tx, {
        conversationId: quote.conversationId,
        quoteRequestId,
        quoteOfferId: created.id,
        actorUserId: currentUser.id,
        type: ConversationEventType.QUOTE_OFFER_RECEIVED,
        occurredAt: created.createdAt,
        dedupeKey: `quote-offer:${created.id}:received`,
        data: { status: QuoteOfferStatus.PENDING },
      });

      const recipientId =
        await this.notifications.resolveProviderUpdateRecipientInTransaction(
          tx,
          quote.weddingPlanId,
          quote.userId,
        );
      await this.notifications.createNotificationInTransaction(
        tx,
        quoteOfferReceivedNotification({
          requesterId: recipientId,
          weddingPlanId: quote.weddingPlanId,
          quoteRequestId,
          quoteOfferId: created.id,
          providerId: provider.id,
          providerName: provider.businessName,
        }),
      );

      return created;
    });

    return this.toQuoteOfferResponse(offer);
  }

  async updateQuoteOffer(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateQuoteOfferDto,
  ) {
    this.assertUuid(id, 'quoteOfferId');
    const requestedAmount =
      dto.amount !== undefined
        ? this.requiredPositiveMoneyAmount(dto.amount, 'amount')
        : undefined;
    const offer = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await tx.quoteOffer.findUnique({
        where: { id },
        select: {
          providerId: true,
          quoteRequest: {
            select: {
              userId: true,
              weddingPlanId: true,
              conversationId: true,
            },
          },
        },
      });
      if (!seed) {
        throw new NotFoundException('Quote offer not found');
      }
      const provider = await this.lockQuoteMutationContext(
        tx,
        currentUser.id,
        {
          providerId: seed.providerId,
          userId: seed.quoteRequest.userId,
          weddingPlanId: seed.quoteRequest.weddingPlanId,
          conversationId: seed.quoteRequest.conversationId,
        },
      );
      if (!(await lockQuoteOfferTransitionRows(tx, id))) {
        throw new NotFoundException('Quote offer not found');
      }
      const existing = await tx.quoteOffer.findFirst({
        where: { id, providerId: provider.id },
        include: {
          quoteRequest: {
            select: {
              status: true,
              weddingPlan: { select: { status: true, currency: true } },
            },
          },
        },
      });
      if (!existing) {
        throw new NotFoundException('Quote offer not found');
      }
      if (existing.quoteRequest.weddingPlan) {
        assertWeddingPlanWritable(existing.quoteRequest.weddingPlan);
      }
      if (
        existing.status !== QuoteOfferStatus.PENDING ||
        existing.quoteRequest.status !== QuoteRequestStatus.RESPONDED
      ) {
        throw new ConflictException('Only pending quote offers can be updated');
      }
      const amount =
        requestedAmount ??
        this.requiredPositiveMoneyAmount(
          existing.amount?.toString(),
          'amount',
        );
      const currency = this.quoteOfferCurrency(
        dto.currency ?? existing.currency,
        existing.quoteRequest.weddingPlan?.currency,
      );

      const transition = await tx.quoteOffer.updateMany({
        where: { id, status: QuoteOfferStatus.PENDING },
        data: {
          ...(dto.title !== undefined
            ? { title: this.optionalText(dto.title) }
            : {}),
          ...(dto.message !== undefined
            ? { message: this.requiredText(dto.message ?? '', 'message') }
            : {}),
          ...(dto.amount !== undefined
            ? { amount }
            : {}),
          ...(dto.currency !== undefined ? { currency } : {}),
          ...(dto.validUntil !== undefined
            ? { validUntil: this.optionalDate(dto.validUntil, 'validUntil') }
            : {}),
        },
      });
      if (transition.count !== 1) {
        throw new ConflictException('Only pending quote offers can be updated');
      }
      return tx.quoteOffer.findUniqueOrThrow({ where: { id } });
    });

    return this.toQuoteOfferResponse(offer);
  }

  async findReviews(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const reviews = await this.prisma.providerReview.findMany({
      where: { providerId: provider.id },
      include: {
        user: { select: { id: true, ...applicationNameFields } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return reviews.map((review) => this.toReviewResponse(review));
  }

  private async lockQuoteMutationContext(
    tx: Prisma.TransactionClient,
    actorUserId: string,
    seed: {
      providerId: string;
      userId: string;
      weddingPlanId: string | null;
      conversationId: string;
    },
  ): Promise<Provider> {
    const preliminaryProvider = await tx.provider.findUnique({
      where: { userId: actorUserId },
      select: { id: true },
    });
    if (!preliminaryProvider || preliminaryProvider.id !== seed.providerId) {
      throw new NotFoundException('Quote request not found');
    }

    await lockProviderMutationUsersInTransaction(
      tx,
      [actorUserId, seed.userId],
      actorUserId,
    );

    if (seed.weddingPlanId) {
      const plans = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "WeddingPlan"
          WHERE "id" = ${seed.weddingPlanId}
          FOR SHARE
        `,
      );
      if (plans.length !== 1) {
        throw new NotFoundException('Quote request not found');
      }
      const plan = await tx.weddingPlan.findUnique({
        where: { id: seed.weddingPlanId },
        select: { status: true },
      });
      if (!plan) {
        throw new NotFoundException('Quote request not found');
      }
      assertWeddingPlanWritable(plan);
    }

    const provider = await lockOwnedProviderAfterUsersInTransaction(
      tx,
      actorUserId,
      'OPERATIONAL',
      'SHARE',
      seed.providerId,
    );

    const conversations = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "Conversation"
        WHERE "id" = ${seed.conversationId}
        FOR SHARE
      `,
    );
    if (conversations.length !== 1) {
      throw new NotFoundException('Quote request not found');
    }
    return provider;
  }

  private async lockActiveCategoriesInTransaction(
    tx: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<void> {
    const uniqueIds = [...new Set(categoryIds)].sort();
    for (const categoryId of uniqueIds) {
      this.assertUuid(categoryId, 'categoryId');
    }
    if (uniqueIds.length === 0) return;

    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderCategory"
        WHERE "id" IN (${Prisma.join(uniqueIds)})
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
    if (rows.length !== uniqueIds.length) {
      throw new BadRequestException(
        'categoryIds must reference active categories',
      );
    }
    const activeCount = await tx.providerCategory.count({
      where: { id: { in: uniqueIds }, isActive: true },
    });
    if (activeCount !== uniqueIds.length) {
      throw new BadRequestException(
        'categoryIds must reference active categories',
      );
    }
  }

  private async lockActiveCategoryInTransaction(
    tx: Prisma.TransactionClient,
    categoryId: string,
  ): Promise<void> {
    try {
      await this.lockActiveCategoriesInTransaction(tx, [categoryId]);
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw new BadRequestException(
          'categoryId must reference an active category',
        );
      }
      throw error;
    }
  }

  private async lockActiveCityInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<void> {
    this.assertUuid(cityId, 'cityId');
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "City"
        WHERE "id" = ${cityId}
        FOR SHARE
      `,
    );
    if (rows.length !== 1) {
      throw new BadRequestException('cityId must reference an active city');
    }
    const city = await tx.city.findFirst({
      where: { id: cityId, isActive: true },
      select: { id: true },
    });
    if (!city) {
      throw new BadRequestException('cityId must reference an active city');
    }
  }

  private async lockOwnedServiceInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    serviceId: string,
    mode: 'SHARE' | 'UPDATE',
  ): Promise<ProviderDashboardServiceRecord> {
    const rows =
      mode === 'UPDATE'
        ? await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              SELECT "id"
              FROM "ProviderService"
              WHERE "id" = ${serviceId} AND "providerId" = ${providerId}
              FOR UPDATE
            `,
          )
        : await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              SELECT "id"
              FROM "ProviderService"
              WHERE "id" = ${serviceId} AND "providerId" = ${providerId}
              FOR SHARE
            `,
          );
    if (rows.length !== 1) {
      throw new NotFoundException('Provider service not found');
    }
    const service = await tx.providerService.findUnique({
      where: { id: serviceId },
      include: this.serviceInclude(),
    });
    if (!service || service.providerId !== providerId) {
      throw new NotFoundException('Provider service not found');
    }
    return service;
  }

  private async lockOwnedServiceImageInTransaction(
    tx: Prisma.TransactionClient,
    serviceId: string,
    imageId: string,
  ): Promise<ProviderServiceImage> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderServiceImage"
        WHERE "id" = ${imageId} AND "serviceId" = ${serviceId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) {
      throw new NotFoundException('Service image not found');
    }
    const image = await tx.providerServiceImage.findUnique({
      where: { id: imageId },
    });
    if (!image || image.serviceId !== serviceId) {
      throw new NotFoundException('Service image not found');
    }
    return image;
  }

  private async lockOwnedPackageInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    packageId: string,
  ): Promise<void> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderPackage"
        WHERE "id" = ${packageId} AND "providerId" = ${providerId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) {
      throw new NotFoundException('Provider package not found');
    }
  }

  private async findOwnedProviderOrThrow(userId: string): Promise<Provider> {
    const provider = await this.prisma.provider.findUnique({ where: { userId } });
    if (!provider) {
      throw new NotFoundException('Provider profile not found');
    }
    return provider;
  }

  private async findActiveOwnedProviderOrThrow(
    userId: string,
  ): Promise<Provider> {
    const provider = await this.findOwnedProviderOrThrow(userId);
    assertProviderOperational(provider);
    return provider;
  }

  private async findOwnedProviderProfileOrThrow(
    userId: string,
  ): Promise<ProviderProfile> {
    const provider = await this.prisma.provider.findUnique({
      where: { userId },
      include: { city: true, primaryCategory: true },
    });
    if (!provider) {
      throw new NotFoundException('Provider profile not found');
    }
    return provider;
  }

  private async findOwnedServiceOrThrow(
    userId: string,
    serviceId: string,
  ): Promise<ProviderDashboardServiceRecord> {
    this.assertUuid(serviceId, 'serviceId');
    const provider = await this.findActiveOwnedProviderOrThrow(userId);
    const service = await this.prisma.providerService.findFirst({
      where: { id: serviceId, providerId: provider.id },
      include: this.serviceInclude(),
    });

    if (!service) {
      throw new NotFoundException('Provider service not found');
    }

    return service;
  }

  private async findOwnedPackageOrThrow(
    userId: string,
    packageId: string,
  ): Promise<ProviderPackage> {
    this.assertUuid(packageId, 'packageId');
    const provider = await this.findActiveOwnedProviderOrThrow(userId);
    const providerPackage = await this.prisma.providerPackage.findFirst({
      where: { id: packageId, providerId: provider.id },
    });
    if (!providerPackage) {
      throw new NotFoundException('Provider package not found');
    }
    return providerPackage;
  }

  private async findActiveCityOrThrow(cityId: string): Promise<City> {
    this.assertUuid(cityId, 'cityId');
    const city = await this.prisma.city.findFirst({
      where: { id: cityId, isActive: true },
    });
    if (!city) {
      throw new BadRequestException('cityId must reference an active city');
    }
    return city;
  }

  private async findActiveCategoryOrThrow(
    categoryId: string,
  ): Promise<ProviderCategory> {
    this.assertUuid(categoryId, 'categoryId');
    const category = await this.prisma.providerCategory.findFirst({
      where: { id: categoryId, isActive: true },
    });
    if (!category) {
      throw new BadRequestException('categoryId must reference an active category');
    }
    return category;
  }

  private async assertActiveCategories(categoryIds: string[]): Promise<void> {
    const uniqueIds = [...new Set(categoryIds)];
    for (const categoryId of uniqueIds) {
      this.assertUuid(categoryId, 'categoryId');
    }
    if (uniqueIds.length === 0) return;

    const count = await this.prisma.providerCategory.count({
      where: { id: { in: uniqueIds }, isActive: true },
    });
    if (count !== uniqueIds.length) {
      throw new BadRequestException('categoryIds must reference active categories');
    }
  }

  private serviceInclude() {
    return {
      category: true,
      city: true,
      images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
    } satisfies Prisma.ProviderServiceInclude;
  }

  private quoteInclude() {
    return {
      user: {
        select: { id: true, phone: true, ...applicationNameFields },
      },
      service: { include: { category: true } },
      weddingPlan: {
        select: {
          id: true,
          title: true,
          city: true,
          weddingDate: true,
          currency: true,
        },
      },
      offers: { orderBy: { createdAt: 'desc' } },
    } satisfies Prisma.QuoteRequestInclude;
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private requiredPositiveMoneyAmount(value: unknown, field: string): string {
    const amount = requiredMoneyAmount(value, field);
    if (Number(amount) <= 0) {
      throw new BadRequestException(`${field} must be greater than zero`);
    }
    return amount;
  }

  private quoteOfferCurrency(
    requested: string | null | undefined,
    weddingPlanCurrency?: string | null,
  ): string {
    const currency = (requested?.trim() || weddingPlanCurrency || 'YER')
      .toUpperCase();
    if (!/^[A-Z]{3}$/.test(currency)) {
      throw new BadRequestException(
        'currency must be a three-letter ISO code',
      );
    }
    if (
      weddingPlanCurrency &&
      currency !== weddingPlanCurrency.toUpperCase()
    ) {
      throw new BadRequestException(
        'Quote offer currency must match the wedding plan currency',
      );
    }
    return currency;
  }

  private optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private optionalSignedDecimal(
    value: string | null | undefined,
    field: string,
  ): string | null {
    if (value === undefined || value === null) return null;
    const normalized = value.trim();
    if (!normalized) return null;
    if (!/^-?\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException(`${field} must be a valid decimal value`);
    }
    return normalized;
  }

  private optionalDate(value: string | null | undefined, field: string): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    const date = new Date(trimmed);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`${field} must be a valid date`);
    }
    return date;
  }

  private assertUuid(value: string, field: string): void {
    const uuidPattern =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidPattern.test(value)) {
      throw new BadRequestException(`${field} must be a valid UUID`);
    }
  }

  private toProviderProfileResponse(provider: ProviderProfile) {
    return {
      id: provider.id,
      userId: provider.userId,
      cityId: provider.cityId,
      city: this.toCityResponse(provider.city),
      primaryCategoryId: provider.primaryCategoryId,
      primaryCategory: provider.primaryCategory
        ? this.toCategoryResponse(provider.primaryCategory)
        : null,
      businessName: provider.businessName,
      ownerName: provider.ownerName,
      phone: provider.phone,
      whatsapp: provider.whatsapp,
      email: provider.email,
      description: provider.description,
      address: provider.address,
      latitude: provider.latitude?.toString() ?? null,
      longitude: provider.longitude?.toString() ?? null,
      logoUrl: provider.logoUrl,
      coverUrl: provider.coverUrl,
      status: provider.status,
      reviewNote: provider.reviewNote,
      reviewedAt: provider.reviewedAt,
      reviewedById: provider.reviewedById,
      isFeatured: provider.isFeatured,
      ratingAverage: provider.ratingAverage.toString(),
      ratingCount: provider.ratingCount,
      createdAt: provider.createdAt,
      updatedAt: provider.updatedAt,
    };
  }

  private toCityResponse(city: City) {
    return {
      id: city.id,
      nameAr: city.nameAr,
      nameEn: city.nameEn,
      countryCode: city.countryCode,
      sortOrder: city.sortOrder,
    };
  }

  private toCategoryResponse(category: ProviderCategory) {
    return {
      id: category.id,
      nameAr: category.nameAr,
      nameEn: category.nameEn,
      slug: category.slug,
      icon: category.icon,
      showForGroom: category.showForGroom,
      showForBride: category.showForBride,
      sortOrder: category.sortOrder,
    };
  }

  private toServiceResponse(service: ProviderDashboardServiceRecord) {
    return {
      id: service.id,
      providerId: service.providerId,
      categoryId: service.categoryId,
      category: this.toCategoryResponse(service.category),
      title: service.title,
      description: service.description,
      basePrice: service.basePrice?.toString() ?? null,
      priceUnit: service.priceUnit,
      currency: service.currency,
      cityId: service.cityId,
      city: service.city ? this.toCityResponse(service.city) : null,
      isActive: service.isActive,
      isFeatured: service.isFeatured,
      images: service.images.map((image) => this.toImageResponse(image)),
      createdAt: service.createdAt,
      updatedAt: service.updatedAt,
    };
  }

  private toImageResponse(image: ProviderServiceImage) {
    return {
      id: image.id,
      serviceId: image.serviceId,
      imageUrl: image.imageUrl,
      altText: image.altText,
      sortOrder: image.sortOrder,
      createdAt: image.createdAt,
    };
  }

  private toPackageResponse(providerPackage: ProviderPackageRecord) {
    return {
      id: providerPackage.id,
      providerId: providerPackage.providerId,
      serviceId: providerPackage.serviceId,
      service: providerPackage.service
        ? {
            id: providerPackage.service.id,
            title: providerPackage.service.title,
          }
        : null,
      title: providerPackage.title,
      description: providerPackage.description,
      price: providerPackage.price?.toString() ?? null,
      currency: providerPackage.currency,
      items: providerPackage.items,
      isActive: providerPackage.isActive,
      createdAt: providerPackage.createdAt,
      updatedAt: providerPackage.updatedAt,
    };
  }

  private toQuoteResponse(quote: ProviderQuoteRecord) {
    return {
      id: quote.id,
      userId: quote.userId,
      user: toApplicationUserContact(quote.user),
      weddingPlanId: quote.weddingPlanId,
      weddingPlan: quote.weddingPlan ?? null,
      providerId: quote.providerId,
      serviceId: quote.serviceId,
      service: quote.service
        ? {
            id: quote.service.id,
            title: quote.service.title,
            category: this.toCategoryResponse(quote.service.category),
          }
        : null,
      eventDate: quote.eventDate,
      location: weddingLocationResponse(quote.location),
      cityId: quote.cityId,
      guestCount: quote.guestCount,
      contactName: quote.contactName,
      contactPhone: quote.contactPhone,
      contactNormalizedPhone: quote.contactNormalizedPhone,
      message: quote.message,
      budgetMin: quote.budgetMin?.toString() ?? null,
      budgetMax: quote.budgetMax?.toString() ?? null,
      status: quote.status,
      lifecycleStatus: quoteLifecycleStatus(quote.status),
      offers: quote.offers?.map((offer) => this.toQuoteOfferResponse(offer)) ?? [],
      acceptedAt: quote.acceptedAt,
      rejectedAt: quote.rejectedAt,
      cancelledAt: quote.cancelledAt,
      createdAt: quote.createdAt,
      updatedAt: quote.updatedAt,
    };
  }

  private toReviewResponse(review: ProviderReviewRecord) {
    return {
      id: review.id,
      userId: review.userId,
      user: toReviewIdentity(review.user),
      providerId: review.providerId,
      rating: review.rating,
      comment: review.comment,
      status: review.status,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
    };
  }

  private toQuoteOfferResponse(offer: QuoteOffer) {
    const isExpired = isQuoteOfferExpired(offer);
    return {
      id: offer.id,
      quoteRequestId: offer.quoteRequestId,
      providerId: offer.providerId,
      title: offer.title,
      message: offer.message,
      amount: offer.amount?.toString() ?? null,
      currency: offer.currency,
      validUntil: offer.validUntil,
      status: offer.status,
      isExpired,
      isActionable: offer.status === QuoteOfferStatus.PENDING && !isExpired,
      createdAt: offer.createdAt,
      updatedAt: offer.updatedAt,
    };
  }
}
