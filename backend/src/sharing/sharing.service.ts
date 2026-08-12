import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionProvenance,
  ContributionSection,
  NotificationPriority,
  NotificationType,
  PlanInvite,
  PlanInviteDeliveryStatus,
  Prisma,
  SharedMember,
  SharedMemberRole,
  User,
  UserStatus,
  WeddingPlan,
} from "@prisma/client";
import { createHash, randomBytes } from "crypto";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { invitationDeliveryPersistenceFailuresTotal } from "../platform/observability/metrics";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { canonicalPlanContextKey } from "../contexts/context-key";
import { ContributionHistoryService } from "../contribution-history/contribution-history.service";
import { buildContributionSnapshot } from "../contribution-history/contribution-snapshot.builder";
import { ConversationRealtimePublisher } from "../conversations/conversation-realtime.publisher";
import { NotificationsService } from "../notifications/notifications.service";
import { enqueueConversationAccessRevoked } from "../outbox/realtime-revocation";
import { PrismaService } from "../platform/database/prisma.service";
import {
  ApplicationNameSource,
  applicationDisplayName,
  applicationNameFields,
  toApplicationUserContact,
} from "../users/application-user-identity";
import {
  lockUserLifecycleRowsForUpdateInTransaction,
  lockUserLifecycleRowsInTransaction,
} from "../users/user-lifecycle-lock";
import { CreatePlanInviteDto } from "./dto/create-plan-invite.dto";
import { CreateSharedMemberDto } from "./dto/create-shared-member.dto";
import { LeavePlanDto } from "./dto/leave-plan.dto";
import { UpdateSharedMemberDto } from "./dto/update-shared-member.dto";
import {
  InvitationDeliveryResult,
  InvitationDeliveryService,
} from "./invitation-delivery.service";
import {
  assertWeddingPlanWritable,
  livePlanAuthorizationWhere,
  PermissionService,
  PlanAccessContext,
} from "./permission.service";
import {
  PlanPermissionFlags,
  rolePermissionDefaults,
} from "./plan-permissions";

export interface SharedMemberResponse {
  id: string;
  weddingPlanId: string;
  userId: string;
  user?: SafeSharedMemberUser;
  role: SharedMemberRole;
  canViewMoney: boolean;
  canEditPlan: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canInviteMembers: boolean;
  canManageMoney: boolean;
  receiveNotifications: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface PlanMemberResponse extends SharedMemberResponse {
  isOwner: boolean;
}

export interface SafeSharedMemberUser {
  id: string;
  name: string;
  phone: string | null;
}

type ApplicationContactRecord = ApplicationNameSource & {
  id: string;
  phone: string | null;
};

export interface SharedWeddingPlanResponse {
  id: string;
  title: string;
  city: string | null;
  weddingDate: Date | null;
  currency: string;
  status: string;
  sharedMember: SharedMemberResponse;
}

export interface PlanInviteResponse {
  id: string;
  weddingPlanId: string;
  contextKey?: string;
  token: string;
  name: string | null;
  phone: string | null;
  normalizedPhone: string | null;
  email: string | null;
  inviteeUserId: string | null;
  inviterUserId: string;
  role: SharedMemberRole;
  canViewMoney: boolean;
  canEditPlan: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canInviteMembers: boolean;
  canManageMoney: boolean;
  receiveNotifications: boolean;
  status: "PENDING" | "ACCEPTED" | "DECLINED" | "CANCELLED" | "EXPIRED";
  expiresAt: Date;
  acceptedAt: Date | null;
  declinedAt: Date | null;
  revokedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  weddingPlan?: {
    id: string;
    title: string;
    city: string | null;
    weddingDate: Date | null;
    status: string;
  };
  inviter?: SafeSharedMemberUser;
  invitee?: SafeSharedMemberUser | null;
  delivery: {
    channel: "WHATSAPP";
    status: PlanInviteDeliveryStatus;
    attemptedAt: Date | null;
    retryAfterSeconds: number;
  };
}

export interface PermissionSummaryResponse {
  weddingPlanId: string;
  userId: string;
  isOwner: boolean;
  role: SharedMemberRole | null;
  canViewMoney: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canManageMoney: boolean;
  canManagePlan: boolean;
  canManageMembers: boolean;
  receiveNotifications: boolean;
}

type PlanInviteWithRelations = PlanInvite & {
  weddingPlan?: Pick<
    WeddingPlan,
    "id" | "title" | "city" | "weddingDate" | "status"
  >;
  inviter?: ApplicationContactRecord;
  invitee?: ApplicationContactRecord | null;
};

type PermissionFlags = PlanPermissionFlags;

type AccessPermissionKey = Exclude<
  keyof PermissionFlags,
  "receiveNotifications"
>;

interface RevocationDescriptor {
  key: AccessPermissionKey;
  section: ContributionSection;
  permission: ContributionPermission;
}

type StoredPermissionRecord = PermissionFlags & {
  role: SharedMemberRole;
};

interface PresentedInvite {
  invite: PlanInviteWithRelations;
  token: string;
}

interface InviteDeliveryAttempt {
  inviteId: string;
  weddingPlanId: string;
  tokenHash: string;
  attemptedAt: Date;
}

const inviteReissueCooldownMs = 60_000;
const inviteReissueCooldownCode = "INVITE_REISSUE_COOLDOWN";
const inviteDeliverySupersededCode = "INVITE_DELIVERY_ATTEMPT_SUPERSEDED";
const inviteAuthorityRevokedCode = "INVITE_AUTHORITY_REVOKED";
const inviteAuthorityRevokedMessage =
  "لم تعد صلاحيات مُرسل الدعوة تسمح بقبولها";
const inviteAuthorityInactiveCode = "INVITE_AUTHORITY_INACTIVE";
const inviteAuthorityInactiveMessage =
  "\u0644\u0627 \u064a\u0645\u0643\u0646 \u0642\u0628\u0648\u0644 \u0627\u0644\u062f\u0639\u0648\u0629 \u0644\u0623\u0646 \u062d\u0633\u0627\u0628 \u0635\u0627\u062d\u0628 \u0627\u0644\u0635\u0644\u0627\u062d\u064a\u0629 \u0644\u0645 \u064a\u0639\u062f \u0646\u0634\u0637\u064b\u0627";
const memberReentryRequiresInviteCode = "MEMBER_REENTRY_REQUIRES_INVITE";
const memberReentryRequiresInviteMessage =
  "إعادة المشاركة بعد المغادرة تتطلب دعوة جديدة";
const ownerCannotLeaveCode = "PLAN_OWNER_CANNOT_LEAVE";
const ownerCannotLeaveMessage = "لا يمكن لمالك الخطة مغادرة خطته";

const revocationDescriptors: readonly RevocationDescriptor[] = [
  {
    key: "canManageTasks",
    section: ContributionSection.TASKS,
    permission: ContributionPermission.MANAGE_TASKS,
  },
  {
    key: "canManageGuests",
    section: ContributionSection.GUESTS,
    permission: ContributionPermission.MANAGE_GUESTS,
  },
  {
    key: "canViewMoney",
    section: ContributionSection.MONEY,
    permission: ContributionPermission.VIEW_MONEY,
  },
  {
    key: "canManageMoney",
    section: ContributionSection.MONEY,
    permission: ContributionPermission.MANAGE_MONEY,
  },
  {
    key: "canManageProviders",
    section: ContributionSection.PROVIDERS,
    permission: ContributionPermission.MANAGE_PROVIDERS,
  },
  {
    key: "canInviteMembers",
    section: ContributionSection.MEMBERS,
    permission: ContributionPermission.MANAGE_MEMBERS,
  },
  {
    key: "canEditPlan",
    section: ContributionSection.PLAN,
    permission: ContributionPermission.MANAGE_PLAN,
  },
];

@Injectable()
export class SharingService {
  private readonly logger = new Logger(SharingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
    private readonly notifications: NotificationsService,
    private readonly invitationDelivery: InvitationDeliveryService,
    private readonly history: ContributionHistoryService,
    @Optional() private readonly realtime?: ConversationRealtimePublisher,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateSharedMemberDto,
  ): Promise<SharedMemberResponse> {
    const access = await this.permissions.assertMemberManageable(
      weddingPlanId,
      currentUser,
    );
    const plan = access.plan;
    const user = await this.findTargetUser(dto);
    const role = this.assignableRole(dto.role ?? SharedMemberRole.VIEWER);
    const permissionData = this.permissionDataForDirectMemberCreate(dto);
    this.assertPermissionCeiling(access, role, permissionData);
    const userId = user.id;

    if (userId === plan.ownerUserId) {
      throw new BadRequestException("Owner cannot be added as a shared member");
    }

    const existing = await this.prisma.sharedMember.findUnique({
      where: { weddingPlanId_userId: { weddingPlanId, userId } },
    });
    if (existing) {
      throw new ConflictException(
        "User is already shared on this wedding plan",
      );
    }

    const member = await runSerializableTransaction(this.prisma, async (tx) => {
      const transactionalAccess =
        await this.permissions.assertMemberManageableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
          [userId],
        );
      this.assertPermissionCeiling(transactionalAccess, role, permissionData);
      const lockedTarget = await tx.user.findUnique({
        where: { id: userId },
        select: { status: true },
      });
      if (!lockedTarget || lockedTarget.status !== UserStatus.ACTIVE) {
        throw new BadRequestException("userId must reference an active user");
      }
      if (userId === transactionalAccess.plan.ownerUserId) {
        throw new BadRequestException(
          "Owner cannot be added as a shared member",
        );
      }
      const duplicate = await tx.sharedMember.findUnique({
        where: { weddingPlanId_userId: { weddingPlanId, userId } },
      });
      if (duplicate) {
        throw new ConflictException(
          "User is already shared on this wedding plan",
        );
      }
      if (
        await this.wasPreviouslyLeftInTransaction(tx, weddingPlanId, userId)
      ) {
        throw new HttpException(
          {
            statusCode: HttpStatus.CONFLICT,
            code: memberReentryRequiresInviteCode,
            message: memberReentryRequiresInviteMessage,
          },
          HttpStatus.CONFLICT,
        );
      }
      const created = await tx.sharedMember.create({
        data: {
          weddingPlanId,
          userId,
          role,
          ...permissionData,
        },
        include: {
          user: {
            select: { id: true, phone: true, ...applicationNameFields },
          },
        },
      });
      await this.history.ensureTenureInTransaction(tx, created);
      await this.history.recordForContextInTransaction(
        tx,
        transactionalAccess,
        {
          section: ContributionSection.MEMBERS,
          entityType: ContributionEntityType.MEMBER_ITEM,
          entityId: created.id,
          action: ContributionAction.CREATED,
          snapshot: buildContributionSnapshot(
            ContributionEntityType.MEMBER_ITEM,
            {
              displayName: applicationDisplayName(created.user),
              role: created.role,
              permissionLabels: this.permissionLabels(created),
            },
          ),
          dedupeKey: `member-created:${created.id}`,
          requiredPermission: ContributionPermission.MANAGE_MEMBERS,
          occurredAt: created.createdAt,
        },
      );
      if (created.canManageProviders) {
        await this.setProviderConversationParticipation(
          tx,
          weddingPlanId,
          userId,
          true,
        );
      }
      await this.notifications.createNotificationInTransaction(tx, {
        userId,
        weddingPlanId,
        type: NotificationType.SHARING_INVITATION,
        priority: NotificationPriority.HIGH,
        title: "تمت إضافتك إلى خطة زفاف",
        body: `أصبحت مشاركًا في "${transactionalAccess.plan.title}" بدور ${created.role}.`,
        entityType: "shared_member",
        entityId: created.id,
        routeTarget: `/wedding-plans/${weddingPlanId}/plan-center`,
        data: {
          sharedMemberId: created.id,
          weddingPlanId,
          role: created.role,
        },
        dedupeKey: `${userId}:sharing:${created.id}:invitation`,
      });
      return created;
    });

    return this.toMemberResponse(member);
  }

  async findSharedPlans(
    currentUser: AuthenticatedUser,
  ): Promise<SharedWeddingPlanResponse[]> {
    const members = await this.prisma.sharedMember.findMany({
      where: { userId: currentUser.id },
      include: {
        weddingPlan: true,
        user: {
          select: { id: true, phone: true, ...applicationNameFields },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    return members.map((member) =>
      this.toSharedPlanResponse(member.weddingPlan, member),
    );
  }

  async findMembersForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<PlanMemberResponse[]> {
    const access = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    const liveMembershipWhere = livePlanAuthorizationWhere(
      access,
      currentUser.id,
    );
    if (access.isOwner) {
      const plan = await this.prisma.weddingPlan.findFirst({
        where: { id: weddingPlanId, ...liveMembershipWhere },
        include: {
          owner: {
            select: { id: true, phone: true, ...applicationNameFields },
          },
        },
      });
      if (!plan) {
        throw new NotFoundException("Wedding plan not found");
      }
      const members = await this.prisma.sharedMember.findMany({
        where: {
          weddingPlanId,
          weddingPlan: { is: liveMembershipWhere },
        },
        include: {
          user: {
            select: { id: true, phone: true, ...applicationNameFields },
          },
        },
        orderBy: { createdAt: "asc" },
      });
      return [
        this.toOwnerMemberResponse(plan),
        ...members.map((member) => this.toPlanMemberResponse(member)),
      ];
    }

    const createdMemberIds = this.permissions.canManageMembers(access)
      ? await this.contributedEntityIds(
          weddingPlanId,
          currentUser.id,
          ContributionEntityType.MEMBER_ITEM,
          ContributionAction.CREATED,
        )
      : [];
    const allowedMemberIds = new Set(createdMemberIds);
    const members = await this.prisma.sharedMember.findMany({
      where: {
        weddingPlanId,
        weddingPlan: { is: liveMembershipWhere },
        OR: [
          { userId: currentUser.id },
          ...(createdMemberIds.length > 0
            ? [
                {
                  id: { in: createdMemberIds },
                  weddingPlan: {
                    is: livePlanAuthorizationWhere(
                      access,
                      currentUser.id,
                      ["canInviteMembers"],
                    ),
                  },
                },
              ]
            : []),
        ],
      },
      include: {
        user: {
          select: { id: true, phone: true, ...applicationNameFields },
        },
      },
      orderBy: { createdAt: "asc" },
    });
    return members
      .filter(
        (member) =>
          member.userId === currentUser.id || allowedMemberIds.has(member.id),
      )
      .map((member) => this.toPlanMemberResponse(member));
  }

  async createInvite(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreatePlanInviteDto,
  ): Promise<PlanInviteResponse> {
    const access = await this.permissions.assertMemberManageable(
      weddingPlanId,
      currentUser,
    );
    const plan = access.plan;
    const target = await this.findInviteTarget(dto);
    const role = this.assignableRole(dto.role ?? SharedMemberRole.VIEWER);
    const permissionData = this.permissionDataForCreate(role, dto);
    this.assertPermissionCeiling(access, role, permissionData);

    if (target.user?.id === plan.ownerUserId) {
      throw new BadRequestException(
        "Owner cannot be invited to own wedding plan",
      );
    }

    const created = await this.withUniqueInviteToken(async (token) =>
      runSerializableTransaction(this.prisma, async (tx) => {
        const transactionalAccess =
          await this.permissions.assertMemberManageableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
            target.user ? [target.user.id] : [],
          );
        this.assertPermissionCeiling(transactionalAccess, role, permissionData);
        if (target.user) {
          const lockedTarget = await tx.user.findUnique({
            where: { id: target.user.id },
            select: { status: true },
          });
          if (!lockedTarget || lockedTarget.status !== UserStatus.ACTIVE) {
            throw new BadRequestException(
              "userId must reference an active user",
            );
          }
        }
        if (target.user?.id === transactionalAccess.plan.ownerUserId) {
          throw new BadRequestException(
            "Owner cannot be invited to own wedding plan",
          );
        }

        if (target.user) {
          const existingMember = await tx.sharedMember.findUnique({
            where: {
              weddingPlanId_userId: {
                weddingPlanId,
                userId: target.user.id,
              },
            },
          });
          if (existingMember) {
            throw new ConflictException(
              "User is already shared on this wedding plan",
            );
          }
        }

        const now = new Date();
        const duplicateInvite = await tx.planInvite.findFirst({
          where: {
            weddingPlanId,
            acceptedAt: null,
            declinedAt: null,
            revokedAt: null,
            expiresAt: { gt: now },
            OR: [
              ...(target.user ? [{ inviteeUserId: target.user.id }] : []),
              ...(target.normalizedPhone
                ? [{ normalizedPhone: target.normalizedPhone }]
                : []),
              ...(target.email ? [{ email: target.email }] : []),
            ],
          },
        });
        if (duplicateInvite) {
          throw new ConflictException(
            "A pending invitation already exists for this participant",
          );
        }

        const invite = await tx.planInvite.create({
          data: {
            weddingPlanId,
            inviterUserId: currentUser.id,
            inviteeUserId: target.user?.id ?? null,
            name:
              this.optionalText(dto.name) ??
              (target.user ? applicationDisplayName(target.user) : null),
            phone: target.phone,
            normalizedPhone: target.normalizedPhone,
            email: target.email,
            role,
            ...permissionData,
            expiresAt: this.expiresAt(dto.expiresInDays),
            tokenHash: this.hashInviteToken(token),
            deliveryStatus: PlanInviteDeliveryStatus.PENDING,
            deliveryAttemptedAt: now,
          },
          include: this.inviteIncludes(),
        });

        await this.history.recordForContextInTransaction(
          tx,
          transactionalAccess,
          {
            section: ContributionSection.MEMBERS,
            entityType: ContributionEntityType.PLAN_INVITE,
            entityId: invite.id,
            action: ContributionAction.INVITED,
            snapshot: buildContributionSnapshot(
              ContributionEntityType.PLAN_INVITE,
              {
                displayName: invite.name,
                role: invite.role,
                permissionLabels: this.permissionLabels(invite),
                inviteState: "PENDING",
              },
            ),
            dedupeKey: `plan-invite-created:${invite.id}`,
            requiredPermission: ContributionPermission.MANAGE_MEMBERS,
            occurredAt: invite.createdAt,
          },
        );

        if (target.user) {
          await this.notifications.createNotificationInTransaction(tx, {
            userId: target.user.id,
            weddingPlanId,
            type: NotificationType.SHARING_INVITATION,
            priority: NotificationPriority.HIGH,
            title: "دعوة للمشاركة في خطة زفاف",
            body: `تلقيت دعوة للمشاركة في "${transactionalAccess.plan.title}".`,
            entityType: "plan_invite",
            entityId: invite.id,
            routeTarget: `/invites/${invite.id}`,
            data: {
              inviteId: invite.id,
              weddingPlanId,
              role: invite.role,
            },
            dedupeKey: `${target.user.id}:plan-invite:${invite.id}`,
          });
        }

        return invite;
      }),
    );

    const delivery = await this.invitationDelivery.deliver(
      created.invite.normalizedPhone,
      created.token,
    );
    const { invite: finalized, attempt } = await this.finalizeInviteDelivery(
      created,
      delivery,
    );
    return this.toInviteResponse(
      finalized,
      finalized.tokenHash === attempt.tokenHash ? created.token : undefined,
    );
  }

  async findInvitesForCurrentUser(
    currentUser: AuthenticatedUser,
  ): Promise<PlanInviteResponse[]> {
    const normalizedPhone = PhoneNormalizer.normalizeOptional(
      currentUser.phone,
    );
    const invites = await this.prisma.planInvite.findMany({
      where: {
        OR: [
          { inviteeUserId: currentUser.id },
          ...(normalizedPhone ? [{ normalizedPhone }] : []),
        ],
      },
      include: this.inviteIncludes(),
      orderBy: { createdAt: "desc" },
    });
    const acceptedPlanIds = [
      ...new Set(
        invites
          .filter(
            (invite) =>
              this.inviteStatus(invite) === "ACCEPTED" &&
              invite.inviteeUserId === currentUser.id,
          )
          .map((invite) => invite.weddingPlanId),
      ),
    ];
    const liveMemberships =
      acceptedPlanIds.length === 0
        ? []
        : await this.prisma.sharedMember.findMany({
            where: {
              userId: currentUser.id,
              weddingPlanId: { in: acceptedPlanIds },
            },
            select: { weddingPlanId: true },
          });
    const liveMembershipPlanIds = new Set(
      liveMemberships.map((membership) => membership.weddingPlanId),
    );
    return invites.map((invite) =>
      this.toCurrentUserInviteResponse(
        invite,
        currentUser.id,
        liveMembershipPlanIds.has(invite.weddingPlanId),
      ),
    );
  }

  async getInviteForCurrentUser(
    currentUser: AuthenticatedUser,
    token: string,
  ): Promise<PlanInviteResponse> {
    const invite = await this.findInviteByTokenOrThrow(token);
    this.assertInviteBelongsToCurrentUser(invite, currentUser);
    const liveMembership =
      this.inviteStatus(invite) === "ACCEPTED" &&
      invite.inviteeUserId === currentUser.id
        ? await this.prisma.sharedMember.findUnique({
            where: {
              weddingPlanId_userId: {
                weddingPlanId: invite.weddingPlanId,
                userId: currentUser.id,
              },
            },
            select: { id: true },
          })
        : null;
    return this.toCurrentUserInviteResponse(
      invite,
      currentUser.id,
      Boolean(liveMembership),
    );
  }

  async findInvitesForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<PlanInviteResponse[]> {
    const access = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    if (!this.permissions.canManageMembers(access)) {
      throw new NotFoundException("Wedding plan not found");
    }
    const invites = await this.prisma.planInvite.findMany({
      where: {
        weddingPlanId,
        weddingPlan: {
          is: livePlanAuthorizationWhere(access, currentUser.id, [
            "canInviteMembers",
          ]),
        },
        ...(access.isOwner ? {} : { inviterUserId: currentUser.id }),
      },
      include: this.inviteIncludes(),
      orderBy: { createdAt: "desc" },
    });
    return invites
      .filter(
        (invite) => access.isOwner || invite.inviterUserId === currentUser.id,
      )
      .map((invite) => this.toInviteResponse(invite));
  }

  async cancelInvite(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    inviteId: string,
  ): Promise<PlanInviteResponse> {
    await this.permissions.assertMemberManageable(weddingPlanId, currentUser);

    const cancelled = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const transactionalAccess =
          await this.permissions.assertMemberManageableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        const invite = await tx.planInvite.findFirst({
          where: { id: inviteId, weddingPlanId },
          include: this.inviteIncludes(),
        });
        if (!invite) throw new NotFoundException("Invite not found");
        if (
          !transactionalAccess.isOwner &&
          invite.inviterUserId !== currentUser.id
        ) {
          throw new NotFoundException("Invite not found");
        }
        this.assertPermissionCeiling(
          transactionalAccess,
          invite.role,
          this.permissionFlagsForRecord(invite),
        );

        const now = new Date();
        const claimed = await tx.planInvite.updateMany({
          where: {
            id: invite.id,
            weddingPlanId,
            tokenHash: invite.tokenHash,
            acceptedAt: null,
            declinedAt: null,
            revokedAt: null,
            expiresAt: { gt: now },
          },
          data: { revokedAt: now },
        });
        if (claimed.count !== 1) {
          throw new ConflictException("Invite is no longer pending");
        }

        const updated = await tx.planInvite.findUnique({
          where: { id: invite.id },
          include: this.inviteIncludes(),
        });
        if (!updated) {
          throw new ConflictException("Invite is no longer pending");
        }
        return updated;
      },
    );
    return this.toInviteResponse(cancelled);
  }

  async reissueInvite(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    inviteId: string,
    dto: UpdateSharedMemberDto = {},
  ): Promise<PlanInviteResponse> {
    await this.permissions.assertMemberManageable(weddingPlanId, currentUser);

    const reissued = await this.withUniqueInviteToken(async (token) =>
      runSerializableTransaction(this.prisma, async (tx) => {
        const transactionalAccess =
          await this.permissions.assertMemberManageableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        const invite = await tx.planInvite.findFirst({
          where: { id: inviteId, weddingPlanId },
          include: this.inviteIncludes(),
        });
        if (!invite) {
          throw new NotFoundException("Invite not found");
        }
        if (
          !transactionalAccess.isOwner &&
          invite.inviterUserId !== currentUser.id
        ) {
          throw new NotFoundException("Invite not found");
        }
        this.assertPermissionCeiling(
          transactionalAccess,
          invite.role,
          this.permissionFlagsForRecord(invite),
        );

        const now = new Date();
        if (
          invite.acceptedAt ||
          invite.declinedAt ||
          invite.revokedAt ||
          invite.expiresAt.getTime() <= now.getTime()
        ) {
          throw new ConflictException("Invite is no longer pending");
        }
        const role = this.assignableRole(dto.role ?? invite.role);
        const permissionData = this.permissionDataForUpdate(invite, dto, role);
        this.assertPermissionCeiling(transactionalAccess, role, permissionData);
        this.assertInviteReissueCooldownElapsed(
          invite.deliveryAttemptedAt,
          now,
        );

        const updated = await tx.planInvite.updateMany({
          where: {
            id: invite.id,
            weddingPlanId,
            tokenHash: invite.tokenHash,
            acceptedAt: null,
            declinedAt: null,
            revokedAt: null,
            expiresAt: { gt: now },
          },
          data: {
            tokenHash: this.hashInviteToken(token),
            deliveryStatus: PlanInviteDeliveryStatus.PENDING,
            deliveryAttemptedAt: now,
            ...(dto.role !== undefined ? { role } : {}),
            ...permissionData,
          },
        });
        if (updated.count !== 1) {
          throw new ConflictException("Invite is no longer pending");
        }

        const rotated = await tx.planInvite.findUnique({
          where: { id: invite.id },
          include: this.inviteIncludes(),
        });
        if (!rotated) {
          throw new ConflictException("Invite is no longer pending");
        }
        return rotated;
      }),
    );

    const delivery = await this.invitationDelivery.deliver(
      reissued.invite.normalizedPhone,
      reissued.token,
    );
    const { invite: finalized, attempt } = await this.finalizeInviteDelivery(
      reissued,
      delivery,
    );
    return this.toInviteResponse(
      finalized,
      finalized.tokenHash === attempt.tokenHash ? reissued.token : undefined,
    );
  }

  async acceptInvite(
    currentUser: AuthenticatedUser,
    token: string,
  ): Promise<{
    invite: PlanInviteResponse;
    member: SharedMemberResponse;
    contextKey: string;
  }> {
    const resolvedInvite = await this.findInviteByTokenOrThrow(token);
    this.assertInviteBelongsToCurrentUser(resolvedInvite, currentUser);

    const acceptedAt = new Date();
    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const planSeed = await tx.weddingPlan.findUnique({
        where: { id: resolvedInvite.weddingPlanId },
        select: { ownerUserId: true },
      });
      if (!planSeed) {
        throw new NotFoundException("Wedding plan not found");
      }
      const lifecycleUsers = await lockUserLifecycleRowsInTransaction(tx, [
        currentUser.id,
        resolvedInvite.inviterUserId,
        planSeed.ownerUserId,
      ]);
      const actor = lifecycleUsers.find((user) => user.id === currentUser.id);
      const inviterLifecycle = lifecycleUsers.find(
        (user) => user.id === resolvedInvite.inviterUserId,
      );
      const ownerLifecycle = lifecycleUsers.find(
        (user) => user.id === planSeed.ownerUserId,
      );
      if (
        !actor ||
        actor.status !== UserStatus.ACTIVE ||
        !inviterLifecycle ||
        !ownerLifecycle
      ) {
        throw new NotFoundException("Invite not found");
      }
      if (
        inviterLifecycle.status !== UserStatus.ACTIVE ||
        ownerLifecycle.status !== UserStatus.ACTIVE
      ) {
        throw this.inviteAuthorityInactive();
      }
      const lockedPlan = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "WeddingPlan"
          WHERE "id" = ${resolvedInvite.weddingPlanId}
          FOR SHARE
        `,
      );
      if (lockedPlan.length !== 1) {
        throw new NotFoundException("Wedding plan not found");
      }
      const plan = await tx.weddingPlan.findUnique({
        where: { id: resolvedInvite.weddingPlanId },
      });
      if (!plan || plan.ownerUserId !== planSeed.ownerUserId) {
        throw new NotFoundException("Wedding plan not found");
      }
      assertWeddingPlanWritable(plan);

      const delegatedInviterMember =
        await this.lockDelegatedInviteAuthorityInTransaction(
          tx,
          resolvedInvite,
          plan,
        );

      const lockedInvite = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "PlanInvite"
          WHERE "id" = ${resolvedInvite.id}
          FOR UPDATE
        `,
      );
      if (lockedInvite.length !== 1) {
        throw new ConflictException("Invite is no longer pending");
      }
      const invite = await tx.planInvite.findUnique({
        where: { id: resolvedInvite.id },
        include: this.inviteIncludes(),
      });
      if (!invite) {
        throw new ConflictException("Invite is no longer pending");
      }
      if (
        invite.acceptedAt &&
        !invite.declinedAt &&
        !invite.revokedAt &&
        currentUser.phoneVerifiedAt &&
        invite.inviteeUserId === currentUser.id
      ) {
        const presentedTokenStillMatches =
          token === invite.id ||
          invite.tokenHash === this.hashInviteToken(token);
        if (!presentedTokenStillMatches) {
          throw new ConflictException("Invite is no longer pending");
        }
        const member = await tx.sharedMember.findUnique({
          where: {
            weddingPlanId_userId: {
              weddingPlanId: invite.weddingPlanId,
              userId: currentUser.id,
            },
          },
          include: {
            user: {
              select: { id: true, phone: true, ...applicationNameFields },
            },
          },
        });
        if (!member) {
          throw new ConflictException(
            "Accepted invitation membership is no longer active",
          );
        }
        await this.history.ensureTenureInTransaction(tx, member);
        await this.recordAcceptedInviteMemberForInviterInTransaction(
          tx,
          invite,
          member,
          invite.acceptedAt,
        );
        return { member, acceptedInvite: invite };
      }
      this.assertInviteCanBeAccepted(invite, currentUser);
      this.assertPendingInviteAuthority(
        invite,
        plan,
        delegatedInviterMember,
      );

      const claimed = await tx.planInvite.updateMany({
        where: {
          id: invite.id,
          ...this.inviteClaimTokenFilter(invite, token),
          acceptedAt: null,
          declinedAt: null,
          revokedAt: null,
          expiresAt: { gt: acceptedAt },
        },
        data: {
          acceptedAt,
          inviteeUserId: currentUser.id,
        },
      });
      if (claimed.count !== 1) {
        throw new ConflictException("Invite is no longer pending");
      }

      const member = await tx.sharedMember.upsert({
        where: {
          weddingPlanId_userId: {
            weddingPlanId: invite.weddingPlanId,
            userId: currentUser.id,
          },
        },
        update: {},
        create: {
          weddingPlanId: invite.weddingPlanId,
          userId: currentUser.id,
          role: invite.role,
          canViewMoney: invite.canViewMoney,
          canEditPlan: invite.canEditPlan,
          canManageTasks: invite.canManageTasks,
          canManageGuests: invite.canManageGuests,
          canManageProviders: invite.canManageProviders,
          canInviteMembers: invite.canInviteMembers,
          canManageMoney: invite.canManageMoney,
          receiveNotifications: invite.receiveNotifications,
        },
        include: {
          user: {
            select: { id: true, phone: true, ...applicationNameFields },
          },
        },
      });
      await this.history.ensureTenureInTransaction(tx, member);
      await this.recordAcceptedInviteMemberForInviterInTransaction(
        tx,
        invite,
        member,
        acceptedAt,
      );
      if (member.canManageProviders) {
        await this.setProviderConversationParticipation(
          tx,
          invite.weddingPlanId,
          currentUser.id,
          true,
        );
      }

      const acceptedInvite = await tx.planInvite.findUnique({
        where: { id: invite.id },
        include: this.inviteIncludes(),
      });
      if (!acceptedInvite) {
        throw new ConflictException("Invite is no longer pending");
      }

      await this.notifications.createNotificationInTransaction(tx, {
        userId: invite.inviterUserId,
        weddingPlanId: invite.weddingPlanId,
        type: NotificationType.SHARING_INVITE_ACCEPTED,
        priority: NotificationPriority.HIGH,
        title: "تم قبول الدعوة",
        body: `${currentUser.name} قبل دعوة المشاركة في خطة الزفاف.`,
        entityType: "plan_invite",
        entityId: invite.id,
        routeTarget: `/wedding-plans/${invite.weddingPlanId}/sharing`,
        data: {
          inviteId: invite.id,
          sharedMemberId: member.id,
          weddingPlanId: invite.weddingPlanId,
        },
        dedupeKey: `${invite.inviterUserId}:plan-invite:${invite.id}:accepted`,
      });

      return { member, acceptedInvite };
    });

    return {
      invite: this.toInviteResponse(result.acceptedInvite),
      member: this.toMemberResponse(result.member),
      contextKey: canonicalPlanContextKey(
        result.acceptedInvite.weddingPlanId,
        "contributor",
      ),
    };
  }

  async declineInvite(
    currentUser: AuthenticatedUser,
    token: string,
  ): Promise<PlanInviteResponse> {
    const invite = await this.findInviteByTokenOrThrow(token);
    this.assertInviteBelongsToCurrentUser(invite, currentUser);

    const declinedAt = new Date();
    const declined = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const planSeed = await tx.weddingPlan.findUnique({
          where: { id: invite.weddingPlanId },
          select: { ownerUserId: true },
        });
        if (!planSeed) {
          throw new NotFoundException("Wedding plan not found");
        }
        const lifecycleUsers = await lockUserLifecycleRowsInTransaction(tx, [
          currentUser.id,
          invite.inviterUserId,
          planSeed.ownerUserId,
        ]);
        const actor = lifecycleUsers.find((user) => user.id === currentUser.id);
        if (
          !actor ||
          actor.status !== UserStatus.ACTIVE ||
          !lifecycleUsers.some((user) => user.id === invite.inviterUserId) ||
          !lifecycleUsers.some((user) => user.id === planSeed.ownerUserId)
        ) {
          throw new NotFoundException("Invite not found");
        }
        const lockedPlan = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
          SELECT "id"
          FROM "WeddingPlan"
          WHERE "id" = ${invite.weddingPlanId}
          FOR SHARE
        `,
        );
        if (lockedPlan.length !== 1) {
          throw new NotFoundException("Wedding plan not found");
        }
        const lockedPlanState = await tx.weddingPlan.findUnique({
          where: { id: invite.weddingPlanId },
          select: { ownerUserId: true },
        });
        if (
          !lockedPlanState ||
          lockedPlanState.ownerUserId !== planSeed.ownerUserId
        ) {
          throw new NotFoundException("Wedding plan not found");
        }
        const lockedInvite = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
          SELECT "id"
          FROM "PlanInvite"
          WHERE "id" = ${invite.id}
          FOR UPDATE
        `,
        );
        if (lockedInvite.length !== 1) {
          throw new ConflictException("Invite is no longer pending");
        }
        const currentInvite = await tx.planInvite.findUnique({
          where: { id: invite.id },
          include: this.inviteIncludes(),
        });
        if (!currentInvite) {
          throw new ConflictException("Invite is no longer pending");
        }
        if (
          currentInvite.declinedAt &&
          !currentInvite.acceptedAt &&
          !currentInvite.revokedAt &&
          currentUser.phoneVerifiedAt &&
          currentInvite.inviteeUserId === currentUser.id
        ) {
          const presentedTokenStillMatches =
            token === currentInvite.id ||
            currentInvite.tokenHash === this.hashInviteToken(token);
          if (!presentedTokenStillMatches) {
            throw new ConflictException("Invite is no longer pending");
          }
          return currentInvite;
        }
        this.assertInviteCanBeAccepted(currentInvite, currentUser);
        const claimed = await tx.planInvite.updateMany({
          where: {
            id: currentInvite.id,
            ...this.inviteClaimTokenFilter(currentInvite, token),
            acceptedAt: null,
            declinedAt: null,
            revokedAt: null,
            expiresAt: { gt: declinedAt },
          },
          data: {
            declinedAt,
            inviteeUserId: currentUser.id,
          },
        });
        if (claimed.count !== 1) {
          throw new ConflictException("Invite is no longer pending");
        }
        const updated = await tx.planInvite.findUnique({
          where: { id: currentInvite.id },
          include: this.inviteIncludes(),
        });
        if (!updated) {
          throw new ConflictException("Invite is no longer pending");
        }

        await this.notifications.createNotificationInTransaction(tx, {
          userId: currentInvite.inviterUserId,
          weddingPlanId: currentInvite.weddingPlanId,
          type: NotificationType.SHARING_INVITE_DECLINED,
          title: "تم رفض الدعوة",
          body: `${currentUser.name} رفض دعوة المشاركة في خطة الزفاف.`,
          entityType: "plan_invite",
          entityId: currentInvite.id,
          routeTarget: `/wedding-plans/${currentInvite.weddingPlanId}/sharing`,
          data: {
            inviteId: currentInvite.id,
            weddingPlanId: currentInvite.weddingPlanId,
          },
          dedupeKey: `${currentInvite.inviterUserId}:plan-invite:${currentInvite.id}:declined`,
        });
        return updated;
      },
    );

    return this.toInviteResponse(declined);
  }

  async updateMemberForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    memberId: string,
    dto: UpdateSharedMemberDto,
  ): Promise<SharedMemberResponse> {
    this.assertNotOwnerMemberId(memberId);
    const targetSeed = await this.prisma.sharedMember.findFirst({
      where: { id: memberId, weddingPlanId },
      select: { userId: true },
    });
    if (!targetSeed) {
      throw new NotFoundException("Shared member not found");
    }

    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const access = await this.permissions.assertMemberManageableInTransaction(
        tx,
        weddingPlanId,
        currentUser,
        [targetSeed.userId],
      );
      const targetLock = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "SharedMember"
          WHERE "id" = ${memberId}
            AND "weddingPlanId" = ${weddingPlanId}
          FOR UPDATE
        `,
      );
      if (targetLock.length !== 1) {
        throw new NotFoundException("Shared member not found");
      }
      const existing = await tx.sharedMember.findFirst({
        where: { id: memberId, weddingPlanId },
      });
      if (!existing || existing.userId !== targetSeed.userId) {
        throw new NotFoundException("Shared member not found");
      }
      await this.assertMemberWithinActorScopeInTransaction(
        tx,
        access,
        currentUser.id,
        existing.id,
      );
      this.assertPermissionCeiling(
        access,
        existing.role,
        this.permissionFlagsForRecord(existing),
      );
      const role = this.assignableRole(dto.role ?? existing.role);
      const permissionData = this.permissionDataForUpdate(existing, dto, role);
      this.assertPermissionCeiling(access, role, permissionData);
      const revokedPermissions = this.revokedPermissions(
        existing,
        permissionData,
      );
      const authorityNarrowed = revocationDescriptors.some(
        ({ key }) => existing[key] === true && permissionData[key] === false,
      );
      if (revokedPermissions.length > 0) {
        await this.recordRevocationBoundariesInTransaction(
          tx,
          existing,
          revokedPermissions,
        );
      }
      if (authorityNarrowed) {
        await this.revokePendingInvitesExceedingAuthorityInTransaction(
          tx,
          weddingPlanId,
          existing.userId,
          permissionData,
          new Date(),
        );
      }
      const hadFinancialAccess = this.permissions.canViewMoney({
        plan: access.plan,
        isOwner: false,
        sharedMember: existing,
      });
      const nextRecord = { ...existing, role, ...permissionData };
      const keepsFinancialAccess = this.permissions.canViewMoney({
        plan: access.plan,
        isOwner: false,
        sharedMember: nextRecord,
      });
      const hadProviderConversationAccess = existing.canManageProviders;
      const keepsProviderConversationAccess = nextRecord.canManageProviders;
      const gainsProviderConversationAccess =
        !hadProviderConversationAccess && keepsProviderConversationAccess;
      const authorityVersion = existing.authorityVersion ?? 1;
      const authorityChanged =
        role !== existing.role ||
        revocationDescriptors.some(
          ({ key }) => existing[key] !== permissionData[key],
        );
      const updated = await tx.sharedMember.update({
        where: { id: existing.id },
        data: {
          ...(dto.role !== undefined ? { role } : {}),
          ...permissionData,
          ...(authorityChanged
            ? { authorityVersion: authorityVersion + 1 }
            : {}),
        },
        include: {
          user: {
            select: { id: true, phone: true, ...applicationNameFields },
          },
        },
      });
      if (hadFinancialAccess && !keepsFinancialAccess) {
        await this.notifications.purgeMoneyForMember(
          tx,
          existing.userId,
          weddingPlanId,
        );
      }
      let revokedConversationIds: string[] = [];
      if (hadProviderConversationAccess && !keepsProviderConversationAccess) {
        revokedConversationIds =
          await this.setProviderConversationParticipation(
            tx,
            weddingPlanId,
            existing.userId,
            false,
          );
      } else if (gainsProviderConversationAccess) {
        await this.setProviderConversationParticipation(
          tx,
          weddingPlanId,
          existing.userId,
          true,
        );
      }
      await enqueueConversationAccessRevoked(
        tx,
        existing.userId,
        revokedConversationIds,
      );
      return {
        member: updated,
        affectedUserId: existing.userId,
        revokedConversationIds,
      };
    });

    if (result.revokedConversationIds.length > 0) {
      this.realtime?.revokeConversationAccess(
        result.affectedUserId,
        result.revokedConversationIds,
      );
    }

    return this.toMemberResponse(result.member);
  }

  async removeMemberFromPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    memberId: string,
  ): Promise<{ id: string; deleted: true }> {
    if (this.isOwnerMemberId(memberId)) {
      throw new BadRequestException("Last owner cannot be removed");
    }
    const targetSeed = await this.prisma.sharedMember.findFirst({
      where: { id: memberId, weddingPlanId },
      select: { userId: true },
    });
    if (!targetSeed) {
      throw new NotFoundException("Shared member not found");
    }

    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const access = await this.permissions.assertMemberManageableInTransaction(
        tx,
        weddingPlanId,
        currentUser,
        [targetSeed.userId],
      );
      if (memberId === access.plan.ownerUserId) {
        throw new BadRequestException("Last owner cannot be removed");
      }
      const targetUser = await tx.user.findUnique({
        where: { id: targetSeed.userId },
        select: { phone: true },
      });
      if (!targetUser) {
        throw new NotFoundException("Shared member not found");
      }
      const normalizedPhone = PhoneNormalizer.normalizeOptional(
        targetUser.phone,
      );
      const revokedAt = new Date();
      const targetInvitePredicate = normalizedPhone
        ? Prisma.sql`
            (
              "inviterUserId" = ${targetSeed.userId}
              OR "inviteeUserId" = ${targetSeed.userId}
              OR "normalizedPhone" = ${normalizedPhone}
            )
          `
        : Prisma.sql`(
            "inviterUserId" = ${targetSeed.userId}
            OR "inviteeUserId" = ${targetSeed.userId}
          )`;
      const pendingInviteLocks = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "PlanInvite"
          WHERE "weddingPlanId" = ${weddingPlanId}
            AND "acceptedAt" IS NULL
            AND "declinedAt" IS NULL
            AND "revokedAt" IS NULL
            AND "expiresAt" > ${revokedAt}
            AND ${targetInvitePredicate}
          ORDER BY "id"
          FOR UPDATE
        `,
      );
      const pendingInviteIds = pendingInviteLocks.map((invite) => invite.id);
      const targetLock = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "SharedMember"
          WHERE "id" = ${memberId}
            AND "weddingPlanId" = ${weddingPlanId}
          FOR UPDATE
        `,
      );
      if (targetLock.length !== 1) {
        throw new NotFoundException("Shared member not found");
      }
      const existing = await tx.sharedMember.findFirst({
        where: { id: memberId, weddingPlanId },
      });
      if (!existing || existing.userId !== targetSeed.userId) {
        throw new NotFoundException("Shared member not found");
      }
      await this.assertMemberWithinActorScopeInTransaction(
        tx,
        access,
        currentUser.id,
        existing.id,
      );
      this.assertPermissionCeiling(
        access,
        existing.role,
        this.permissionFlagsForRecord(existing),
      );
      if (pendingInviteIds.length > 0) {
        const revokedInvites = await tx.planInvite.updateMany({
          where: {
            id: { in: pendingInviteIds },
            weddingPlanId,
            acceptedAt: null,
            declinedAt: null,
            revokedAt: null,
            expiresAt: { gt: revokedAt },
            OR: [
              { inviterUserId: existing.userId },
              { inviteeUserId: existing.userId },
              ...(normalizedPhone ? [{ normalizedPhone }] : []),
            ],
          },
          data: { revokedAt },
        });
        if (revokedInvites.count !== pendingInviteIds.length) {
          throw new ConflictException(
            "Invitation state changed during removal",
          );
        }
      }
      const revokedPermissions = revocationDescriptors.filter(
        ({ key }) => existing[key] === true,
      );
      if (revokedPermissions.length > 0) {
        await this.recordRevocationBoundariesInTransaction(
          tx,
          existing,
          revokedPermissions,
        );
      }
      await this.recordMembershipEndInTransaction(
        tx,
        existing,
        ContributionAction.MEMBER_REMOVED,
      );
      await this.history.closeTenureInTransaction(tx, {
        weddingPlanId,
        actorUserId: existing.userId,
        reason: "MEMBER_REMOVED",
        roleAtEnd: existing.role,
        endedAt: revokedAt,
      });
      await tx.user.updateMany({
        where: {
          id: existing.userId,
          activeWeddingPlanId: weddingPlanId,
        },
        data: { activeWeddingPlanId: null },
      });
      await tx.sharedMember.delete({ where: { id: existing.id } });
      const revokedConversationIds =
        await this.setProviderConversationParticipation(
          tx,
          weddingPlanId,
          existing.userId,
          false,
        );
      await enqueueConversationAccessRevoked(
        tx,
        existing.userId,
        revokedConversationIds,
      );
      await this.notifications.purgeMoneyForMember(
        tx,
        existing.userId,
        weddingPlanId,
      );
      return {
        id: existing.id,
        affectedUserId: existing.userId,
        revokedConversationIds,
      };
    });
    if (result.revokedConversationIds.length > 0) {
      this.realtime?.revokeConversationAccess(
        result.affectedUserId,
        result.revokedConversationIds,
      );
    }
    return { id: result.id, deleted: true };
  }

  async leaveCurrentMemberFromPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    expectedMembership: LeavePlanDto,
  ): Promise<{
    weddingPlanId: string;
    deleted: true;
    alreadyLeft: boolean;
  }> {
    const planSeed = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      select: { ownerUserId: true },
    });
    if (!planSeed) throw new NotFoundException("Wedding plan not found");
    if (planSeed.ownerUserId === currentUser.id) {
      throw new HttpException(
        {
          statusCode: HttpStatus.FORBIDDEN,
          code: ownerCannotLeaveCode,
          message: ownerCannotLeaveMessage,
        },
        HttpStatus.FORBIDDEN,
      );
    }

    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const lockedUsers = await lockUserLifecycleRowsForUpdateInTransaction(
        tx,
        [currentUser.id],
      );
      if (lockedUsers.length !== 1) {
        throw new NotFoundException("Wedding plan not found");
      }
      const plan = await tx.weddingPlan.findUnique({
        where: { id: weddingPlanId },
        select: { ownerUserId: true },
      });
      if (!plan) throw new NotFoundException("Wedding plan not found");
      if (plan.ownerUserId === currentUser.id) {
        throw new HttpException(
          {
            statusCode: HttpStatus.FORBIDDEN,
            code: ownerCannotLeaveCode,
            message: ownerCannotLeaveMessage,
          },
          HttpStatus.FORBIDDEN,
        );
      }

      const targetLock = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "SharedMember"
          WHERE "weddingPlanId" = ${weddingPlanId}
            AND "userId" = ${currentUser.id}
          FOR UPDATE
        `,
      );
      const existing = await tx.sharedMember.findUnique({
        where: {
          weddingPlanId_userId: {
            weddingPlanId,
            userId: currentUser.id,
          },
        },
      });
      if (!existing) {
        if (targetLock.length > 0) {
          throw new ConflictException("Membership state changed during leave");
        }
        const wasAlreadyLeft = await this.wasPreviouslyLeftInTransaction(
          tx,
          weddingPlanId,
          currentUser.id,
        );
        if (!wasAlreadyLeft) {
          throw new NotFoundException("Wedding plan not found");
        }
        return {
          weddingPlanId,
          deleted: true as const,
          alreadyLeft: true,
          affectedUserId: currentUser.id,
          revokedConversationIds: [] as string[],
        };
      }
      if (targetLock.length !== 1) {
        throw new ConflictException("Membership state changed during leave");
      }
      if (
        existing.id !== expectedMembership.expectedMemberId ||
        existing.authorityVersion !==
          expectedMembership.expectedAuthorityVersion
      ) {
        throw new HttpException(
          {
            statusCode: HttpStatus.CONFLICT,
            code: "MEMBERSHIP_CHANGED_SINCE_LEAVE_REQUEST",
            message:
              "تغيّرت عضويتك في الخطة. حدّث المسارات ثم أعد محاولة المغادرة.",
          },
          HttpStatus.CONFLICT,
        );
      }

      const user = await tx.user.findUnique({
        where: { id: currentUser.id },
        select: { phone: true },
      });
      if (!user) throw new NotFoundException("Wedding plan not found");
      const leftAt = new Date();
      await this.revokePendingInvitesForUserInTransaction(
        tx,
        weddingPlanId,
        currentUser.id,
        user.phone,
        leftAt,
      );

      const revokedPermissions = revocationDescriptors.filter(
        ({ key }) => existing[key] === true,
      );
      if (revokedPermissions.length > 0) {
        await this.recordRevocationBoundariesInTransaction(
          tx,
          existing,
          revokedPermissions,
        );
      }
      await this.recordMembershipEndInTransaction(
        tx,
        existing,
        ContributionAction.MEMBER_LEFT,
      );
      await this.history.closeTenureInTransaction(tx, {
        weddingPlanId,
        actorUserId: currentUser.id,
        reason: "MEMBER_LEFT",
        roleAtEnd: existing.role,
        endedAt: leftAt,
      });
      await tx.user.updateMany({
        where: { id: currentUser.id, activeWeddingPlanId: weddingPlanId },
        data: { activeWeddingPlanId: null },
      });
      await tx.sharedMember.delete({ where: { id: existing.id } });
      const revokedConversationIds =
        await this.setProviderConversationParticipation(
          tx,
          weddingPlanId,
          currentUser.id,
          false,
        );
      await enqueueConversationAccessRevoked(
        tx,
        currentUser.id,
        revokedConversationIds,
      );
      await this.notifications.purgeMoneyForMember(
        tx,
        currentUser.id,
        weddingPlanId,
      );
      return {
        weddingPlanId,
        deleted: true as const,
        alreadyLeft: false,
        affectedUserId: currentUser.id,
        revokedConversationIds,
      };
    });

    if (result.revokedConversationIds.length > 0) {
      this.realtime?.revokeConversationAccess(
        result.affectedUserId,
        result.revokedConversationIds,
      );
    }
    return {
      weddingPlanId: result.weddingPlanId,
      deleted: true,
      alreadyLeft: result.alreadyLeft,
    };
  }

  async permissionsForCurrentUser(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<PermissionSummaryResponse> {
    const context = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    return this.toPermissionSummary(context, currentUser.id);
  }

  private async findMemberForPlanOrThrow(
    weddingPlanId: string,
    memberId: string,
  ): Promise<SharedMember> {
    const member = await this.prisma.sharedMember.findFirst({
      where: { id: memberId, weddingPlanId },
    });
    if (!member) {
      throw new NotFoundException("Shared member not found");
    }
    return member;
  }

  private async findPlanWithOwnerOrThrow(
    weddingPlanId: string,
  ): Promise<WeddingPlan & { owner: ApplicationContactRecord }> {
    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      include: {
        owner: {
          select: { id: true, phone: true, ...applicationNameFields },
        },
      },
    });
    if (!plan) {
      throw new NotFoundException("Wedding plan not found");
    }
    return plan;
  }

  private async findTargetUser(dto: CreateSharedMemberDto): Promise<User> {
    const userId = dto.userId?.trim();
    const phone = dto.phone
      ? PhoneNormalizer.normalizeRequired(dto.phone)
      : null;

    if (userId && phone) {
      throw new BadRequestException("Provide either userId or phone, not both");
    }

    if (!userId && !phone) {
      throw new BadRequestException("Provide either userId or phone");
    }

    let user: User | null;
    if (userId) {
      user = await this.prisma.user.findUnique({ where: { id: userId } });
    } else if (phone) {
      user = await this.prisma.user.findFirst({
        where: { phone: { in: PhoneNormalizer.lookupVariants(phone) } },
      });
    } else {
      user = null;
    }

    if (!user) {
      throw new BadRequestException(
        phone
          ? "No registered user found for this phone"
          : "userId must reference an existing user",
      );
    }

    return user;
  }

  private async findInviteTarget(dto: CreatePlanInviteDto): Promise<{
    user: User | null;
    phone: string | null;
    normalizedPhone: string | null;
    email: string | null;
  }> {
    const userId = this.optionalText(dto.userId);
    const phone = dto.phone
      ? PhoneNormalizer.normalizeRequired(dto.phone)
      : null;
    const email = this.optionalText(dto.email)?.toLowerCase() ?? null;

    const identifiers = [userId, phone, email].filter(Boolean);
    if (identifiers.length > 1) {
      throw new BadRequestException(
        "Provide only one of userId, phone, or email",
      );
    }

    if (identifiers.length === 0) {
      throw new BadRequestException("Provide userId, phone, or email");
    }

    if (email) {
      throw new BadRequestException(
        "Email invitations require verified email and are not available",
      );
    }

    if (userId) {
      const user = await this.prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        throw new BadRequestException("userId must reference an existing user");
      }
      const normalizedPhone = PhoneNormalizer.normalizeOptional(user.phone);
      return {
        user,
        phone: user.phone,
        normalizedPhone,
        email: null,
      };
    }

    const user = phone
      ? ((await this.prisma.user.findUnique({ where: { phone } })) ??
        (await this.prisma.user.findFirst({
          where: {
            phone: {
              in: PhoneNormalizer.lookupVariants(phone).filter(
                (candidate) => candidate !== phone,
              ),
            },
          },
        })))
      : null;
    return {
      user,
      phone: phone ?? user?.phone ?? null,
      normalizedPhone:
        phone ?? PhoneNormalizer.normalizeOptional(user?.phone) ?? null,
      email: null,
    };
  }

  private async withUniqueInviteToken(
    operation: (token: string) => Promise<PlanInviteWithRelations>,
  ): Promise<PresentedInvite> {
    for (let attempt = 0; attempt < 5; attempt++) {
      const token = randomBytes(32).toString("base64url");
      try {
        const invite = await operation(token);
        return { invite, token };
      } catch (error) {
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === "P2002"
        ) {
          continue;
        }
        throw error;
      }
    }

    throw new ConflictException("Could not create a unique invite token");
  }

  private deliveryAttemptFor(
    presented: PresentedInvite,
  ): InviteDeliveryAttempt {
    const attemptedAt = presented.invite.deliveryAttemptedAt;
    if (!attemptedAt) {
      throw new Error("Invite delivery attempt was not initialized");
    }
    return {
      inviteId: presented.invite.id,
      weddingPlanId: presented.invite.weddingPlanId,
      tokenHash: this.hashInviteToken(presented.token),
      attemptedAt,
    };
  }

  private async persistInviteDelivery(
    attempt: InviteDeliveryAttempt,
    delivery: InvitationDeliveryResult,
  ): Promise<PlanInviteWithRelations> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const finalizedAt = new Date();
      const stored = await tx.planInvite.updateMany({
        where: {
          id: attempt.inviteId,
          weddingPlanId: attempt.weddingPlanId,
          tokenHash: attempt.tokenHash,
          deliveryAttemptedAt: attempt.attemptedAt,
          deliveryStatus: PlanInviteDeliveryStatus.PENDING,
          acceptedAt: null,
          declinedAt: null,
          revokedAt: null,
          expiresAt: { gt: finalizedAt },
        },
        data: {
          deliveryStatus: this.toStoredDeliveryStatus(delivery.status),
        },
      });
      if (stored.count !== 1) {
        throw new HttpException(
          {
            statusCode: HttpStatus.CONFLICT,
            code: inviteDeliverySupersededCode,
            message: "Invite delivery attempt was superseded.",
          },
          HttpStatus.CONFLICT,
        );
      }

      const finalized = await tx.planInvite.findUnique({
        where: { id: attempt.inviteId },
        include: this.inviteIncludes(),
      });
      if (!finalized) {
        throw new NotFoundException("Invite not found");
      }
      return finalized;
    });
  }

  private async finalizeInviteDelivery(
    presented: PresentedInvite,
    delivery: InvitationDeliveryResult,
  ): Promise<{
    invite: PlanInviteWithRelations;
    attempt: InviteDeliveryAttempt;
  }> {
    const attempt = this.deliveryAttemptFor(presented);
    try {
      return {
        invite: await this.persistInviteDelivery(attempt, delivery),
        attempt,
      };
    } catch (error) {
      if (error instanceof HttpException || !isPrismaPersistenceError(error)) {
        throw error;
      }

      invitationDeliveryPersistenceFailuresTotal.inc();
      this.logger.error({
        event: "invitation_delivery_persistence_failed",
      });
      return { invite: presented.invite, attempt };
    }
  }

  private toStoredDeliveryStatus(
    status: InvitationDeliveryResult["status"],
  ): PlanInviteDeliveryStatus {
    switch (status) {
      case "DELIVERED":
        return PlanInviteDeliveryStatus.DELIVERED;
      case "UNCERTAIN":
        return PlanInviteDeliveryStatus.UNCERTAIN;
      case "UNAVAILABLE":
        return PlanInviteDeliveryStatus.UNAVAILABLE;
    }
  }

  private assertInviteReissueCooldownElapsed(
    attemptedAt: Date | null,
    now: Date,
  ): void {
    const retryAfterSeconds = this.inviteRetryAfterSeconds(attemptedAt, now);
    if (retryAfterSeconds === 0) return;

    throw new HttpException(
      {
        statusCode: HttpStatus.TOO_MANY_REQUESTS,
        code: inviteReissueCooldownCode,
        message: "Invite delivery was attempted recently. Try again later.",
        retryAfterSeconds,
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }

  private inviteRetryAfterSeconds(
    attemptedAt: Date | null,
    now = new Date(),
  ): number {
    if (!attemptedAt) return 0;
    const remainingMs =
      attemptedAt.getTime() + inviteReissueCooldownMs - now.getTime();
    return remainingMs > 0 ? Math.ceil(remainingMs / 1000) : 0;
  }

  private async findInviteByTokenOrThrow(
    token: string,
  ): Promise<PlanInviteWithRelations> {
    const inviteByHash = await this.prisma.planInvite.findUnique({
      where: { tokenHash: this.hashInviteToken(token) },
      include: this.inviteIncludes(),
    });
    const invite =
      inviteByHash ??
      (await this.prisma.planInvite.findUnique({
        where: { id: token },
        include: this.inviteIncludes(),
      }));
    if (!invite) {
      throw new NotFoundException("Invite not found");
    }
    return invite;
  }

  private hashInviteToken(token: string): string {
    return createHash("sha256").update(token).digest("hex");
  }

  private inviteClaimTokenFilter(
    invite: PlanInviteWithRelations,
    presentedToken: string,
  ): { tokenHash?: string } {
    // Authenticated in-app notifications intentionally use the invite id as an
    // identity-checked action handle. A raw external bearer, however, must
    // still match the live fingerprint so reissue invalidates an in-flight old
    // link before it can claim the invitation.
    return presentedToken === invite.id
      ? {}
      : { tokenHash: this.hashInviteToken(presentedToken) };
  }

  private inviteIncludes() {
    return {
      weddingPlan: {
        select: {
          id: true,
          title: true,
          city: true,
          weddingDate: true,
          status: true,
        },
      },
      inviter: {
        select: { id: true, phone: true, ...applicationNameFields },
      },
      invitee: {
        select: { id: true, phone: true, ...applicationNameFields },
      },
    } satisfies Prisma.PlanInviteInclude;
  }

  private assertInviteCanBeAccepted(
    invite: PlanInvite,
    currentUser: AuthenticatedUser,
  ): void {
    if (!currentUser.phoneVerifiedAt) {
      throw new NotFoundException("Invite not found");
    }
    if (invite.email && !invite.inviteeUserId && !invite.normalizedPhone) {
      throw new NotFoundException("Invite not found");
    }
    if (invite.inviteeUserId && invite.inviteeUserId !== currentUser.id) {
      throw new NotFoundException("Invite not found");
    }
    if (
      invite.phone &&
      !PhoneNormalizer.areEquivalent(currentUser.phone, invite.phone)
    ) {
      throw new NotFoundException("Invite not found");
    }
    if (invite.revokedAt) {
      throw new BadRequestException("Invite has been revoked");
    }
    if (invite.acceptedAt) {
      throw new ConflictException("Invite has already been accepted");
    }
    if (invite.declinedAt) {
      throw new ConflictException("Invite has already been declined");
    }
    if (invite.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException("Invite has expired");
    }
  }

  private assertInviteBelongsToCurrentUser(
    invite: PlanInvite,
    currentUser: AuthenticatedUser,
  ): void {
    if (!currentUser.phoneVerifiedAt) {
      throw new NotFoundException("Invite not found");
    }
    if (invite.email && !invite.inviteeUserId && !invite.normalizedPhone) {
      throw new NotFoundException("Invite not found");
    }
    if (invite.inviteeUserId) {
      if (invite.inviteeUserId === currentUser.id) {
        return;
      }
      throw new NotFoundException("Invite not found");
    }
    if (
      invite.phone &&
      PhoneNormalizer.areEquivalent(currentUser.phone, invite.phone)
    ) {
      return;
    }
    throw new NotFoundException("Invite not found");
  }

  private async contributedEntityIds(
    weddingPlanId: string,
    actorUserId: string,
    entityType: ContributionEntityType,
    action: ContributionAction,
  ): Promise<string[]> {
    const events = await this.prisma.contributionEvent.findMany({
      where: {
        historyScope: { weddingPlanId },
        contributorTenure: { actorUserId },
        entityType,
        action,
        entityId: { not: null },
      },
      select: { entityId: true },
      distinct: ["entityId"],
    });
    return events.flatMap(({ entityId }) => (entityId ? [entityId] : []));
  }

  private revokedPermissions(
    existing: StoredPermissionRecord,
    next: PermissionFlags,
  ): RevocationDescriptor[] {
    const revoked = revocationDescriptors.filter(
      ({ key, section }) =>
        section !== ContributionSection.MONEY &&
        existing[key] === true &&
        next[key] === false,
    );
    const hadMoneyAccess = existing.canViewMoney || existing.canManageMoney;
    const keepsMoneyAccess = next.canViewMoney || next.canManageMoney;
    if (hadMoneyAccess && !keepsMoneyAccess) {
      const moneyReadDescriptor = revocationDescriptors.find(
        ({ permission }) => permission === ContributionPermission.VIEW_MONEY,
      );
      if (!moneyReadDescriptor) {
        throw new Error("Money read revocation descriptor is missing");
      }
      revoked.push(moneyReadDescriptor);
    }
    return revoked;
  }

  private async assertMemberWithinActorScopeInTransaction(
    tx: Prisma.TransactionClient,
    access: PlanAccessContext,
    actorUserId: string,
    targetMemberId: string,
  ): Promise<void> {
    if (access.isOwner) return;
    const createdByActor = await tx.contributionEvent.findFirst({
      where: {
        historyScope: { weddingPlanId: access.plan.id },
        contributorTenure: { actorUserId },
        section: ContributionSection.MEMBERS,
        entityType: ContributionEntityType.MEMBER_ITEM,
        entityId: targetMemberId,
        action: ContributionAction.CREATED,
      },
      select: { id: true },
    });
    if (!createdByActor) throw new NotFoundException("Shared member not found");
  }

  private async recordRevocationBoundariesInTransaction(
    tx: Prisma.TransactionClient,
    member: SharedMember,
    revokedPermissions: readonly RevocationDescriptor[],
  ): Promise<void> {
    if (revokedPermissions.length === 0) return;
    await this.history.ensureTenureInTransaction(tx, member);
    const authorityVersion = member.authorityVersion ?? 1;
    const capturedAt = new Date();

    for (const descriptor of revokedPermissions) {
      await this.history.recordInTransaction(tx, {
        weddingPlanId: member.weddingPlanId,
        actorUserId: member.userId,
        section: descriptor.section,
        entityType: ContributionEntityType.SECTION,
        action: ContributionAction.SECTION_REVOKED,
        snapshot: buildContributionSnapshot(ContributionEntityType.SECTION, {
          status: "REVOKED",
        }),
        dedupeKey: [
          "revoke",
          member.id,
          authorityVersion,
          descriptor.permission,
          "section",
        ].join(":"),
        provenance: ContributionProvenance.REVOCATION_SNAPSHOT,
        requiredPermission: descriptor.permission,
        authorityVersion,
        occurredAt: capturedAt,
      });
    }
  }

  private async recordMembershipEndInTransaction(
    tx: Prisma.TransactionClient,
    member: SharedMember,
    action:
      | typeof ContributionAction.MEMBER_LEFT
      | typeof ContributionAction.MEMBER_REMOVED,
  ): Promise<void> {
    await this.history.ensureTenureInTransaction(tx, member);
    await this.history.recordInTransaction(tx, {
      weddingPlanId: member.weddingPlanId,
      actorUserId: member.userId,
      section: ContributionSection.MEMBERS,
      entityType: ContributionEntityType.MEMBER_ITEM,
      entityId: member.id,
      action,
      snapshot: buildContributionSnapshot(ContributionEntityType.MEMBER_ITEM, {
        role: member.role,
        permissionLabels: this.permissionLabels(member),
      }),
      dedupeKey: `membership-end:${member.id}:${action}`,
      provenance: ContributionProvenance.RUNTIME,
      authorityVersion: member.authorityVersion ?? 1,
      occurredAt: new Date(),
    });
  }

  private async recordAcceptedInviteMemberForInviterInTransaction(
    tx: Prisma.TransactionClient,
    invite: PlanInvite,
    member: SharedMember & { user?: ApplicationContactRecord },
    occurredAt: Date,
  ): Promise<void> {
    const inviterMember = await tx.sharedMember.findUnique({
      where: {
        weddingPlanId_userId: {
          weddingPlanId: invite.weddingPlanId,
          userId: invite.inviterUserId,
        },
      },
    });
    if (!inviterMember) return;
    await this.history.ensureTenureInTransaction(tx, inviterMember);
    await this.history.recordInTransaction(tx, {
      weddingPlanId: invite.weddingPlanId,
      actorUserId: invite.inviterUserId,
      section: ContributionSection.MEMBERS,
      entityType: ContributionEntityType.MEMBER_ITEM,
      entityId: member.id,
      action: ContributionAction.CREATED,
      snapshot: buildContributionSnapshot(ContributionEntityType.MEMBER_ITEM, {
        displayName: member.user
          ? applicationDisplayName(member.user)
          : invite.name,
        role: member.role,
        permissionLabels: this.permissionLabels(member),
      }),
      dedupeKey: `invite-accepted-member:${invite.id}:${member.id}`,
      provenance: ContributionProvenance.RUNTIME,
      requiredPermission: ContributionPermission.MANAGE_MEMBERS,
      authorityVersion: inviterMember.authorityVersion ?? 1,
      occurredAt,
    });
  }

  private permissionLabels(
    record: Pick<
      SharedMember | PlanInvite,
      | "canViewMoney"
      | "canEditPlan"
      | "canManageTasks"
      | "canManageGuests"
      | "canManageProviders"
      | "canInviteMembers"
      | "canManageMoney"
    >,
  ): string[] {
    return revocationDescriptors
      .filter(({ key }) => record[key] === true)
      .map(({ permission }) => permission);
  }

  private async wasPreviouslyLeftInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    actorUserId: string,
  ): Promise<boolean> {
    const scope = await tx.contributorHistoryScope.findUnique({
      where: { weddingPlanId },
      select: { id: true },
    });
    if (!scope) return false;
    const previousLeave = await tx.contributorTenure.findFirst({
      where: {
        historyScopeId: scope.id,
        actorUserId,
        endedAt: { not: null },
        endReason: "MEMBER_LEFT",
      },
      select: { id: true },
    });
    return previousLeave !== null;
  }

  private async lockDelegatedInviteAuthorityInTransaction(
    tx: Prisma.TransactionClient,
    invite: Pick<PlanInvite, "weddingPlanId" | "inviterUserId">,
    plan: WeddingPlan,
  ): Promise<SharedMember | null> {
    if (invite.inviterUserId === plan.ownerUserId) return null;

    const locks = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" = ${invite.weddingPlanId}
          AND "userId" = ${invite.inviterUserId}
        FOR SHARE
      `,
    );
    if (locks.length !== 1) return null;

    return tx.sharedMember.findUnique({
      where: {
        weddingPlanId_userId: {
          weddingPlanId: invite.weddingPlanId,
          userId: invite.inviterUserId,
        },
      },
    });
  }

  private assertPendingInviteAuthority(
    invite: PlanInvite,
    plan: WeddingPlan,
    delegatedInviterMember: SharedMember | null,
  ): void {
    if (invite.inviterUserId === plan.ownerUserId) return;
    if (
      !delegatedInviterMember ||
      delegatedInviterMember.weddingPlanId !== invite.weddingPlanId ||
      delegatedInviterMember.userId !== invite.inviterUserId
    ) {
      throw this.inviteAuthorityRevoked();
    }

    const inviterContext: PlanAccessContext = {
      plan,
      isOwner: false,
      sharedMember: delegatedInviterMember,
    };
    if (!this.permissions.canManageMembers(inviterContext)) {
      throw this.inviteAuthorityRevoked();
    }
    try {
      this.assertPermissionCeiling(
        inviterContext,
        invite.role,
        this.permissionFlagsForRecord(invite),
      );
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw this.inviteAuthorityRevoked();
      }
      throw error;
    }
  }

  private inviteAuthorityRevoked(): HttpException {
    return new HttpException(
      {
        statusCode: HttpStatus.CONFLICT,
        code: inviteAuthorityRevokedCode,
        message: inviteAuthorityRevokedMessage,
      },
      HttpStatus.CONFLICT,
    );
  }

  private inviteAuthorityInactive(): HttpException {
    return new HttpException(
      {
        statusCode: HttpStatus.CONFLICT,
        code: inviteAuthorityInactiveCode,
        message: inviteAuthorityInactiveMessage,
      },
      HttpStatus.CONFLICT,
    );
  }

  private async revokePendingInvitesForUserInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
    rawPhone: string | null,
    revokedAt: Date,
  ): Promise<void> {
    const normalizedPhone = PhoneNormalizer.normalizeOptional(rawPhone);
    const targetPredicate = normalizedPhone
      ? Prisma.sql`(
          "inviterUserId" = ${userId}
          OR "inviteeUserId" = ${userId}
          OR "normalizedPhone" = ${normalizedPhone}
        )`
      : Prisma.sql`(
          "inviterUserId" = ${userId}
          OR "inviteeUserId" = ${userId}
        )`;
    const locks = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "PlanInvite"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "acceptedAt" IS NULL
          AND "declinedAt" IS NULL
          AND "revokedAt" IS NULL
          AND "expiresAt" > ${revokedAt}
          AND ${targetPredicate}
        ORDER BY "id"
        FOR UPDATE
      `,
    );
    const ids = locks.map(({ id }) => id);
    if (ids.length === 0) return;
    const revoked = await tx.planInvite.updateMany({
      where: {
        id: { in: ids },
        weddingPlanId,
        acceptedAt: null,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: revokedAt },
        OR: [
          { inviterUserId: userId },
          { inviteeUserId: userId },
          ...(normalizedPhone ? [{ normalizedPhone }] : []),
        ],
      },
      data: { revokedAt },
    });
    if (revoked.count !== ids.length) {
      throw new ConflictException("Invitation state changed during leave");
    }
  }

  private async revokePendingInvitesExceedingAuthorityInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    inviterUserId: string,
    nextAuthority: PermissionFlags,
    revokedAt: Date,
  ): Promise<void> {
    const pendingInvites = await tx.$queryRaw<
      Array<
        Pick<
          PlanInvite,
          | "id"
          | "canViewMoney"
          | "canEditPlan"
          | "canManageTasks"
          | "canManageGuests"
          | "canManageProviders"
          | "canInviteMembers"
          | "canManageMoney"
        >
      >
    >(
      Prisma.sql`
        SELECT
          "id",
          "canViewMoney",
          "canEditPlan",
          "canManageTasks",
          "canManageGuests",
          "canManageProviders",
          "canInviteMembers",
          "canManageMoney"
        FROM "PlanInvite"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "inviterUserId" = ${inviterUserId}
          AND "acceptedAt" IS NULL
          AND "declinedAt" IS NULL
          AND "revokedAt" IS NULL
          AND "expiresAt" > ${revokedAt}
        ORDER BY "id"
        FOR UPDATE
      `,
    );
    const inviteIds = pendingInvites
      .filter((invite) => {
        if (!nextAuthority.canInviteMembers) return true;
        return revocationDescriptors.some(
          ({ key }) => invite[key] === true && nextAuthority[key] === false,
        );
      })
      .map(({ id }) => id);
    if (inviteIds.length === 0) return;

    const revoked = await tx.planInvite.updateMany({
      where: {
        id: { in: inviteIds },
        weddingPlanId,
        inviterUserId,
        acceptedAt: null,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: revokedAt },
      },
      data: { revokedAt },
    });
    if (revoked.count !== inviteIds.length) {
      throw new ConflictException(
        "Invitation state changed during authority revocation",
      );
    }
  }

  private async setProviderConversationParticipation(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
    active: boolean,
  ): Promise<string[]> {
    const conversations = await tx.conversation.findMany({
      where: { weddingPlanId },
      select: {
        id: true,
        provider: { select: { userId: true } },
        weddingPlan: { select: { ownerUserId: true } },
      },
    });
    const conversationIds = conversations
      .filter(
        (conversation) =>
          active ||
          (conversation.provider.userId !== userId &&
            conversation.weddingPlan?.ownerUserId !== userId),
      )
      .map((conversation) => conversation.id);
    if (conversationIds.length === 0) return [];

    if (active) {
      await tx.conversationParticipant.updateMany({
        where: {
          userId,
          conversationId: { in: conversationIds },
        },
        data: { revokedAt: null },
      });
      await tx.conversationParticipant.createMany({
        data: conversationIds.map((conversationId) => ({
          conversationId,
          userId,
        })),
        skipDuplicates: true,
      });
    } else {
      await tx.conversationParticipant.updateMany({
        where: {
          userId,
          conversationId: { in: conversationIds },
          revokedAt: null,
        },
        data: { revokedAt: new Date() },
      });
    }
    return conversationIds;
  }

  private assignableRole(role: SharedMemberRole): SharedMemberRole {
    if (role === SharedMemberRole.OWNER) {
      throw new BadRequestException(
        "OWNER is reserved for the wedding plan owner",
      );
    }
    return role;
  }

  private permissionDataForCreate(
    role: SharedMemberRole,
    dto: CreateSharedMemberDto | CreatePlanInviteDto,
  ): PermissionFlags {
    const defaults = rolePermissionDefaults(role);
    const canManageMoney = dto.canManageMoney ?? defaults.canManageMoney;
    return {
      canViewMoney:
        canManageMoney || (dto.canViewMoney ?? defaults.canViewMoney),
      canEditPlan: dto.canEditPlan ?? defaults.canEditPlan,
      canManageTasks: dto.canManageTasks ?? defaults.canManageTasks,
      canManageGuests: dto.canManageGuests ?? defaults.canManageGuests,
      canManageProviders: dto.canManageProviders ?? defaults.canManageProviders,
      canInviteMembers: dto.canInviteMembers ?? defaults.canInviteMembers,
      canManageMoney,
      receiveNotifications:
        dto.receiveNotifications ?? defaults.receiveNotifications,
    };
  }

  private permissionDataForDirectMemberCreate(
    dto: CreateSharedMemberDto,
  ): PermissionFlags {
    const canManageMoney = dto.canManageMoney ?? false;
    return {
      canViewMoney: canManageMoney || (dto.canViewMoney ?? false),
      canEditPlan: dto.canEditPlan ?? false,
      canManageTasks: dto.canManageTasks ?? false,
      canManageGuests: dto.canManageGuests ?? false,
      canManageProviders: dto.canManageProviders ?? false,
      canInviteMembers: dto.canInviteMembers ?? false,
      canManageMoney,
      receiveNotifications: dto.receiveNotifications ?? true,
    };
  }

  private permissionDataForUpdate(
    existing: StoredPermissionRecord,
    dto: UpdateSharedMemberDto,
    _role: SharedMemberRole,
  ): PermissionFlags {
    const canManageMoney = dto.canManageMoney ?? existing.canManageMoney;
    return {
      canViewMoney:
        canManageMoney || (dto.canViewMoney ?? existing.canViewMoney),
      canEditPlan: dto.canEditPlan ?? existing.canEditPlan,
      canManageTasks: dto.canManageTasks ?? existing.canManageTasks,
      canManageGuests: dto.canManageGuests ?? existing.canManageGuests,
      canManageProviders: dto.canManageProviders ?? existing.canManageProviders,
      canInviteMembers: dto.canInviteMembers ?? existing.canInviteMembers,
      canManageMoney,
      receiveNotifications:
        dto.receiveNotifications ?? existing.receiveNotifications,
    };
  }

  private assertPermissionCeiling(
    inviterContext: PlanAccessContext,
    targetRole: SharedMemberRole,
    targetStoredPermissions: PermissionFlags,
  ): void {
    if (inviterContext.isOwner) return;

    const ceiling = this.effectivePermissions(inviterContext);
    const targetContext: PlanAccessContext = {
      plan: inviterContext.plan,
      isOwner: false,
      sharedMember: {
        role: targetRole,
        ...targetStoredPermissions,
      } as SharedMember,
    };
    const target = this.effectivePermissions(targetContext);
    const guarded: Array<keyof PermissionFlags> = [
      "canViewMoney",
      "canEditPlan",
      "canManageTasks",
      "canManageGuests",
      "canManageProviders",
      "canInviteMembers",
      "canManageMoney",
    ];

    const exceeded = guarded.find((permission) => {
      return target[permission] && !ceiling[permission];
    });
    if (exceeded) {
      throw new BadRequestException(
        `Cannot grant permission above inviter ceiling: ${exceeded}`,
      );
    }
  }

  private permissionFlagsForRecord(
    record: Pick<
      SharedMember | PlanInvite,
      | "canViewMoney"
      | "canEditPlan"
      | "canManageTasks"
      | "canManageGuests"
      | "canManageProviders"
      | "canInviteMembers"
      | "canManageMoney"
      | "receiveNotifications"
    >,
  ): PermissionFlags {
    return {
      canViewMoney: record.canViewMoney,
      canEditPlan: record.canEditPlan,
      canManageTasks: record.canManageTasks,
      canManageGuests: record.canManageGuests,
      canManageProviders: record.canManageProviders,
      canInviteMembers: record.canInviteMembers,
      canManageMoney: record.canManageMoney,
      receiveNotifications: record.receiveNotifications,
    };
  }

  private effectivePermissions(context: PlanAccessContext): PermissionFlags {
    return {
      canViewMoney: this.permissions.canViewMoney(context),
      canEditPlan: this.permissions.canManagePlan(context),
      canManageTasks: this.permissions.canManageTasks(context),
      canManageGuests: this.permissions.canManageGuests(context),
      canManageProviders: this.permissions.canManageProviders(context),
      canInviteMembers: this.permissions.canManageMembers(context),
      canManageMoney: this.permissions.canManageMoney(context),
      receiveNotifications: true,
    };
  }

  private expiresAt(expiresInDays?: number): Date {
    const days = expiresInDays ?? 14;
    return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  }

  private optionalText(value: string | null | undefined): string | null {
    const trimmed = value?.trim() ?? "";
    return trimmed || null;
  }

  private isOwnerMemberId(memberId: string): boolean {
    return memberId.startsWith("owner:");
  }

  private assertNotOwnerMemberId(memberId: string): void {
    if (this.isOwnerMemberId(memberId)) {
      throw new BadRequestException("Owner member cannot be edited");
    }
  }

  private toMemberResponse(
    member: SharedMember & { user?: ApplicationContactRecord },
  ): SharedMemberResponse {
    return {
      id: member.id,
      weddingPlanId: member.weddingPlanId,
      userId: member.userId,
      ...(member.user ? { user: toApplicationUserContact(member.user) } : {}),
      role: member.role,
      canViewMoney: member.canViewMoney,
      canEditPlan: member.canEditPlan,
      canManageTasks: member.canManageTasks,
      canManageGuests: member.canManageGuests,
      canManageProviders: member.canManageProviders,
      canInviteMembers: member.canInviteMembers,
      canManageMoney: member.canManageMoney,
      receiveNotifications: member.receiveNotifications,
      createdAt: member.createdAt,
      updatedAt: member.updatedAt,
    };
  }

  private toPlanMemberResponse(
    member: SharedMember & { user?: ApplicationContactRecord },
  ): PlanMemberResponse {
    return {
      ...this.toMemberResponse(member),
      isOwner: false,
    };
  }

  private toOwnerMemberResponse(
    plan: WeddingPlan & { owner: ApplicationContactRecord },
  ): PlanMemberResponse {
    return {
      id: `owner:${plan.ownerUserId}`,
      weddingPlanId: plan.id,
      userId: plan.ownerUserId,
      user: toApplicationUserContact(plan.owner),
      role: SharedMemberRole.OWNER,
      canViewMoney: true,
      canEditPlan: true,
      canManageTasks: true,
      canManageGuests: true,
      canManageProviders: true,
      canInviteMembers: true,
      canManageMoney: true,
      receiveNotifications: true,
      isOwner: true,
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
    };
  }

  private toSharedPlanResponse(
    plan: WeddingPlan,
    member: SharedMember,
  ): SharedWeddingPlanResponse {
    return {
      id: plan.id,
      title: plan.title,
      city: plan.city,
      weddingDate: plan.weddingDate,
      currency: plan.currency,
      status: plan.status,
      sharedMember: this.toMemberResponse(member),
    };
  }

  private toInviteResponse(
    invite: PlanInviteWithRelations,
    presentedToken?: string,
  ): PlanInviteResponse {
    const status = this.inviteStatus(invite);
    return {
      id: invite.id,
      weddingPlanId: invite.weddingPlanId,
      token:
        presentedToken && status === "PENDING" ? presentedToken : invite.id,
      name: invite.name,
      phone: invite.phone,
      normalizedPhone: invite.normalizedPhone,
      email: invite.email,
      inviteeUserId: invite.inviteeUserId,
      inviterUserId: invite.inviterUserId,
      role: invite.role,
      canViewMoney: invite.canViewMoney,
      canEditPlan: invite.canEditPlan,
      canManageTasks: invite.canManageTasks,
      canManageGuests: invite.canManageGuests,
      canManageProviders: invite.canManageProviders,
      canInviteMembers: invite.canInviteMembers,
      canManageMoney: invite.canManageMoney,
      receiveNotifications: invite.receiveNotifications,
      status,
      expiresAt: invite.expiresAt,
      acceptedAt: invite.acceptedAt,
      declinedAt: invite.declinedAt,
      revokedAt: invite.revokedAt,
      createdAt: invite.createdAt,
      updatedAt: invite.updatedAt,
      delivery: {
        channel: "WHATSAPP",
        status: invite.deliveryStatus,
        attemptedAt: invite.deliveryAttemptedAt,
        retryAfterSeconds: this.inviteRetryAfterSeconds(
          invite.deliveryAttemptedAt,
        ),
      },
      ...(invite.weddingPlan ? { weddingPlan: invite.weddingPlan } : {}),
      ...(invite.inviter
        ? { inviter: toApplicationUserContact(invite.inviter) }
        : {}),
      ...(invite.invitee !== undefined
        ? {
            invitee: invite.invitee
              ? toApplicationUserContact(invite.invitee)
              : null,
          }
        : {}),
    };
  }

  private toCurrentUserInviteResponse(
    invite: PlanInviteWithRelations,
    currentUserId: string,
    hasLiveMembership: boolean,
  ): PlanInviteResponse {
    const response = this.toInviteResponse(invite);
    if (
      response.status !== "ACCEPTED" ||
      invite.inviteeUserId !== currentUserId ||
      !hasLiveMembership
    ) {
      return response;
    }
    return {
      ...response,
      contextKey: canonicalPlanContextKey(invite.weddingPlanId, "contributor"),
    };
  }

  private inviteStatus(
    invite: Pick<
      PlanInvite,
      "acceptedAt" | "declinedAt" | "revokedAt" | "expiresAt"
    >,
  ): PlanInviteResponse["status"] {
    if (invite.revokedAt) return "CANCELLED";
    if (invite.declinedAt) return "DECLINED";
    if (invite.acceptedAt) return "ACCEPTED";
    if (invite.expiresAt.getTime() < Date.now()) return "EXPIRED";
    return "PENDING";
  }

  private toPermissionSummary(
    context: PlanAccessContext,
    userId: string,
  ): PermissionSummaryResponse {
    return {
      weddingPlanId: context.plan.id,
      userId,
      isOwner: context.isOwner,
      role: context.isOwner
        ? SharedMemberRole.OWNER
        : (context.sharedMember?.role ?? null),
      canViewMoney: this.permissions.canViewMoney(context),
      canManageTasks: this.permissions.canManageTasks(context),
      canManageGuests: this.permissions.canManageGuests(context),
      canManageProviders: this.permissions.canManageProviders(context),
      canManageMoney: this.permissions.canManageMoney(context),
      canManagePlan: this.permissions.canManagePlan(context),
      canManageMembers: this.permissions.canManageMembers(context),
      receiveNotifications:
        context.isOwner || context.sharedMember?.receiveNotifications === true,
    };
  }
}

function isPrismaPersistenceError(error: unknown): boolean {
  if (
    error instanceof Prisma.PrismaClientUnknownRequestError ||
    error instanceof Prisma.PrismaClientRustPanicError ||
    error instanceof Prisma.PrismaClientInitializationError
  ) {
    return true;
  }
  if (!(error instanceof Prisma.PrismaClientKnownRequestError)) return false;
  if (["P2024", "P2028", "P2034"].includes(error.code)) return true;
  if (error.code !== "P2010") return false;

  const databaseCode = String(
    (error.meta as Record<string, unknown> | undefined)?.code ?? "",
  );
  return [
    "40001",
    "40P01",
    "08000",
    "08001",
    "08003",
    "08004",
    "08006",
    "08007",
    "08P01",
    "57P01",
    "57P02",
    "57P03",
  ].includes(databaseCode);
}
