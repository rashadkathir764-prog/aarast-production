import {
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import {
  ConversationReportStatus,
  Prisma,
  ReviewStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { AdminPermission } from '../common/admin/admin-permissions';
import { optionalMoneyAmount } from '../common/validation/money';
import {
  lockProviderRatingRows,
  refreshProviderRating,
} from '../marketplace/provider-review-rating';
import { PrismaService } from '../prisma/prisma.service';
import { runAuthorizedAdminMutation } from './admin-mutation-gate';
import {
  toAdminNotificationResponse,
  toAdminReviewResponse,
  toAdminServiceResponse,
  toCategoryResponse,
  toCityResponse,
} from './admin.presenter';
import {
  AdminCategoryDto,
  AdminCityDto,
} from './dto/admin-catalog.dto';
import { AdminConversationReportStatusDto } from './dto/admin-conversation-report.dto';
import { AdminReviewStatusDto } from './dto/admin-review.dto';
import { AdminServiceDto } from './dto/admin-service.dto';

export class AdminMutationExecutor {
  constructor(private readonly prisma: PrismaService) {}

  async createService(
    currentUser: AuthenticatedUser,
    dto: AdminServiceDto,
  ) {
    const service = await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.SERVICES_WRITE,
      async (tx) => {
        const providerId = this.requiredText(dto.providerId, 'providerId');
        const categoryId = this.requiredText(dto.categoryId, 'categoryId');
        await this.lockProvider(tx, providerId);
        await this.lockCategory(tx, categoryId, 'SHARE');
        if (dto.cityId) {
          await this.lockCity(tx, dto.cityId, 'SHARE');
        }
        return tx.providerService.create({
          data: {
            providerId,
            categoryId,
            title: this.requiredText(dto.title, 'title'),
            description: this.optionalText(dto.description),
            basePrice: optionalMoneyAmount(dto.basePrice, 'basePrice'),
            priceUnit: this.optionalText(dto.priceUnit),
            currency: this.optionalText(dto.currency) ?? 'YER',
            cityId: this.optionalText(dto.cityId),
            isActive: dto.isActive ?? true,
            isFeatured: dto.isFeatured ?? false,
          },
          include: this.serviceInclude(),
        });
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
      currentUser,
      AdminPermission.SERVICES_WRITE,
      async (tx) => {
        const seed = await tx.providerService.findUnique({
          where: { id },
          select: { providerId: true },
        });
        if (!seed) {
          throw new NotFoundException('Provider service not found');
        }
        await this.lockProvider(tx, seed.providerId);
        const requestedProviderId =
          dto.providerId !== undefined
            ? this.requiredText(dto.providerId, 'providerId')
            : undefined;
        if (
          requestedProviderId !== undefined &&
          requestedProviderId !== seed.providerId
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
          await this.lockCategory(tx, categoryId, 'SHARE');
        }
        if (dto.cityId) {
          await this.lockCity(tx, dto.cityId, 'SHARE');
        }
        await this.lockService(tx, id, seed.providerId);
        const basePrice =
          dto.basePrice !== undefined
            ? optionalMoneyAmount(dto.basePrice, 'basePrice')
            : undefined;
        return tx.providerService.update({
          where: { id },
          data: {
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
            ...(dto.isFeatured !== undefined
              ? { isFeatured: dto.isFeatured }
              : {}),
          },
          include: this.serviceInclude(),
        });
      },
    );

    return toAdminServiceResponse(service);
  }

  async deleteService(currentUser: AuthenticatedUser, id: string) {
    const service = await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.SERVICES_WRITE,
      async (tx) => {
        const seed = await tx.providerService.findUnique({
          where: { id },
          select: { providerId: true },
        });
        if (!seed) {
          throw new NotFoundException('Provider service not found');
        }
        await this.lockProvider(tx, seed.providerId);
        await this.lockService(tx, id, seed.providerId);
        return tx.providerService.update({
          where: { id },
          data: { isActive: false, isFeatured: false },
          include: this.serviceInclude(),
        });
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
      currentUser,
      AdminPermission.REVIEWS_WRITE,
      async (tx) => {
        const seed = await tx.providerReview.findUnique({
          where: { id },
          select: { providerId: true },
        });
        if (!seed) throw new NotFoundException('Review not found');
        const providers = await lockProviderRatingRows(tx, [seed.providerId]);
        if (providers.length !== 1) {
          throw new NotFoundException('Provider not found');
        }
        await this.lockReview(tx, id, seed.providerId);
        const status = this.parseReviewStatus(dto.status);
        const review = await tx.providerReview.update({
          where: { id },
          data: { status },
          include: this.reviewInclude(),
        });
        if (!(await refreshProviderRating(tx, seed.providerId))) {
          throw new NotFoundException('Provider not found');
        }
        return toAdminReviewResponse(review);
      },
    );
  }

  async hideReview(currentUser: AuthenticatedUser, id: string) {
    return runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.REVIEWS_WRITE,
      async (tx) => {
        const seed = await tx.providerReview.findUnique({
          where: { id },
          select: { providerId: true },
        });
        if (!seed) throw new NotFoundException('Review not found');
        const providers = await lockProviderRatingRows(tx, [seed.providerId]);
        if (providers.length !== 1) {
          throw new NotFoundException('Provider not found');
        }
        await this.lockReview(tx, id, seed.providerId);
        const review = await tx.providerReview.update({
          where: { id },
          data: { status: ReviewStatus.HIDDEN },
          include: this.reviewInclude(),
        });
        if (!(await refreshProviderRating(tx, seed.providerId))) {
          throw new NotFoundException('Provider not found');
        }
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
      currentUser,
      AdminPermission.CONVERSATION_REPORTS_WRITE,
      async (tx) => {
        await this.lockConversationReport(tx, id);
        const status = this.parseConversationReportStatus(dto.status);
        return tx.conversationReport.update({
          where: { id },
          data: { status },
          select: {
            id: true,
            conversationId: true,
            reason: true,
            status: true,
            createdAt: true,
            updatedAt: true,
          },
        });
      },
    );
  }

  async markNotificationRead(currentUser: AuthenticatedUser, id: string) {
    const notification = await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.NOTIFICATIONS_WRITE,
      async (tx) => {
        await this.lockNotification(tx, id);
        return tx.notification.update({
          where: { id },
          data: { readAt: new Date() },
          include: this.notificationInclude(),
        });
      },
    );
    return toAdminNotificationResponse(notification);
  }

  async archiveNotification(currentUser: AuthenticatedUser, id: string) {
    const notification = await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.NOTIFICATIONS_WRITE,
      async (tx) => {
        const existing = await this.lockNotification(tx, id);
        const now = new Date();
        return tx.notification.update({
          where: { id },
          data: {
            archivedAt: now,
            readAt: existing.readAt ?? now,
          },
          include: this.notificationInclude(),
        });
      },
    );
    return toAdminNotificationResponse(notification);
  }

  async deleteNotification(currentUser: AuthenticatedUser, id: string) {
    await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.NOTIFICATIONS_WRITE,
      async (tx) => {
        await this.lockNotification(tx, id);
        await tx.notification.delete({ where: { id } });
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
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        this.assertActiveCategoryAudience(
          isActive,
          showForGroom,
          showForBride,
        );
        return tx.providerCategory.create({
          data: {
            nameAr: this.requiredText(dto.nameAr, 'nameAr'),
            nameEn: this.optionalText(dto.nameEn),
            slug: this.toSlug(dto.slug ?? dto.nameEn ?? dto.nameAr),
            icon: this.optionalText(dto.icon),
            showForGroom,
            showForBride,
            isActive,
            sortOrder: dto.sortOrder ?? 0,
          },
          include: { _count: { select: { providers: true, services: true } } },
        });
      },
    );

    return toCategoryResponse(category);
  }

  async updateCategory(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminCategoryDto,
  ) {
    const category = await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        await this.lockCategory(tx, id, 'UPDATE');
        const current = await tx.providerCategory.findUnique({
          where: { id },
          select: {
            showForGroom: true,
            showForBride: true,
            isActive: true,
          },
        });
        if (!current) {
          throw new NotFoundException('Provider category not found');
        }
        this.assertActiveCategoryAudience(
          dto.isActive ?? current.isActive,
          dto.showForGroom ?? current.showForGroom,
          dto.showForBride ?? current.showForBride,
        );
        return tx.providerCategory.update({
          where: { id },
          data: {
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
          },
          include: { _count: { select: { providers: true, services: true } } },
        });
      },
    );

    return toCategoryResponse(category);
  }

  async deleteCategory(currentUser: AuthenticatedUser, id: string) {
    const category = await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        await this.lockCategory(tx, id, 'UPDATE');
        return tx.providerCategory.update({
          where: { id },
          data: { isActive: false },
          include: { _count: { select: { providers: true, services: true } } },
        });
      },
    );

    return { ...toCategoryResponse(category), deleted: false };
  }

  async createCity(currentUser: AuthenticatedUser, dto: AdminCityDto) {
    const city = await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) =>
        tx.city.create({
          data: {
            nameAr: this.requiredText(dto.nameAr, 'nameAr'),
            nameEn: this.optionalText(dto.nameEn),
            countryCode: this.optionalText(dto.countryCode) ?? 'YE',
            isActive: dto.isActive ?? true,
            sortOrder: dto.sortOrder ?? 0,
          },
          include: { _count: { select: { providers: true, services: true } } },
        }),
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
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        await this.lockCity(tx, id, 'UPDATE');
        return tx.city.update({
          where: { id },
          data: {
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
          },
          include: { _count: { select: { providers: true, services: true } } },
        });
      },
    );

    return toCityResponse(city);
  }

  async deleteCity(currentUser: AuthenticatedUser, id: string) {
    const city = await runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        await this.lockCity(tx, id, 'UPDATE');
        return tx.city.update({
          where: { id },
          data: { isActive: false },
          include: { _count: { select: { providers: true, services: true } } },
        });
      },
    );

    return { ...toCityResponse(city), deleted: false };
  }

  private async lockProvider(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<void> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "id" = ${providerId}
        FOR SHARE
      `,
    );
    if (rows.length !== 1) {
      throw new NotFoundException('Provider not found');
    }
  }

  private async lockService(
    tx: Prisma.TransactionClient,
    serviceId: string,
    expectedProviderId: string,
  ): Promise<void> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderService"
        WHERE "id" = ${serviceId}
          AND "providerId" = ${expectedProviderId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) {
      throw new NotFoundException('Provider service not found');
    }
  }

  private async lockReview(
    tx: Prisma.TransactionClient,
    reviewId: string,
    expectedProviderId: string,
  ): Promise<void> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderReview"
        WHERE "id" = ${reviewId}
          AND "providerId" = ${expectedProviderId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) {
      throw new NotFoundException('Review not found');
    }
  }

  private async lockConversationReport(
    tx: Prisma.TransactionClient,
    reportId: string,
  ): Promise<void> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ConversationReport"
        WHERE "id" = ${reportId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) {
      throw new NotFoundException('Conversation report not found');
    }
  }

  private async lockNotification(
    tx: Prisma.TransactionClient,
    notificationId: string,
  ): Promise<{ id: string; readAt: Date | null }> {
    const rows = await tx.$queryRaw<Array<{ id: string; readAt: Date | null }>>(
      Prisma.sql`
        SELECT "id", "readAt"
        FROM "Notification"
        WHERE "id" = ${notificationId}
        FOR UPDATE
      `,
    );
    const notification = rows[0];
    if (!notification) {
      throw new NotFoundException('Notification not found');
    }
    return notification;
  }

  private async lockCategory(
    tx: Prisma.TransactionClient,
    categoryId: string,
    mode: 'SHARE' | 'UPDATE',
  ): Promise<void> {
    const rows =
      mode === 'UPDATE'
        ? await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              SELECT "id"
              FROM "ProviderCategory"
              WHERE "id" = ${categoryId}
              FOR UPDATE
            `,
          )
        : await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              SELECT "id"
              FROM "ProviderCategory"
              WHERE "id" = ${categoryId}
              FOR SHARE
            `,
          );
    if (rows.length !== 1) {
      throw new NotFoundException('Provider category not found');
    }
  }

  private async lockCity(
    tx: Prisma.TransactionClient,
    cityId: string,
    mode: 'SHARE' | 'UPDATE',
  ): Promise<void> {
    const rows =
      mode === 'UPDATE'
        ? await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              SELECT "id"
              FROM "City"
              WHERE "id" = ${cityId}
              FOR UPDATE
            `,
          )
        : await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              SELECT "id"
              FROM "City"
              WHERE "id" = ${cityId}
              FOR SHARE
            `,
          );
    if (rows.length !== 1) {
      throw new NotFoundException('City not found');
    }
  }

  private serviceInclude() {
    return {
      provider: { include: { city: true, primaryCategory: true } },
      category: true,
      city: true,
      images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
    } satisfies Prisma.ProviderServiceInclude;
  }

  private reviewInclude() {
    return {
      user: {
        select: { id: true, name: true, appName: true, role: true },
      },
      provider: { include: { city: true, primaryCategory: true } },
    } satisfies Prisma.ProviderReviewInclude;
  }

  private notificationInclude() {
    return {
      user: { select: { id: true, name: true, phone: true } },
      weddingPlan: { select: { id: true, title: true, city: true } },
    } satisfies Prisma.NotificationInclude;
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
