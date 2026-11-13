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
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../../../notifications/public/notifications.port";
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
import { UpdateProfileDto } from "../../api/user-dto/update-profile.dto";
import { UpdateSettingsDto } from "../../api/user-dto/update-settings.dto";
import { assertActiveMutationActorForUpdateInTransaction } from "../../public/user-lifecycle-lock";
import {
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
  findPlanOwnerContacts,
  lockUserForAccountDeletion,
} from '../../infrastructure/account-erasure.repository';
import {
  planErasedNotice,
  planMemberErasedNotice,
} from "./account-deletion-notices";
import { applicationDisplayName } from "../../../../shared-kernel/privacy/application-user-identity";
import {
  findPrivacySettings,
  updatePrivacySettings,
} from "../../infrastructure/data-request.repository";
import type { UpdatePrivacyDto } from "../../api/user-dto/privacy.dto";

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

/**
 * D63: what one purge attempt did: erased the account, found its request
 * taken back or its day not come, or found it already gone.
 */
export type AccountErasureOutcome = "ERASED" | "NOT_DUE" | "GONE";

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
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
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
   * D63: permanently erase an account whose 30 days of grace are over, and
   * every piece of data it owns. Only the purge job calls it (the app asks
   * for the deletion and may take it back, `AccountDeletionService`); under
   * the account's row lock it erases nothing unless the request still stands
   * and its day has come, so a take-back that commits first always wins.
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
  async eraseDueAccount(
    userId: string,
    now: Date,
  ): Promise<AccountErasureOutcome> {
    const outcome = await runRetryableTransaction(
      this.prisma,
      async (tx): Promise<AccountErasureOutcome> => {
        // The same advisory account lock used by presigning prevents a new
        // upload ticket from escaping this snapshot. It must be acquired
        // before the User row so media consumption and account deletion keep
        // one lock order.
        await this.mediaStorage.lockAccountDeletionBoundary(userId, tx);

        // Lock the account before enumerating its plans. A concurrent plan
        // create needs a foreign-key key-share lock on this row and therefore
        // cannot slip a new owned plan past the deletion snapshot.
        const lockedUsers = await lockUserForAccountDeletion(tx, userId);
        const account = lockedUsers[0];
        if (!account) return "GONE";
        if (
          !account.deletionRequestedAt ||
          !account.deletionScheduledFor ||
          account.deletionScheduledFor.getTime() > now.getTime()
        ) {
          return "NOT_DUE";
        }
        // One receipt per request: the same request erased twice (a second
        // job instance) finds the account gone above.
        const receiptHash = accountDeletionReceiptHash(
          userId,
          `grace:${account.deletionRequestedAt.toISOString()}`,
        );
        if (await findAccountDeletionReceipt(tx, receiptHash)) return "GONE";
        const preservesAdministratorIdentity =
          account.role === UserRole.ADMIN;
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

        // B-33: a provider with weddings still to do hands them over or
        // cancels them first. Read under the provider rows' locks (taken
        // above in the saga's order), so no confirmation slips in after it;
        // the refusal rolls back this whole transaction, so nothing was
        // erased (the purge job records it and the admin sees it on n06).
        const upcomingBookingIds =
          await this.marketplaceErasure.lockUpcomingConfirmedBookingIdsInTransaction(
            tx,
            providerIds,
            now,
          );
        if (upcomingBookingIds.length > 0) {
          throw new ConflictException({
            statusCode: 409,
            code: "PROVIDER_HAS_UPCOMING_BOOKINGS",
            message: "Hand over or cancel the upcoming bookings first",
            count: upcomingBookingIds.length,
            bookingIds: upcomingBookingIds,
          });
        }
        // Told after the purge below; built now, while the requests and the
        // memberships exist: the customers of his listing (B-33), the
        // providers of his requests and the members of his plans (D63).
        const notices = [
          ...(await this.marketplaceErasure.closedProviderNoticesInTransaction(
            tx,
            providerIds,
            now,
          )),
          ...(await this.marketplaceErasure.closedCustomerNoticesInTransaction(
            tx,
            { userId, weddingPlanIds: planIds },
            account.name,
            now,
          )),
          ...(await this.permissionService.listPlanMembers(tx, planIds)).map(
            (member) =>
              planErasedNotice({
                memberUserId: member.userId,
                weddingPlanId: member.weddingPlanId,
                owner: { name: account.name, persona: account.persona },
                erasedAt: now,
              }),
          ),
        ].filter((notice) => notice.userId !== userId);

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
        // V1 checklist 4.10: the account's private costs in other plans
        // (as a partner) are its own data and go with it.
        await this.finance.lockPrivateCostsForUpdateInTransaction(tx, userId);

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

        // D112 (Q-22), RA-BE-131: what the account recorded in another
        // person's plan stays in that plan. Its requests there (a helper
        // who booked the hall for the groom) pass to the plan's owner with
        // their offers and bookings, instead of going with the account by
        // cascade; and the owner of every plan it took part in is told.
        // Locked here, right after the owned requests, so the saga's lock
        // order is unchanged.
        const memberPlanRequests =
          await this.marketplaceErasure.lockMemberPlanQuoteRequestsForUpdateInTransaction(
            tx,
            {
              userId,
              weddingPlanIds: planIds,
              providerIds,
              conversationIds,
            },
          );
        const memberPlanIds = [
          ...new Set([
            ...memberPlanRequests.map((item) => item.weddingPlanId),
            ...(await this.permissionService.listMemberships(tx, userId)).map(
              (membership) => membership.weddingPlanId,
            ),
          ]),
        ].filter((weddingPlanId) => !planIds.includes(weddingPlanId));
        // An account that took part in no one else's plan asks nothing more.
        const planOwners =
          memberPlanIds.length === 0
            ? []
            : (
                await this.planErasure.listPlanOwnersInTransaction(
                  tx,
                  memberPlanIds,
                )
              ).filter((plan) => plan.ownerUserId !== userId);
        const ownerContacts = new Map(
          (planOwners.length === 0
            ? []
            : await findPlanOwnerContacts(
                tx,
                planOwners.map((plan) => plan.ownerUserId),
              )
          ).map((owner) => [owner.id, owner]),
        );
        const requestsByPlan = new Map(
          memberPlanRequests.map((item) => [
            item.weddingPlanId,
            item.quoteRequestIds,
          ]),
        );
        await this.marketplaceErasure.handOverQuoteRequestsInTransaction(
          tx,
          userId,
          planOwners.flatMap((plan) => {
            const owner = ownerContacts.get(plan.ownerUserId);
            const quoteRequestIds = requestsByPlan.get(plan.weddingPlanId);
            return owner && quoteRequestIds
              ? [
                  {
                    quoteRequestIds,
                    ownerUserId: owner.id,
                    contactName: applicationDisplayName(owner),
                    contactPhone: owner.phone,
                  },
                ]
              : [];
          }),
        );
        notices.push(
          ...planOwners.map((plan) =>
            planMemberErasedNotice({
              ownerUserId: plan.ownerUserId,
              weddingPlanId: plan.weddingPlanId,
              memberName: account.name,
              handedOverRequests:
                requestsByPlan.get(plan.weddingPlanId)?.length ?? 0,
              erasedAt: now,
            }),
          ),
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
        // Receipts (V1 checklist 4.4): those of the erased plans, and those
        // this account uploaded into other plans, go with their files.
        const receiptIds = await this.finance.listErasedReceiptIdsInTransaction(
          tx,
          planIds,
          userId,
        );
        await this.mediaStorage.scheduleCostReceiptDeletion(receiptIds, tx);
        await this.finance.deleteReceiptsInTransaction(tx, receiptIds);

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
        // V1 checklist 4.10: no one else ever saw the account's private costs
        // and tasks; they leave with it (their receipts went above).
        await this.finance.purgePrivateCostsInTransaction(tx, userId);
        await this.tasks.deletePrivateTasksInTransaction(tx, userId);
        const tenureEndedAt = now;
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
        // B-33 and D63: written after the notification purge above.
        for (const notice of notices) {
          await this.notifications.createNotificationInTransaction(tx, notice);
        }
        // A claim of a listing (B-12) is the account's own request.
        await this.marketplaceErasure.deleteUserClaimRequestsInTransaction(
          tx,
          userId,
        );

        if (preservesAdministratorIdentity) {
          await this.eraseAdministratorApplicationIdentity(
            tx,
            userId,
            account.phone,
          );
        }

        // The anonymous receipt commits atomically with erasure. It contains
        // neither the former user id nor the request's time and is immutable
        // at the database boundary.
        await createAccountDeletionReceipt(tx, receiptHash);

        if (!preservesAdministratorIdentity) {
          // Keyed by userId / phone with no User foreign key: never cascades.
          await deleteIdempotencyKeysForUser(tx, userId);
          if (account.phone) {
            await deleteOtpCodesByPhone(tx, account.phone);
          }

          // Finally the user. Cascades refresh tokens, memberships, personal
          // conversation state/messages, and any remaining requester rows;
          // SetNulls actor/creator fields in other owners' contexts. Historical
          // tenures were closed above and their immutable events are retained.
          await enqueueUserSessionsRevoked(tx, userId);
          await deleteAccountUser(tx, userId);
        }
        return "ERASED";
      },
      {
        timeout: 15_000,
        isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
      },
    );

    // The account no longer exists, so every authenticated realtime channel
    // must be severed immediately instead of surviving until token expiry.
    if (outcome === "ERASED") this.realtime?.disconnectUser(userId);
    return outcome;
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

  /** D63 (w40): the privacy choices kept on the server. */
  async getPrivacy(
    currentUser: AuthenticatedUser,
  ): Promise<{ reviewFirstNameOnly: boolean }> {
    const privacy = await findPrivacySettings(this.prisma, currentUser.id);
    if (!privacy) throw new NotFoundException("User not found");
    return privacy;
  }

  async updatePrivacy(
    currentUser: AuthenticatedUser,
    dto: UpdatePrivacyDto,
  ): Promise<{ reviewFirstNameOnly: boolean }> {
    return runRetryableTransaction(this.prisma, async (tx) => {
      await assertActiveMutationActorForUpdateInTransaction(tx, currentUser.id);
      return updatePrivacySettings(tx, currentUser.id, {
        reviewFirstNameOnly: dto.reviewFirstNameOnly,
      });
    });
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
