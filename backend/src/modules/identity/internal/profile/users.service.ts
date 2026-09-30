import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
  Optional,
} from "@nestjs/common";
import { createHash } from "node:crypto";
import {
  AppRole,
  AuthSessionScope,
  NotificationPreference,
  OtpPurpose,
  Prisma,
  UserRole,
} from "@prisma/client";
import { AuthenticatedUser } from "../../public/identity-session.types";
import { SafeUser } from "../../public/safe-user";
import { toSafeUser } from "../safe-user.presenter";
import { PhoneNormalizer } from "../../../../shared-kernel/phone/phone-normalizer";
import { runRetryableTransaction } from "../../../../platform/database/serializable-transaction";
import {
  MESSAGING_REALTIME_PORT,
  MessagingRealtimePort,
} from "../../../messaging/public/messaging-realtime.port";
import {
  MEDIA_STORAGE_PORT,
  MediaStoragePort,
} from "../../../media/public/media-storage.port";
import { enqueueUserSessionsRevoked } from "../../../../platform/outbox/realtime-revocation";
import { purgeOutboxEventsForAggregatesInTransaction } from "../../../../platform/outbox/outbox-purge";
import {
  deleteApplicationIdempotencyKeysForUser,
  deleteIdempotencyKeysForUser,
  deleteStaleIdempotencyReservation,
  findIdempotencyReservation,
} from "../../../../platform/idempotency/idempotency-keys";
import {
  COLLABORATION_ERASURE_PORT,
  type CollaborationErasurePort,
} from "../../../collaboration/public/collaboration-erasure.port";
import {
  FINANCE_PORT,
  type FinancePort,
} from "../../../finance/public/finance.port";
import { GUESTS_PORT, type GuestsPort } from "../../../guests/public/guests.port";
import {
  MARKETPLACE_ERASURE_PORT,
  type MarketplaceErasurePort,
} from "../../../marketplace/public/marketplace-erasure.port";
import {
  MESSAGING_ERASURE_PORT,
  type MessagingErasurePort,
} from "../../../messaging/public/messaging-erasure.port";
import {
  NOTIFICATIONS_ERASURE_PORT,
  type NotificationsErasurePort,
} from "../../../notifications/public/notifications-erasure.port";
import {
  PLAN_ERASURE_PORT,
  type PlanErasurePort,
} from "../../../planning/public/plan-erasure.port";
import { TASKS_PORT, type TasksPort } from "../../../tasks/public/tasks.port";
import {
  PUSH_CAPABILITY_PORT,
  PushCapabilityPort,
} from "../../../notifications/public/push-capability.port";
import {
  lockProviderRatingRows,
  refreshProviderRating,
} from "../../../marketplace/public/provider-review-rating";
import { PrismaService } from "../../../../platform/database/prisma.service";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
} from "../../../collaboration/public/collaboration-permission.port";
import {
  applicationNameFields,
  toApplicationUserContact,
} from "../../../../shared-kernel/privacy/application-user-identity";
import { UpdateProfileDto } from "../../api/user-dto/update-profile.dto";
import { UpdateSettingsDto } from "../../api/user-dto/update-settings.dto";
import { assertActiveMutationActorForUpdateInTransaction } from "../../public/user-lifecycle-lock";
import {
  findApplicationUserByPhone,
  findDuplicateProfileEmail,
  findProfileForUpdate,
  lockNotificationSettingsUser as lockNotificationSettingsUserRow,
  updateProfileUser,
} from '../../infrastructure/profile-user.repository';
import {
  clearAdministratorApplicationIdentity,
  createAccountDeletionReceipt,
  deleteAccountUser,
  deleteApplicationOtpCodesByPhone,
  deleteApplicationRefreshTokens,
  deleteOtpCodesByPhone,
  findAccountDeletionReceipt,
  lockUserForAccountDeletion,
  lockUserForDeletionStatus,
} from '../../infrastructure/account-erasure.repository';

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
  channelCapabilities: NotificationChannelCapabilitiesResponse;
  createdAt: Date;
  updatedAt: Date;
}

export interface NotificationChannelCapabilityResponse {
  supported: boolean;
  configurable: boolean;
  enabled: boolean;
}

export interface NotificationChannelCapabilitiesResponse {
  inApp: NotificationChannelCapabilityResponse;
  push: NotificationChannelCapabilityResponse;
  sms: NotificationChannelCapabilityResponse;
  whatsapp: NotificationChannelCapabilityResponse;
  email: NotificationChannelCapabilityResponse;
}

const NOTIFICATION_CHANNEL_CAPABILITIES: NotificationChannelCapabilitiesResponse =
  {
    inApp: { supported: true, configurable: false, enabled: true },
    push: { supported: true, configurable: false, enabled: false },
    sms: { supported: false, configurable: false, enabled: false },
    whatsapp: { supported: false, configurable: false, enabled: false },
    email: { supported: false, configurable: false, enabled: false },
  };

const UNSUPPORTED_NOTIFICATION_CHANNELS = [
  ["smsEnabled", "sms"],
  ["whatsappEnabled", "whatsapp"],
  ["emailEnabled", "email"],
] as const;

/// Deliberately minimal: lookup exists only so a plan owner can confirm a
/// member before inviting. No avatar and no extra profile data — phone
/// numbers must not become a directory of user photos (culturally
/// sensitive, privacy-critical in Yemen).
export interface UserLookupResponse {
  id: string;
  name: string;
  phone: string | null;
}

export type AccountDeletionStatus = "DELETED" | "PENDING" | "NOT_STARTED";
const ACCOUNT_DELETION_STALE_RESERVATION_MS = 30_000;

export function accountDeletionReceiptHash(
  userId: string,
  clientRequestId: string,
): string {
  return createHash("sha256")
    .update(userId)
    .update("\0")
    .update(clientRequestId)
    .digest("hex");
}

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissionService: PermissionService,
    @Inject(MEDIA_STORAGE_PORT)
    private readonly mediaStorage: MediaStoragePort,
    @Inject(PLAN_ERASURE_PORT)
    private readonly planErasure: PlanErasurePort,
    @Inject(MARKETPLACE_ERASURE_PORT)
    private readonly marketplaceErasure: MarketplaceErasurePort,
    @Inject(MESSAGING_ERASURE_PORT)
    private readonly messagingErasure: MessagingErasurePort,
    @Inject(NOTIFICATIONS_ERASURE_PORT)
    private readonly notificationsErasure: NotificationsErasurePort,
    @Inject(COLLABORATION_ERASURE_PORT)
    private readonly collaborationErasure: CollaborationErasurePort,
    @Inject(FINANCE_PORT)
    private readonly finance: FinancePort,
    @Inject(TASKS_PORT)
    private readonly tasks: TasksPort,
    @Inject(GUESTS_PORT)
    private readonly guests: GuestsPort,
    @Optional()
    @Inject(MESSAGING_REALTIME_PORT)
    private readonly realtime?: MessagingRealtimePort,
    @Optional()
    @Inject(PUSH_CAPABILITY_PORT)
    private readonly firebasePush?: PushCapabilityPort,
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

    const user = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        await assertActiveMutationActorForUpdateInTransaction(
          tx,
          currentUser.id,
        );
        const existing = await findProfileForUpdate(tx, currentUser.id);
        const applicationAdmin =
          existing.role === UserRole.ADMIN && currentUser.adminMfa !== true;
        if (email) {
          const duplicateEmail = await findDuplicateProfileEmail(
            tx,
            currentUser.id,
            email,
          );
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
          await this.mediaStorage.scheduleTargetDeletion(avatarTarget, tx);
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
        return updateProfileUser(tx, currentUser.id, {
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
            ...(dto.persona !== undefined ? { persona: dto.persona } : {}),
        });
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );

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
  async deleteMe(
    currentUser: AuthenticatedUser,
    clientRequestId: string,
  ): Promise<{ deleted: true }> {
    const userId = currentUser.id;
    const receiptHash = accountDeletionReceiptHash(userId, clientRequestId);

    await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const priorReceipt = await findAccountDeletionReceipt(tx, receiptHash);
        if (priorReceipt) return;

        // The same advisory account lock used by presigning prevents a new
        // upload ticket from escaping this snapshot. It must be acquired
        // before the User row so media consumption and account deletion keep
        // one lock order.
        await this.mediaStorage.lockAccountDeletionBoundary(userId, tx);

        // Lock the account before enumerating its plans. A concurrent plan
        // create needs a foreign-key key-share lock on this row and therefore
        // cannot slip a new owned plan past the deletion snapshot.
        const lockedUsers = await lockUserForAccountDeletion(tx, userId);
        if (lockedUsers.length === 0) {
          const committedWhileWaiting =
            await findAccountDeletionReceipt(tx, receiptHash);
          if (committedWhileWaiting) return;
          throw new NotFoundException("User not found");
        }
        const preservesAdministratorIdentity =
          lockedUsers[0].role === UserRole.ADMIN;

        // An administrator may separately enroll in the application. Deleting
        // that application identity must never delete the administrator's
        // login/profile media, while every ordinary application account keeps
        // the existing complete-account erasure behavior.
        if (preservesAdministratorIdentity) {
          await this.mediaStorage.scheduleApplicationIdentityMediaDeletion(
            userId,
            tx,
          );
        } else {
          await this.mediaStorage.scheduleAllOwnedMediaDeletion(userId, tx);
        }

        // Parent rows are locked in a deterministic order before any child is
        // purged. This blocks new FK children while this transaction deletes
        // the complete account graph and avoids cross-context lock inversions.
        // Every statement below runs in its table's owner, on this
        // transaction, in this order — the order is the FK-safe, deadlock-safe
        // specification of the saga.
        const planIds =
          await this.planErasure.lockOwnedPlanIdsForUpdateInTransaction(
            tx,
            userId,
          );

        const providerIds =
          await this.marketplaceErasure.listOwnedProviderIds(tx, userId);
        const reviewedProviderIds =
          await this.marketplaceErasure.listReviewedProviderIds(tx, userId);
        const ownedProviderIds = new Set(providerIds);
        const externalRatedProviderIds = reviewedProviderIds.filter(
          (providerId) => !ownedProviderIds.has(providerId),
        );
        const lockedProviderIds = new Set(
          await lockProviderRatingRows(tx, [
            ...providerIds,
            ...externalRatedProviderIds,
          ]),
        );
        const ratingsToRefresh = externalRatedProviderIds.filter((providerId) =>
          lockedProviderIds.has(providerId),
        );

        if (reviewedProviderIds.length > 0) {
          // ProviderReview cascades from User, but the provider cache does not.
          // Remove these rows explicitly while every affected provider is
          // locked, then refresh each surviving external provider before the
          // account transaction can commit.
          await this.marketplaceErasure.deleteUserReviewsInTransaction(
            tx,
            userId,
          );
          for (const providerId of ratingsToRefresh) {
            await refreshProviderRating(tx, providerId);
          }
        }

        // Every money mutation locks WeddingCost before CostPayment. Account
        // erasure follows the same order, so reversePayment can never hold a
        // cost while this path holds its payment and waits in the opposite
        // direction.
        await this.finance.lockPlanCostsForUpdateInTransaction(tx, planIds);

        const conversationIds =
          await this.messagingErasure.lockOwnedConversationIdsForUpdateInTransaction(
            tx,
            { userId, weddingPlanIds: planIds, providerIds },
          );

        const quoteRequestIds =
          await this.marketplaceErasure.lockOwnedQuoteRequestIdsForUpdateInTransaction(
            tx,
            {
              userId,
              weddingPlanIds: planIds,
              providerIds,
              conversationIds,
            },
          );

        const attachmentIds =
          await this.messagingErasure.listAttachmentIdsForConversations(
            tx,
            conversationIds,
          );
        await this.mediaStorage.scheduleChatAttachmentDeletion(
          attachmentIds,
          tx,
        );

        const notificationIds =
          await this.notificationsErasure.listOwnedNotificationIds(tx, {
            userId,
            weddingPlanIds: planIds,
            quoteRequestIds,
          });
        await purgeOutboxEventsForAggregatesInTransaction(tx, {
          notificationIds,
          conversationIds,
        });
        await this.notificationsErasure.deleteNotificationsInTransaction(
          tx,
          notificationIds,
        );

        // QuoteRequest.conversationId is Restrict by design so ordinary quote
        // removal can never erase a shared thread. Account purge is the one
        // explicit path that removes all requests in owned contexts first,
        // then removes only those contexts.
        await this.marketplaceErasure.deleteQuoteRequestsInTransaction(
          tx,
          quoteRequestIds,
        );
        await this.messagingErasure.deleteConversationsInTransaction(
          tx,
          conversationIds,
        );
        const tenureEndedAt = new Date();
        if (planIds.length > 0) {
          // Contribution history is retained independently from the live plan.
          // Close every active tenure before the plan/member graph disappears;
          // the append-only events and detached history scope remain intact.
          await this.collaborationErasure.markPlansDeletedInTransaction(
            tx,
            planIds,
            tenureEndedAt,
          );
        }
        // A contributor deleting the central account closes their tenures in
        // plans owned by other users without deleting the plan's audit trail.
        await this.collaborationErasure.closeActorTenuresInTransaction(
          tx,
          userId,
          tenureEndedAt,
        );
        if (planIds.length > 0) {
          await this.finance.purgePlanLedgerInTransaction(tx, planIds);
          await this.tasks.deletePlanTasksInTransaction(tx, planIds); // cascades checklist items
          await this.guests.deletePlanGuestsInTransaction(tx, planIds);
          await this.marketplaceErasure.deletePlanProviderLinksInTransaction(
            tx,
            planIds,
          );
          await this.collaborationErasure.deletePlanMembersAndInvitesInTransaction(
            tx,
            planIds,
          );
          await this.finance.deletePlanBudgetCategoriesInTransaction(
            tx,
            planIds,
          );
          await this.planErasure.deletePlansInTransaction(tx, planIds);
        }

        // A provider profile would otherwise be orphaned (owner SetNull). Its
        // customer requests/conversations were purged above; other owners'
        // plans and costs remain through the existing SetNull relations.
        await this.marketplaceErasure.deleteProvidersInTransaction(
          tx,
          providerIds,
        );

        if (preservesAdministratorIdentity) {
          await this.eraseAdministratorApplicationIdentity(
            tx,
            userId,
            currentUser.phone,
          );
        }

        // The anonymous receipt commits atomically with erasure. It contains
        // neither the former user id nor the request id and is immutable at the
        // database boundary, so a lost HTTP response remains recoverable.
        await createAccountDeletionReceipt(tx, receiptHash);

        if (!preservesAdministratorIdentity) {
          // Keyed by userId / phone with no User foreign key: never cascades.
          await deleteIdempotencyKeysForUser(tx, userId);
          if (currentUser.phone) {
            await deleteOtpCodesByPhone(tx, currentUser.phone);
          }

          // Finally the user. Cascades refresh tokens, memberships, personal
          // conversation state/messages, and any remaining requester rows;
          // SetNulls actor/creator fields in other owners' contexts. Historical
          // tenures were closed above and their immutable events are retained.
          await enqueueUserSessionsRevoked(tx, userId);
          await deleteAccountUser(tx, userId);
        }
      },
      {
        timeout: 15_000,
        isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
      },
    );

    // The account no longer exists, so every authenticated realtime channel
    // must be severed immediately instead of surviving until token expiry.
    this.realtime?.disconnectUser(userId);
    return { deleted: true };
  }

  private async eraseAdministratorApplicationIdentity(
    tx: Prisma.TransactionClient,
    userId: string,
    phone: string | null,
  ): Promise<void> {
    // These are the explicit equivalents of User cascades/SetNull relations.
    // The User row itself is retained because it is also the administrator
    // identity; admin review/audit relations and admin challenges stay linked.
    await this.tasks.unassignUserTasksInTransaction(tx, userId);
    await this.collaborationErasure.detachUserInTransaction(tx, userId);
    await this.notificationsErasure.deleteUserPreferencesAndInstallationsInTransaction(
      tx,
      userId,
    );
    await this.marketplaceErasure.deleteUserFavoritesInTransaction(tx, userId);
    await this.messagingErasure.eraseUserParticipationInTransaction(tx, userId);

    await deleteApplicationRefreshTokens(tx, userId);
    await deleteApplicationIdempotencyKeysForUser(tx, userId);
    if (phone) {
      await deleteApplicationOtpCodesByPhone(tx, phone);
    }
    await enqueueUserSessionsRevoked(tx, userId);
    await clearAdministratorApplicationIdentity(tx, userId);
  }

  async accountDeletionStatus(
    userId: string,
    clientRequestId: string,
  ): Promise<{ status: AccountDeletionStatus }> {
    const receiptHash = accountDeletionReceiptHash(userId, clientRequestId);
    return this.prisma.$transaction(
      async (tx) => {
        const receipt = await findAccountDeletionReceipt(tx, receiptHash);
        if (receipt) return { status: "DELETED" as const };

        const reservation = await findIdempotencyReservation(
          tx,
          userId,
          clientRequestId,
        );
        if (
          reservation?.method === "DELETE" &&
          reservation.path === "/api/v1/users/me"
        ) {
          if (
            reservation.completedAt === null &&
            reservation.createdAt.getTime() <=
              Date.now() - ACCOUNT_DELETION_STALE_RESERVATION_MS
          ) {
            // The deletion transaction has a hard 15-second timeout. A
            // reservation twice that old with no atomic receipt is a crashed
            // interceptor owner. Reclaim only that exact unfinished command;
            // deleteMe remains concurrent-safe through the User lock and the
            // unique receipt.
            const lockedUser = await lockUserForDeletionStatus(tx, userId);
            const receiptAfterLock =
              await findAccountDeletionReceipt(tx, receiptHash);
            if (receiptAfterLock) return { status: "DELETED" as const };
            if (lockedUser.length === 0) {
              return { status: "NOT_STARTED" as const };
            }
            await deleteStaleIdempotencyReservation(
              tx,
              reservation.id,
              new Date(Date.now() - ACCOUNT_DELETION_STALE_RESERVATION_MS),
            );
            return { status: "NOT_STARTED" as const };
          }
          return { status: "PENDING" as const };
        }
        const receiptAfterReservationRead =
          await findAccountDeletionReceipt(tx, receiptHash);
        if (receiptAfterReservationRead) {
          return { status: "DELETED" as const };
        }
        return { status: "NOT_STARTED" as const };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted },
    );
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
    const user = await findApplicationUserByPhone(
      this.prisma,
      PhoneNormalizer.lookupVariants(normalizedPhone),
    );

    if (!user) {
      throw new NotFoundException("User not found for phone");
    }

    return toApplicationUserContact(user);
  }

  async getSettings(
    currentUser: AuthenticatedUser,
  ): Promise<NotificationPreferenceResponse> {
    const settings = await runRetryableTransaction(this.prisma, async (tx) => {
      await this.lockNotificationSettingsUser(tx, currentUser.id);
      return this.notificationsErasure.ensurePreferenceInTransaction(
        tx,
        currentUser.id,
      );
    });

    return this.toSettingsResponse(settings);
  }

  async updateSettings(
    currentUser: AuthenticatedUser,
    dto: UpdateSettingsDto,
  ): Promise<NotificationPreferenceResponse> {
    if (dto.pushEnabled === true) {
      throw new BadRequestException({
        code: "NOTIFICATION_CHANNEL_DEVICE_MANAGED",
        channel: "push",
        message:
          "Push notifications are managed by the device notification permission",
      });
    }
    for (const [field, channel] of UNSUPPORTED_NOTIFICATION_CHANNELS) {
      if (dto[field] === true) {
        throw new BadRequestException({
          code: "NOTIFICATION_CHANNEL_UNSUPPORTED",
          channel,
          message: `The ${channel} notification channel is not available`,
        });
      }
    }
    const update = {
      smsEnabled: false,
      whatsappEnabled: false,
      emailEnabled: false,
      ...(dto.taskRemindersEnabled !== undefined
        ? { taskRemindersEnabled: dto.taskRemindersEnabled }
        : {}),
      ...(dto.paymentRemindersEnabled !== undefined
        ? { paymentRemindersEnabled: dto.paymentRemindersEnabled }
        : {}),
      ...(dto.providerMessagesEnabled !== undefined
        ? { providerMessagesEnabled: dto.providerMessagesEnabled }
        : {}),
    };
    const settings = await runRetryableTransaction(this.prisma, async (tx) => {
      await this.lockNotificationSettingsUser(tx, currentUser.id);
      return this.notificationsErasure.upsertPreferenceInTransaction(
        tx,
        currentUser.id,
        update,
      );
    });

    return this.toSettingsResponse(settings);
  }

  private async lockNotificationSettingsUser(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    const users = await lockNotificationSettingsUserRow(tx, userId);
    if (users.length !== 1 || users[0]?.status !== "ACTIVE") {
      throw new NotFoundException("User not found");
    }
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
      smsEnabled: false,
      whatsappEnabled: false,
      emailEnabled: false,
      taskRemindersEnabled: settings.taskRemindersEnabled,
      paymentRemindersEnabled: settings.paymentRemindersEnabled,
      providerMessagesEnabled: settings.providerMessagesEnabled,
      channelCapabilities: {
        ...NOTIFICATION_CHANNEL_CAPABILITIES,
        push: {
          ...NOTIFICATION_CHANNEL_CAPABILITIES.push,
          supported: this.firebasePush?.enabled === true,
          enabled: settings.pushEnabled,
        },
      },
      createdAt: settings.createdAt,
      updatedAt: settings.updatedAt,
    };
  }
}
