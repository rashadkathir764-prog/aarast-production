import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import {
  ConversationReportStatus,
  Prisma,
  type ProviderCategory,
  ReviewStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { AdminPermission } from '../modules/backoffice/domain/admin-permissions';
import { optionalMoneyAmount } from '../shared-kernel/money/money';
import { PhoneNormalizer } from '../shared-kernel/phone/phone-normalizer';
import {
  lockProviderRatingRows,
  refreshProviderRating,
} from '../modules/marketplace/public/provider-review-rating';
import type { AdminReviewRow } from '../modules/marketplace/public/marketplace-admin.port';
import { PrismaService } from '../platform/database/prisma.service';
import { runAuthorizedAdminMutation } from '../modules/backoffice/public/admin-mutation-gate';
import { AdminOwners } from './admin-owners';
import {
  toAdminNotificationResponse,
  toAdminReviewResponse,
  toAdminServiceResponse,
  toCategoryAdminResponse,
  toCityResponse,
  toProviderResponse,
} from './admin.presenter';
import {
  AdminCategoryDto,
  AdminCityDto,
} from './dto/admin-catalog.dto';
import { AdminConversationReportStatusDto } from './dto/admin-conversation-report.dto';
import { AdminListedProviderDto } from './dto/admin-listed-provider.dto';
import { AdminReviewStatusDto } from './dto/admin-review.dto';
import { AdminServiceDto } from './dto/admin-service.dto';

export class AdminMutationExecutor {
  constructor(
    private readonly prisma: PrismaService,
    private readonly owners: AdminOwners,
  ) {}

  /**
   * Lists a provider who has no account yet (V1 checklist 4.18). It is
   * ACTIVE at once; its owner claims it by signing in with the same phone,
   * so a phone already on another provider is refused.
   */
  async createListedProvider(
    currentUser: AuthenticatedUser,
    dto: AdminListedProviderDto,
  ) {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const whatsapp = PhoneNormalizer.normalizeOptional(dto.whatsapp, 'whatsapp');
    const provider = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.PROVIDERS_WRITE,
      async (tx) => {
        const cityId = this.requiredText(dto.cityId, 'cityId');
        const categoryId = this.requiredText(dto.categoryId, 'categoryId');
        await this.lockCityForShare(tx, cityId);
        await this.lockCategoryForShare(tx, categoryId);
        if (
          await this.owners.marketplace.hasProviderWithPhone(
            tx,
            PhoneNormalizer.lookupVariants(phone),
          )
        ) {
          throw new ConflictException({
            statusCode: 409,
            code: 'PROVIDER_PHONE_TAKEN',
            message: 'A provider already uses this phone',
          });
        }
        const created =
          await this.owners.marketplace.createListedProviderInTransaction(tx, {
            businessName: this.requiredText(dto.businessName, 'businessName'),
            phone,
            whatsapp,
            cityId,
            primaryCategoryId: categoryId,
            description: this.optionalText(dto.description),
            address: this.optionalText(dto.address),
            reviewedAt: new Date(),
            reviewedById: currentUser.id,
          });
        return this.owners.attachProviderDetail(tx, created);
      },
    );
    return toProviderResponse(provider);
  }

  async createService(
    currentUser: AuthenticatedUser,
    dto: AdminServiceDto,
  ) {
    const service = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.SERVICES_WRITE,
      async (tx) => {
        const providerId = this.requiredText(dto.providerId, 'providerId');
        const categoryId = this.requiredText(dto.categoryId, 'categoryId');
        await this.lockProvider(tx, providerId);
        await this.lockCategoryForShare(tx, categoryId);
        if (dto.cityId) {
          await this.lockCityForShare(tx, dto.cityId);
        }
        const created = await this.owners.marketplace.createServiceInTransaction(tx, {
          providerId,
          categoryId,
          title: this.requiredText(dto.title, 'title'),
          description: this.optionalText(dto.description),
          basePrice: optionalMoneyAmount(dto.basePrice, 'basePrice'),
          priceUnit: this.optionalText(dto.priceUnit),
          currency: this.optionalText(dto.currency) ?? 'YER',
          cityId: this.optionalText(dto.cityId),
          isActive: dto.isActive ?? true,
        });
        const [attached] = await this.owners.attachServices(tx, [created]);
        return attached!;
      },
    );

    return toAdminServiceResponse(service);
  }

  async updateService(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminServiceDto,
  ) {
    const service = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.SERVICES_WRITE,
      async (tx) => {
        const seedProviderId =
          await this.owners.marketplace.findServiceProviderId(tx, id);
        if (!seedProviderId) {
          throw new NotFoundException('Provider service not found');
        }
        await this.lockProvider(tx, seedProviderId);
        const requestedProviderId =
          dto.providerId !== undefined
            ? this.requiredText(dto.providerId, 'providerId')
            : undefined;
        if (
          requestedProviderId !== undefined &&
          requestedProviderId !== seedProviderId
        ) {
          throw new BadRequestException(
            'providerId cannot be changed after a service is created',
          );
        }
        const categoryId =
          dto.categoryId !== undefined
            ? this.requiredText(dto.categoryId, 'categoryId')
            : undefined;
        if (categoryId !== undefined) {
          await this.lockCategoryForShare(tx, categoryId);
        }
        if (dto.cityId) {
          await this.lockCityForShare(tx, dto.cityId);
        }
        await this.lockService(tx, id, seedProviderId);
        const basePrice =
          dto.basePrice !== undefined
            ? optionalMoneyAmount(dto.basePrice, 'basePrice')
            : undefined;
        const updated = await this.owners.marketplace.updateServiceInTransaction(tx, id, {
          ...(categoryId !== undefined ? { categoryId } : {}),
          ...(dto.title !== undefined
            ? { title: this.requiredText(dto.title, 'title') }
            : {}),
          ...(dto.description !== undefined
            ? { description: this.optionalText(dto.description) }
            : {}),
          ...(dto.basePrice !== undefined ? { basePrice } : {}),
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
        });
        const [attached] = await this.owners.attachServices(tx, [updated]);
        return attached!;
      },
    );

    return toAdminServiceResponse(service);
  }

  async deleteService(currentUser: AuthenticatedUser, id: string) {
    const service = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.SERVICES_WRITE,
      async (tx) => {
        const seedProviderId =
          await this.owners.marketplace.findServiceProviderId(tx, id);
        if (!seedProviderId) {
          throw new NotFoundException('Provider service not found');
        }
        await this.lockProvider(tx, seedProviderId);
        await this.lockService(tx, id, seedProviderId);
        const updated = await this.owners.marketplace.updateServiceInTransaction(tx, id, {
          isActive: false,
        });
        const [attached] = await this.owners.attachServices(tx, [updated]);
        return attached!;
      },
    );

    return { ...toAdminServiceResponse(service), deleted: false };
  }

  async updateReviewStatus(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminReviewStatusDto,
  ) {
    return runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.REVIEWS_WRITE,
      async (tx) => {
        const review = await this.moderateReview(tx, id, () =>
          this.parseReviewStatus(dto.status),
        );
        return toAdminReviewResponse(review);
      },
    );
  }

  async hideReview(currentUser: AuthenticatedUser, id: string) {
    return runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.REVIEWS_WRITE,
      async (tx) => {
        const review = await this.moderateReview(
          tx,
          id,
          () => ReviewStatus.HIDDEN,
        );
        return { ...toAdminReviewResponse(review), deleted: false };
      },
    );
  }

  async updateConversationReportStatus(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminConversationReportStatusDto,
  ) {
    return runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.CONVERSATION_REPORTS_WRITE,
      async (tx) => {
        if (
          !(await this.owners.messaging.lockConversationReportForUpdateInTransaction(
            tx,
            id,
          ))
        ) {
          throw new NotFoundException('Conversation report not found');
        }
        const status = this.parseConversationReportStatus(dto.status);
        return this.owners.messaging.setConversationReportStatusInTransaction(
          tx,
          id,
          status,
        );
      },
    );
  }

  async markNotificationRead(currentUser: AuthenticatedUser, id: string) {
    const notification = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.NOTIFICATIONS_WRITE,
      async (tx) => {
        const read =
          await this.owners.notifications.markNotificationReadInTransaction(tx, id);
        if (!read) throw new NotFoundException('Notification not found');
        const [attached] = await this.owners.attachNotifications(tx, [read]);
        return attached!;
      },
    );
    return toAdminNotificationResponse(notification);
  }

  async archiveNotification(currentUser: AuthenticatedUser, id: string) {
    const notification = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.NOTIFICATIONS_WRITE,
      async (tx) => {
        const archived =
          await this.owners.notifications.archiveNotificationInTransaction(tx, id);
        if (!archived) throw new NotFoundException('Notification not found');
        const [attached] = await this.owners.attachNotifications(tx, [archived]);
        return attached!;
      },
    );
    return toAdminNotificationResponse(notification);
  }

  async deleteNotification(currentUser: AuthenticatedUser, id: string) {
    await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.NOTIFICATIONS_WRITE,
      async (tx) => {
        if (
          !(await this.owners.notifications.deleteNotificationInTransaction(tx, id))
        ) {
          throw new NotFoundException('Notification not found');
        }
      },
    );
    return { id, deleted: true };
  }

  async createCategory(
    currentUser: AuthenticatedUser,
    dto: AdminCategoryDto,
  ) {
    const showForGroom = dto.showForGroom ?? true;
    const showForBride = dto.showForBride ?? true;
    const isActive = dto.isActive ?? true;
    const category = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        this.assertActiveCategoryAudience(
          isActive,
          showForGroom,
          showForBride,
        );
        const created = await this.owners.catalog.createCategoryInTransaction(tx, {
          nameAr: this.requiredText(dto.nameAr, 'nameAr'),
          nameEn: this.optionalText(dto.nameEn),
          slug: this.toSlug(dto.slug ?? dto.nameEn ?? dto.nameAr),
          icon: this.optionalText(dto.icon),
          showForGroom,
          showForBride,
          isActive,
          sortOrder: dto.sortOrder ?? 0,
        });
        return this.categoryWithStarterItems(tx, created);
      },
    );

    return toCategoryAdminResponse(category.attached, category.starterItems);
  }

  /** The category as the admin reads it, and the starter items its budget line is read against. */
  private async categoryWithStarterItems(
    tx: Prisma.TransactionClient,
    category: ProviderCategory,
  ) {
    const [attached] = await this.owners.attachCategories(tx, [category]);
    return {
      attached: attached!,
      starterItems: await this.owners.catalog.listStarterBudgetItems(tx),
    };
  }

  async updateCategory(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminCategoryDto,
  ) {
    const category = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        const current =
          await this.owners.catalog.lockCategoryForUpdateInTransaction(tx, id);
        if (!current) {
          throw new NotFoundException('Provider category not found');
        }
        this.assertActiveCategoryAudience(
          dto.isActive ?? current.isActive,
          dto.showForGroom ?? current.showForGroom,
          dto.showForBride ?? current.showForBride,
        );
        const updated = await this.owners.catalog.updateCategoryInTransaction(tx, id, {
          ...(dto.nameAr !== undefined
            ? { nameAr: this.requiredText(dto.nameAr, 'nameAr') }
            : {}),
          ...(dto.nameEn !== undefined
            ? { nameEn: this.optionalText(dto.nameEn) }
            : {}),
          ...(dto.slug !== undefined ? { slug: this.toSlug(dto.slug) } : {}),
          ...(dto.icon !== undefined
            ? { icon: this.optionalText(dto.icon) }
            : {}),
          ...(dto.showForGroom !== undefined
            ? { showForGroom: dto.showForGroom }
            : {}),
          ...(dto.showForBride !== undefined
            ? { showForBride: dto.showForBride }
            : {}),
          ...(dto.isActive !== undefined
            ? { isActive: dto.isActive }
            : {}),
          ...(dto.sortOrder !== undefined
            ? { sortOrder: dto.sortOrder }
            : {}),
        });
        return this.categoryWithStarterItems(tx, updated);
      },
    );

    return toCategoryAdminResponse(category.attached, category.starterItems);
  }

  async deleteCategory(currentUser: AuthenticatedUser, id: string) {
    const category = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        if (!(await this.owners.catalog.lockCategoryForUpdateInTransaction(tx, id))) {
          throw new NotFoundException('Provider category not found');
        }
        const updated = await this.owners.catalog.updateCategoryInTransaction(
          tx,
          id,
          { isActive: false },
        );
        return this.categoryWithStarterItems(tx, updated);
      },
    );

    return {
      ...toCategoryAdminResponse(category.attached, category.starterItems),
      deleted: false,
    };
  }

  async createCity(currentUser: AuthenticatedUser, dto: AdminCityDto) {
    const city = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        const created = await this.owners.catalog.createCityInTransaction(tx, {
          nameAr: this.requiredText(dto.nameAr, 'nameAr'),
          nameEn: this.optionalText(dto.nameEn),
          countryCode: this.optionalText(dto.countryCode) ?? 'YE',
          isActive: dto.isActive ?? true,
          sortOrder: dto.sortOrder ?? 0,
        });
        const [attached] = await this.owners.attachCities(tx, [created]);
        return attached!;
      },
    );

    return toCityResponse(city);
  }

  async updateCity(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminCityDto,
  ) {
    const city = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        await this.lockCityForUpdate(tx, id);
        const updated = await this.owners.catalog.updateCityInTransaction(tx, id, {
          ...(dto.nameAr !== undefined
            ? { nameAr: this.requiredText(dto.nameAr, 'nameAr') }
            : {}),
          ...(dto.nameEn !== undefined
            ? { nameEn: this.optionalText(dto.nameEn) }
            : {}),
          ...(dto.countryCode !== undefined
            ? { countryCode: this.optionalText(dto.countryCode) ?? 'YE' }
            : {}),
          ...(dto.isActive !== undefined
            ? { isActive: dto.isActive }
            : {}),
          ...(dto.sortOrder !== undefined
            ? { sortOrder: dto.sortOrder }
            : {}),
        });
        const [attached] = await this.owners.attachCities(tx, [updated]);
        return attached!;
      },
    );

    return toCityResponse(city);
  }

  async deleteCity(currentUser: AuthenticatedUser, id: string) {
    const city = await runAuthorizedAdminMutation(
      this.prisma,
      this.owners.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        await this.lockCityForUpdate(tx, id);
        const updated = await this.owners.catalog.updateCityInTransaction(
          tx,
          id,
          { isActive: false },
        );
        const [attached] = await this.owners.attachCities(tx, [updated]);
        return attached!;
      },
    );

    return { ...toCityResponse(city), deleted: false };
  }

  /**
   * The review's provider rating lock (marketplace's public rating helper),
   * then the review's row lock, the status change and the rating refresh.
   * `status` is parsed once both locks are held.
   */
  private async moderateReview(
    tx: Prisma.TransactionClient,
    id: string,
    status: () => ReviewStatus,
  ) {
    const providerId = await this.owners.marketplace.findReviewProviderId(tx, id);
    if (!providerId) throw new NotFoundException('Review not found');
    const providers = await lockProviderRatingRows(tx, [providerId]);
    if (providers.length !== 1) {
      throw new NotFoundException('Provider not found');
    }
    if (
      !(await this.owners.marketplace.lockReviewForUpdateInTransaction(
        tx,
        id,
        providerId,
      ))
    ) {
      throw new NotFoundException('Review not found');
    }
    const review: AdminReviewRow =
      await this.owners.marketplace.setReviewStatusInTransaction(tx, id, status());
    if (!(await refreshProviderRating(tx, providerId))) {
      throw new NotFoundException('Provider not found');
    }
    const [attached] = await this.owners.attachReviews(tx, [review]);
    return attached!;
  }

  private async lockProvider(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<void> {
    if (!(await this.owners.marketplace.lockProviderForShareInTransaction(tx, providerId))) {
      throw new NotFoundException('Provider not found');
    }
  }

  private async lockService(
    tx: Prisma.TransactionClient,
    serviceId: string,
    expectedProviderId: string,
  ): Promise<void> {
    if (
      !(await this.owners.marketplace.lockServiceForUpdateInTransaction(
        tx,
        serviceId,
        expectedProviderId,
      ))
    ) {
      throw new NotFoundException('Provider service not found');
    }
  }

  private async lockCategoryForShare(
    tx: Prisma.TransactionClient,
    categoryId: string,
  ): Promise<void> {
    if (!(await this.owners.catalog.lockCategoryForShareInTransaction(tx, categoryId))) {
      throw new NotFoundException('Provider category not found');
    }
  }

  private async lockCityForShare(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<void> {
    if (!(await this.owners.catalog.lockCityForShareInTransaction(tx, cityId))) {
      throw new NotFoundException('City not found');
    }
  }

  private async lockCityForUpdate(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<void> {
    if (!(await this.owners.catalog.lockCityForUpdateInTransaction(tx, cityId))) {
      throw new NotFoundException('City not found');
    }
  }

  private parseReviewStatus(value: string): ReviewStatus {
    const normalized = this.requiredText(value, 'status').toUpperCase();
    if (normalized in ReviewStatus) {
      return ReviewStatus[normalized as keyof typeof ReviewStatus];
    }
    throw new BadRequestException('review status is not supported');
  }

  private parseConversationReportStatus(
    value: string,
  ): ConversationReportStatus {
    const normalized = this.requiredText(value, 'status').toUpperCase();
    if (normalized in ConversationReportStatus) {
      return ConversationReportStatus[
        normalized as keyof typeof ConversationReportStatus
      ];
    }
    throw new BadRequestException('conversation report status is not supported');
  }

  private requiredText(
    value: string | null | undefined,
    field: string,
  ): string {
    const trimmed = value?.trim() ?? '';
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private assertActiveCategoryAudience(
    isActive: boolean,
    showForGroom: boolean,
    showForBride: boolean,
  ): void {
    if (isActive && !showForGroom && !showForBride) {
      throw new BadRequestException(
        'An active provider category must belong to at least one wedding persona',
      );
    }
  }

  private toSlug(value: string | null | undefined): string {
    const slug = this.requiredText(value, 'slug')
      .trim()
      .toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^\p{L}\p{N}-]+/gu, '')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');

    if (!slug) throw new BadRequestException('slug must not be empty');
    return slug;
  }
}
