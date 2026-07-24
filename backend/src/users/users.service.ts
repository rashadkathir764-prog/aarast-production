import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  MediaUploadStatus,
  NotificationPreference,
  Prisma,
  UserRole,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { SafeUser, toSafeUser } from "../auth/safe-user";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { runRetryableTransaction } from "../common/prisma/serializable-transaction";
import { MediaStorageService } from "../media/media-storage.service";
import {
  lockProviderRatingRows,
  refreshProviderRating,
} from "../marketplace/provider-review-rating";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
import {
  applicationNameFields,
  toApplicationUserContact,
} from "./application-user-identity";
import { UpdateProfileDto } from "./dto/update-profile.dto";
import { UpdateSettingsDto } from "./dto/update-settings.dto";

export interface NotificationPreferenceResponse {
  id: string;
  userId: string;
  pushEnabled: boolean;
  smsEnabled: boolean;
  whatsappEnabled: boolean;
  emailEnabled: boolean;
  taskRemindersEnabled: boolean;
  paymentRemindersEnabled: boolean;
  providerMessagesEnabled: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/// Deliberately minimal: lookup exists only so a plan owner can confirm a
/// member before inviting. No avatar and no extra profile data — phone
/// numbers must not become a directory of user photos (culturally
/// sensitive, privacy-critical in Yemen).
export interface UserLookupResponse {
  id: string;
  name: string;
  phone: string | null;
}

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissionService: PermissionService,
    private readonly mediaStorage: MediaStorageService,
  ) {}

  async updateMe(
    currentUser: AuthenticatedUser,
    dto: UpdateProfileDto,
  ): Promise<SafeUser> {
    const email = this.optionalText(dto.email);
    const avatarUrl =
      dto.avatarUrl !== undefined
        ? await this.mediaStorage.verifyPublicMediaUrl(
            currentUser,
            dto.avatarUrl,
            "user-avatar",
          )
        : undefined;

    const user = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.user.findUniqueOrThrow({
        where: { id: currentUser.id },
        select: {
          role: true,
          avatarUrl: true,
          appAvatarUrl: true,
        },
      });
      const applicationAdmin =
        existing.role === UserRole.ADMIN && currentUser.adminMfa !== true;
      if (email) {
        const duplicateEmail = await tx.user.findFirst({
          where: {
            id: { not: currentUser.id },
            OR: [{ email }, { appEmail: email }],
          },
          select: { id: true },
        });
        if (duplicateEmail) {
          throw new ConflictException("Email is already registered");
        }
      }
      const currentAvatar = applicationAdmin
        ? existing.appAvatarUrl
        : existing.avatarUrl;
      const avatarTarget = {
        type: applicationAdmin
          ? ("USER_APP_AVATAR" as const)
          : ("USER_AVATAR" as const),
        id: currentUser.id,
      };
      const avatarChanged =
        dto.avatarUrl !== undefined && avatarUrl !== currentAvatar;
      if (avatarChanged) {
        await this.mediaStorage.scheduleTargetDeletion(
          avatarTarget,
          tx,
        );
      }
      if (avatarChanged && avatarUrl) {
        await this.mediaStorage.consumePublicMediaUrl(
          currentUser,
          avatarUrl,
          "user-avatar",
          avatarTarget,
          tx,
        );
      }
      return tx.user.update({
        where: { id: currentUser.id },
        data: {
          ...(dto.name !== undefined
            ? applicationAdmin
              ? { appName: this.requiredText(dto.name, "name") }
              : { name: this.requiredText(dto.name, "name") }
            : {}),
          ...(dto.email !== undefined
            ? applicationAdmin
              ? { appEmail: email }
              : { email }
            : {}),
          ...(dto.avatarUrl !== undefined
            ? applicationAdmin
              ? { appAvatarUrl: avatarUrl }
              : { avatarUrl }
            : {}),
          ...(dto.locale !== undefined
            ? { locale: this.requiredText(dto.locale, "locale") }
            : {}),
          ...(dto.appRole !== undefined ? { appRole: dto.appRole } : {}),
          ...(dto.persona !== undefined ? { persona: dto.persona } : {}),
        },
      });
    });

    return toSafeUser(user);
  }

  /**
   * Permanently delete the current account and every piece of data it owns.
   *
   * Wedding-plan children are protected by `onDelete: Restrict` (a deliberate
   * guard against accidental cascade of financial data), so an owned plan
   * cannot be removed until its children are gone. We therefore delete the
   * account's quote requests before the conversations they restrict, then the
   * plan children leaf-to-root, the plans/provider profile, and the user. Rows
   * keyed by userId/phone WITHOUT a foreign key (idempotency keys, OTP codes)
   * are removed explicitly. Everything runs in one transaction: any ordering
   * mistake rolls back rather than leaving the account half-deleted.
   */
  async deleteMe(currentUser: AuthenticatedUser): Promise<{ deleted: true }> {
    const userId = currentUser.id;

    const account = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true },
    });
    if (account?.role === UserRole.ADMIN) {
      throw new ForbiddenException(
        "Administrator identity cannot be deleted from the application",
      );
    }

    await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        // The same advisory account lock used by presigning prevents a new
        // upload ticket from escaping this snapshot. Tickets survive User
        // deletion (userId becomes null) as durable object-deletion jobs.
        await this.mediaStorage.scheduleAllOwnedMediaDeletion(userId, tx);

        // Lock the account before enumerating its plans. A concurrent plan
        // create needs a foreign-key key-share lock on this row and therefore
        // cannot slip a new owned plan past the deletion snapshot.
        const lockedUsers = await tx.$queryRaw<
          Array<{ id: string; role: UserRole }>
        >(
          Prisma.sql`
            SELECT "id", "role"
            FROM "User"
            WHERE "id" = ${userId}
            FOR UPDATE
          `,
        );
        if (lockedUsers.length === 0) {
          throw new NotFoundException("User not found");
        }
        if (lockedUsers[0].role === UserRole.ADMIN) {
          throw new ForbiddenException(
            "Administrator identity cannot be deleted from the application",
          );
        }

        // Parent rows are locked in a deterministic order before any child is
        // purged. This blocks new FK children while this transaction deletes
        // the complete account graph and avoids cross-context lock inversions.
        const ownedPlans = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            SELECT "id"
            FROM "WeddingPlan"
            WHERE "ownerUserId" = ${userId}
            ORDER BY "id" ASC
            FOR UPDATE
          `,
        );
        const planIds = ownedPlans.map((plan) => plan.id);

        const ownedProviders = await tx.provider.findMany({
          where: { userId },
          orderBy: { id: "asc" },
          select: { id: true },
        });
        const providerIds = ownedProviders.map((provider) => provider.id);
        const reviewedProviders = await tx.providerReview.findMany({
          where: { userId },
          distinct: ["providerId"],
          orderBy: { providerId: "asc" },
          select: { providerId: true },
        });
        const ownedProviderIds = new Set(providerIds);
        const externalRatedProviderIds = reviewedProviders
          .map((review) => review.providerId)
          .filter((providerId) => !ownedProviderIds.has(providerId));
        const lockedProviderIds = new Set(
          await lockProviderRatingRows(tx, [
            ...providerIds,
            ...externalRatedProviderIds,
          ]),
        );
        const ratingsToRefresh = externalRatedProviderIds.filter((providerId) =>
          lockedProviderIds.has(providerId),
        );

        if (reviewedProviders.length > 0) {
          // ProviderReview cascades from User, but the provider cache does not.
          // Remove these rows explicitly while every affected provider is
          // locked, then refresh each surviving external provider before the
          // account transaction can commit.
          await tx.providerReview.deleteMany({ where: { userId } });
          for (const providerId of ratingsToRefresh) {
            await refreshProviderRating(tx, providerId);
          }
        }

        if (planIds.length > 0) {
          // Every money mutation locks WeddingCost before CostPayment. Account
          // erasure follows the same order, so reversePayment can never hold a
          // cost while this path holds its payment and waits in the opposite
          // direction.
          await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              SELECT "id"
              FROM "WeddingCost"
              WHERE "weddingPlanId" IN (${Prisma.join(planIds)})
              ORDER BY "id" ASC
              FOR UPDATE
            `,
          );
        }

        const conversationPredicates: Prisma.Sql[] = [
          Prisma.sql`"accountRequesterUserId" = ${userId}`,
        ];
        if (planIds.length > 0) {
          conversationPredicates.push(
            Prisma.sql`"weddingPlanId" IN (${Prisma.join(planIds)})`,
          );
        }
        if (providerIds.length > 0) {
          conversationPredicates.push(
            Prisma.sql`"providerId" IN (${Prisma.join(providerIds)})`,
          );
        }
        // Only contexts owned by the account are selected here. Merely being
        // a Participant or creator in somebody else's PLAN conversation does
        // not make that conversation eligible for deletion.
        const conversationsToDelete = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            SELECT "id"
            FROM "Conversation"
            WHERE ${Prisma.join(conversationPredicates, " OR ")}
            ORDER BY "id" ASC
            FOR UPDATE
          `,
        );
        const conversationIds = conversationsToDelete.map(
          (conversation) => conversation.id,
        );

        const quoteRequestPredicates: Prisma.Sql[] = [
          Prisma.sql`"userId" = ${userId}`,
        ];
        if (planIds.length > 0) {
          quoteRequestPredicates.push(
            Prisma.sql`"weddingPlanId" IN (${Prisma.join(planIds)})`,
          );
        }
        if (providerIds.length > 0) {
          quoteRequestPredicates.push(
            Prisma.sql`"providerId" IN (${Prisma.join(providerIds)})`,
          );
        }
        if (conversationIds.length > 0) {
          quoteRequestPredicates.push(
            Prisma.sql`"conversationId" IN (${Prisma.join(conversationIds)})`,
          );
        }
        const quoteRequestsToDelete = await tx.$queryRaw<
          Array<{ id: string }>
        >(
          Prisma.sql`
            SELECT "id"
            FROM "QuoteRequest"
            WHERE ${Prisma.join(quoteRequestPredicates, " OR ")}
            ORDER BY "id" ASC
            FOR UPDATE
          `,
        );
        const quoteRequestIds = quoteRequestsToDelete.map((quote) => quote.id);

        const attachmentRows =
          conversationIds.length > 0
            ? await tx.chatAttachment.findMany({
                where: {
                  message: { conversationId: { in: conversationIds } },
                },
                orderBy: { id: "asc" },
                select: { id: true },
              })
            : [];
        const attachmentIds = attachmentRows.map((attachment) => attachment.id);
        if (attachmentIds.length > 0) {
          // A conversation can contain media uploaded by the other party. Its
          // durable ticket must survive the cascade as a deletion job too.
          await tx.mediaUploadTicket.updateMany({
            where: {
              consumedByType: "CHAT_ATTACHMENT",
              consumedById: { in: attachmentIds },
              status: MediaUploadStatus.VERIFIED,
            },
            data: { status: MediaUploadStatus.DELETE_PENDING },
          });
        }

        const notificationConditions: Prisma.NotificationWhereInput[] = [
          { userId },
        ];
        if (planIds.length > 0) {
          notificationConditions.push({ weddingPlanId: { in: planIds } });
        }
        if (quoteRequestIds.length > 0) {
          notificationConditions.push({
            entityType: "quote_request",
            entityId: { in: quoteRequestIds },
          });
        }
        const notificationRows = await tx.notification.findMany({
          where: { OR: notificationConditions },
          select: { id: true },
        });
        const notificationIds = notificationRows.map((row) => row.id);
        if (notificationIds.length > 0 || conversationIds.length > 0) {
          await tx.outboxEvent.deleteMany({
            where: {
              OR: [
                ...(notificationIds.length > 0
                  ? [
                      {
                        aggregateType: "notification",
                        aggregateId: { in: notificationIds },
                      },
                    ]
                  : []),
                ...(conversationIds.length > 0
                  ? [
                      {
                        aggregateType: "conversation",
                        aggregateId: { in: conversationIds },
                      },
                    ]
                  : []),
              ],
            },
          });
        }
        if (notificationIds.length > 0) {
          await tx.notification.deleteMany({
            where: { id: { in: notificationIds } },
          });
        }

        // QuoteRequest.conversationId is Restrict by design so ordinary quote
        // removal can never erase a shared thread. Account purge is the one
        // explicit path that removes all requests in owned contexts first,
        // then removes only those contexts.
        if (quoteRequestIds.length > 0) {
          await tx.quoteRequest.deleteMany({
            where: { id: { in: quoteRequestIds } },
          });
        }
        if (conversationIds.length > 0) {
          await tx.conversation.deleteMany({
            where: { id: { in: conversationIds } },
          });
        }
        if (planIds.length > 0) {
          const inPlans = { weddingPlanId: { in: planIds } };
          // CostPayment is append-only during normal product work. Account
          // erasure is the one explicit, transaction-local purge path.
          await tx.$executeRaw`
            SELECT set_config('aarast.allow_ledger_purge', 'on', true)
          `;
          await tx.costPayment.deleteMany({
            where: { weddingCost: inPlans },
          });
          await tx.paymentSchedule.deleteMany({
            where: { weddingCost: inPlans },
          });
          await tx.weddingCost.deleteMany({ where: inPlans });
          await tx.weddingTask.deleteMany({ where: inPlans }); // cascades checklist items
          await tx.guest.deleteMany({ where: inPlans });
          await tx.guestGroup.deleteMany({ where: inPlans });
          await tx.planProviderLink.deleteMany({ where: inPlans });
          await tx.sharedMember.deleteMany({ where: inPlans });
          await tx.planInvite.deleteMany({ where: inPlans });
          await tx.budgetCategory.deleteMany({ where: inPlans });
          await tx.weddingPlan.deleteMany({ where: { id: { in: planIds } } });
        }

        // A provider profile would otherwise be orphaned (owner SetNull). Its
        // customer requests/conversations were purged above; other owners'
        // plans and costs remain through the existing SetNull relations.
        if (providerIds.length > 0) {
          await tx.provider.deleteMany({
            where: { id: { in: providerIds } },
          });
        }

        // Keyed by userId / phone with no User foreign key: never cascades.
        await tx.idempotencyKey.deleteMany({ where: { userId } });
        if (currentUser.phone) {
          await tx.otpCode.deleteMany({ where: { phone: currentUser.phone } });
        }

        // Finally the user. Cascades refresh tokens, memberships, personal
        // conversation state/messages, and any remaining requester rows;
        // SetNulls actor/creator fields in other owners' contexts.
        await tx.user.delete({ where: { id: userId } });
      },
      {
        timeout: 15_000,
        isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
      },
    );

    return { deleted: true };
  }

  async lookupByPhone(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    phone: string,
  ): Promise<UserLookupResponse> {
    await this.permissionService.assertMemberManageable(
      weddingPlanId,
      currentUser,
    );
    const normalizedPhone = PhoneNormalizer.normalizeRequired(phone);
    const user = await this.prisma.user.findFirst({
      where: {
        phone: { in: PhoneNormalizer.lookupVariants(normalizedPhone) },
      },
      select: {
        id: true,
        phone: true,
        ...applicationNameFields,
      },
    });

    if (!user) {
      throw new NotFoundException("User not found for phone");
    }

    return toApplicationUserContact(user);
  }

  async getSettings(
    currentUser: AuthenticatedUser,
  ): Promise<NotificationPreferenceResponse> {
    const settings = await this.prisma.notificationPreference.upsert({
      where: { userId: currentUser.id },
      update: {},
      create: { userId: currentUser.id },
    });

    return this.toSettingsResponse(settings);
  }

  async updateSettings(
    currentUser: AuthenticatedUser,
    dto: UpdateSettingsDto,
  ): Promise<NotificationPreferenceResponse> {
    const settings = await this.prisma.notificationPreference.upsert({
      where: { userId: currentUser.id },
      create: {
        userId: currentUser.id,
        ...dto,
      },
      update: dto,
    });

    return this.toSettingsResponse(settings);
  }

  private requiredText(
    value: string | null | undefined,
    field: string,
  ): string {
    const trimmed = value?.trim() ?? "";
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

  private toSettingsResponse(
    settings: NotificationPreference,
  ): NotificationPreferenceResponse {
    return {
      id: settings.id,
      userId: settings.userId,
      pushEnabled: settings.pushEnabled,
      smsEnabled: settings.smsEnabled,
      whatsappEnabled: settings.whatsappEnabled,
      emailEnabled: settings.emailEnabled,
      taskRemindersEnabled: settings.taskRemindersEnabled,
      paymentRemindersEnabled: settings.paymentRemindersEnabled,
      providerMessagesEnabled: settings.providerMessagesEnabled,
      createdAt: settings.createdAt,
      updatedAt: settings.updatedAt,
    };
  }
}
