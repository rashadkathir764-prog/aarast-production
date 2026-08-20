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
  ContributionScopeStatus,
  MediaUploadStatus,
  NotificationPreference,
  OtpPurpose,
  Prisma,
  UserRole,
} from "@prisma/client";
import { AuthenticatedUser } from "../../public/identity-session.types";
import { SafeUser, toSafeUser } from "../../public/safe-user";
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
import {
  PUSH_CAPABILITY_PORT,
  PushCapabilityPort,
} from "../../../notifications/public/push-capability.port";
import {
  lockProviderRatingRows,
  refreshProviderRating,
} from "../../../../marketplace/provider-review-rating";
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
            ...(dto.persona !== undefined ? { persona: dto.persona } : {}),
          },
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
        const priorReceipt = await tx.accountDeletionReceipt.findUnique({
          where: { receiptHash },
          select: { receiptHash: true },
        });
        if (priorReceipt) return;

        // The same advisory account lock used by presigning prevents a new
        // upload ticket from escaping this snapshot. It must be acquired
        // before the User row so media consumption and account deletion keep
        // one lock order.
        await this.mediaStorage.lockAccountDeletionBoundary(userId, tx);

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
          const committedWhileWaiting =
            await tx.accountDeletionReceipt.findUnique({
              where: { receiptHash },
              select: { receiptHash: true },
            });
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
        const quoteRequestsToDelete = await tx.$queryRaw<Array<{ id: string }>>(
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
        const tenureEndedAt = new Date();
        if (planIds.length > 0) {
          // Contribution history is retained independently from the live plan.
          // Close every active tenure before the plan/member graph disappears;
          // the append-only events and detached history scope remain intact.
          await tx.contributorTenure.updateMany({
            where: {
              endedAt: null,
              historyScope: { weddingPlanId: { in: planIds } },
            },
            data: {
              endedAt: tenureEndedAt,
              endReason: "PLAN_DELETED",
              sharedMemberId: null,
            },
          });
          await tx.contributorHistoryScope.updateMany({
            where: { weddingPlanId: { in: planIds } },
            data: {
              status: ContributionScopeStatus.DELETED,
              deletedAt: tenureEndedAt,
            },
          });
        }
        // A contributor deleting the central account closes their tenures in
        // plans owned by other users without deleting the plan's audit trail.
        await tx.contributorTenure.updateMany({
          where: { actorUserId: userId, endedAt: null },
          data: {
            endedAt: tenureEndedAt,
            endReason: "ACCOUNT_DELETED",
            sharedMemberId: null,
          },
        });
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
        await tx.accountDeletionReceipt.create({
          data: { receiptHash },
        });

        if (!preservesAdministratorIdentity) {
          // Keyed by userId / phone with no User foreign key: never cascades.
          await tx.idempotencyKey.deleteMany({ where: { userId } });
          if (currentUser.phone) {
            await tx.otpCode.deleteMany({
              where: { phone: currentUser.phone },
            });
          }

          // Finally the user. Cascades refresh tokens, memberships, personal
          // conversation state/messages, and any remaining requester rows;
          // SetNulls actor/creator fields in other owners' contexts. Historical
          // tenures were closed above and their immutable events are retained.
          await enqueueUserSessionsRevoked(tx, userId);
          await tx.user.delete({ where: { id: userId } });
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
    await tx.weddingTask.updateMany({
      where: { assigneeUserId: userId },
      data: { assigneeUserId: null },
    });
    await tx.contributorTenure.updateMany({
      where: { actorUserId: userId },
      data: { actorUserId: null },
    });
    await tx.sharedMember.deleteMany({ where: { userId } });
    await tx.planInvite.deleteMany({ where: { inviterUserId: userId } });
    await tx.planInvite.updateMany({
      where: { inviteeUserId: userId },
      data: { inviteeUserId: null },
    });
    await tx.notificationPreference.deleteMany({ where: { userId } });
    await tx.pushInstallation.deleteMany({ where: { userId } });
    await tx.favoriteProvider.deleteMany({ where: { userId } });
    await tx.conversationParticipant.deleteMany({ where: { userId } });
    await tx.chatMessage.deleteMany({ where: { senderUserId: userId } });
    await tx.conversationReport.deleteMany({
      where: { reporterUserId: userId },
    });
    await tx.conversationEvent.updateMany({
      where: { actorUserId: userId },
      data: { actorUserId: null },
    });
    await tx.conversation.updateMany({
      where: { createdByUserId: userId },
      data: { createdByUserId: null },
    });
    await tx.conversation.updateMany({
      where: { customerSideBlockedById: userId },
      data: { customerSideBlockedById: null },
    });

    await tx.refreshToken.deleteMany({
      where: { userId, scope: AuthSessionScope.APPLICATION },
    });
    await tx.idempotencyKey.deleteMany({
      where: {
        userId,
        NOT: {
          OR: [
            { path: "/admin" },
            { path: { startsWith: "/admin/" } },
            { path: "/api/v1/admin" },
            { path: { startsWith: "/api/v1/admin/" } },
            { path: "/api/v1/auth/admin" },
            { path: { startsWith: "/api/v1/auth/admin/" } },
          ],
        },
      },
    });
    if (phone) {
      await tx.otpCode.deleteMany({
        where: {
          phone,
          purpose: {
            in: [
              OtpPurpose.REGISTER,
              OtpPurpose.LOGIN,
              OtpPurpose.INVITE_ACCESS,
              OtpPurpose.VERIFY_PHONE,
              OtpPurpose.RESET_PASSWORD,
            ],
          },
        },
      });
    }
    await enqueueUserSessionsRevoked(tx, userId);
    await tx.user.update({
      where: { id: userId },
      data: {
        appPasswordHash: null,
        appPasswordConfiguredAt: null,
        appName: null,
        appEmail: null,
        appAvatarUrl: null,
        appRole: AppRole.WEDDING_USER,
        activeWeddingPlanId: null,
        onboardingPath: null,
        persona: null,
        onboardingCompletedAt: null,
      },
    });
  }

  async accountDeletionStatus(
    userId: string,
    clientRequestId: string,
  ): Promise<{ status: AccountDeletionStatus }> {
    const receiptHash = accountDeletionReceiptHash(userId, clientRequestId);
    return this.prisma.$transaction(
      async (tx) => {
        const receipt = await tx.accountDeletionReceipt.findUnique({
          where: { receiptHash },
          select: { receiptHash: true },
        });
        if (receipt) return { status: "DELETED" as const };

        const reservation = await tx.idempotencyKey.findUnique({
          where: { userId_key: { userId, key: clientRequestId } },
          select: {
            id: true,
            method: true,
            path: true,
            completedAt: true,
            createdAt: true,
          },
        });
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
            const lockedUser = await tx.$queryRaw<Array<{ id: string }>>(
              Prisma.sql`
                SELECT "id"
                FROM "User"
                WHERE "id" = ${userId}
                FOR UPDATE
              `,
            );
            const receiptAfterLock =
              await tx.accountDeletionReceipt.findUnique({
                where: { receiptHash },
                select: { receiptHash: true },
              });
            if (receiptAfterLock) return { status: "DELETED" as const };
            if (lockedUser.length === 0) {
              return { status: "NOT_STARTED" as const };
            }
            await tx.idempotencyKey.deleteMany({
              where: {
                id: reservation.id,
                completedAt: null,
                createdAt: {
                  lte: new Date(
                    Date.now() - ACCOUNT_DELETION_STALE_RESERVATION_MS,
                  ),
                },
              },
            });
            return { status: "NOT_STARTED" as const };
          }
          return { status: "PENDING" as const };
        }
        const receiptAfterReservationRead =
          await tx.accountDeletionReceipt.findUnique({
            where: { receiptHash },
            select: { receiptHash: true },
          });
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
    const settings = await runRetryableTransaction(this.prisma, async (tx) => {
      await this.lockNotificationSettingsUser(tx, currentUser.id);
      return tx.notificationPreference.upsert({
        where: { userId: currentUser.id },
        update: {},
        create: { userId: currentUser.id },
      });
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
      return tx.notificationPreference.upsert({
        where: { userId: currentUser.id },
        create: {
          userId: currentUser.id,
          ...update,
        },
        update,
      });
    });

    return this.toSettingsResponse(settings);
  }

  private async lockNotificationSettingsUser(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    const users = await tx.$queryRaw<Array<{ id: string; status: string }>>(
      Prisma.sql`
        SELECT "id", "status"
        FROM "User"
        WHERE "id" = ${userId}
        FOR UPDATE
      `,
    );
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
