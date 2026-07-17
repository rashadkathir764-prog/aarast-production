import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  NotificationPreference,
  Prisma,
  UserRole,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { SafeUser, toSafeUser } from "../auth/safe-user";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { runRetryableTransaction } from "../common/prisma/serializable-transaction";
import { MediaStorageService } from "../media/media-storage.service";
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
   * plan's children leaf-to-root, then the plans, then the user — the remaining
   * user-owned rows are all `Cascade`/`SetNull`. Rows keyed by userId/phone
   * WITHOUT a foreign key (idempotency keys, OTP codes) never cascade, so they
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
        // the complete plan graph and avoids cross-plan lock inversions.
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

        const [notificationRows, conversationRows] = await Promise.all([
          tx.notification.findMany({
            where: { userId },
            select: { id: true },
          }),
          tx.conversationParticipant.findMany({
            where: { userId },
            select: { conversationId: true },
          }),
        ]);
        const notificationIds = notificationRows.map((row) => row.id);
        const conversationIds = conversationRows.map(
          (row) => row.conversationId,
        );
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

        // A provider profile would otherwise be orphaned (owner SetNull); erase
        // it — its own children are all Cascade/SetNull.
        await tx.provider.deleteMany({ where: { userId } });

        // Keyed by userId / phone with no User foreign key: never cascades.
        await tx.idempotencyKey.deleteMany({ where: { userId } });
        if (currentUser.phone) {
          await tx.otpCode.deleteMany({ where: { phone: currentUser.phone } });
        }

        // Finally the user. Cascades refresh tokens, shared memberships,
        // notifications, favorites, reviews, quote requests, conversations and
        // booking leads; SetNulls assigned tasks in others' plans and invitee
        // links.
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
