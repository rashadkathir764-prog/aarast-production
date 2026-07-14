import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { NotificationPreference } from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { SafeUser, toSafeUser } from "../auth/safe-user";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { MediaStorageService } from "../media/media-storage.service";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
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

    if (email) {
      const existing = await this.prisma.user.findUnique({ where: { email } });
      if (existing && existing.id !== currentUser.id) {
        throw new ConflictException("Email is already registered");
      }
    }
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
        select: { avatarUrl: true },
      });
      const avatarChanged =
        dto.avatarUrl !== undefined && avatarUrl !== existing.avatarUrl;
      if (avatarChanged) {
        await this.mediaStorage.scheduleTargetDeletion(
          { type: "USER_AVATAR", id: currentUser.id },
          tx,
        );
      }
      if (avatarChanged && avatarUrl) {
        await this.mediaStorage.consumePublicMediaUrl(
          currentUser,
          avatarUrl,
          "user-avatar",
          { type: "USER_AVATAR", id: currentUser.id },
          tx,
        );
      }
      return tx.user.update({
        where: { id: currentUser.id },
        data: {
          ...(dto.name !== undefined
            ? { name: this.requiredText(dto.name, "name") }
            : {}),
          ...(dto.email !== undefined ? { email } : {}),
          ...(dto.avatarUrl !== undefined ? { avatarUrl } : {}),
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

    await this.prisma.$transaction(
      async (tx) => {
        // The same advisory account lock used by presigning prevents a new
        // upload ticket from escaping this snapshot. Tickets survive User
        // deletion (userId becomes null) as durable object-deletion jobs.
        await this.mediaStorage.scheduleAllOwnedMediaDeletion(userId, tx);
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
        const ownedPlans = await tx.weddingPlan.findMany({
          where: { ownerUserId: userId },
          select: { id: true },
        });
        const planIds = ownedPlans.map((plan) => plan.id);

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
      { timeout: 15_000 },
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
        name: true,
        phone: true,
      },
    });

    if (!user) {
      throw new NotFoundException("User not found for phone");
    }

    return user;
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
