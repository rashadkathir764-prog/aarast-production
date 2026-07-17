import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  NotificationPriority,
  NotificationType,
  PlanInvite,
  Prisma,
  SharedMember,
  SharedMemberRole,
  User,
  WeddingPlan,
} from "@prisma/client";
import { createHash, randomBytes } from "crypto";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
import { NotificationsService } from "../notifications/notifications.service";
import { PrismaService } from "../prisma/prisma.service";
import {
  ApplicationNameSource,
  applicationDisplayName,
  applicationNameFields,
  toApplicationUserContact,
} from "../users/application-user-identity";
import { CreatePlanInviteDto } from "./dto/create-plan-invite.dto";
import { CreateSharedMemberDto } from "./dto/create-shared-member.dto";
import { UpdateSharedMemberDto } from "./dto/update-shared-member.dto";
import {
  InvitationDeliveryResult,
  InvitationDeliveryService,
} from "./invitation-delivery.service";
import { PermissionService, PlanAccessContext } from "./permission.service";
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
  delivery?: InvitationDeliveryResult;
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

interface PresentedInvite {
  invite: PlanInviteWithRelations;
  token: string;
}

@Injectable()
export class SharingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
    private readonly notifications: NotificationsService,
    private readonly invitationDelivery: InvitationDeliveryService,
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
    const permissionData = this.permissionDataForCreate(role, dto);
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

    const member = await this.prisma.sharedMember.create({
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

    await this.notifications.createNotification({
      userId,
      weddingPlanId,
      type: NotificationType.SHARING_INVITATION,
      priority: NotificationPriority.HIGH,
      title: "تمت إضافتك إلى خطة زفاف",
      body: `أصبحت مشاركًا في "${plan.title}" بدور ${member.role}.`,
      entityType: "shared_member",
      entityId: member.id,
      routeTarget: `/wedding-plans/${weddingPlanId}/plan-center`,
      data: {
        sharedMemberId: member.id,
        weddingPlanId,
        role: member.role,
      },
      dedupeKey: `${userId}:sharing:${member.id}:invitation`,
    });

    return this.toMemberResponse(member);
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<SharedMemberResponse[]> {
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);

    const members = await this.prisma.sharedMember.findMany({
      where: { weddingPlanId },
      include: {
        user: {
          select: { id: true, phone: true, ...applicationNameFields },
        },
      },
      orderBy: { createdAt: "asc" },
    });

    return members.map((member) => this.toMemberResponse(member));
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateSharedMemberDto,
  ): Promise<SharedMemberResponse> {
    const existing = await this.findMemberOrThrow(id);
    const access = await this.permissions.assertMemberManageable(
      existing.weddingPlanId,
      currentUser,
    );
    this.assertPermissionCeiling(
      access,
      existing.role,
      this.permissionFlagsForRecord(existing),
    );
    const role = this.assignableRole(dto.role ?? existing.role);
    const permissionData = this.permissionDataForUpdate(existing, dto, role);
    this.assertPermissionCeiling(access, role, permissionData);

    const member = await this.prisma.sharedMember.update({
      where: { id },
      data: {
        ...(dto.role !== undefined ? { role } : {}),
        ...permissionData,
      },
      include: {
        user: {
          select: { id: true, phone: true, ...applicationNameFields },
        },
      },
    });

    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: member.weddingPlanId },
      select: { title: true },
    });

    await this.notifications.createNotification({
      userId: member.userId,
      weddingPlanId: member.weddingPlanId,
      type: NotificationType.SHARING_UPDATED,
      title: "تم تحديث صلاحياتك",
      body: `تغيرت صلاحياتك في "${plan?.title ?? "خطة الزفاف"}".`,
      entityType: "shared_member",
      entityId: member.id,
      routeTarget: `/wedding-plans/${member.weddingPlanId}/plan-center`,
      data: {
        sharedMemberId: member.id,
        weddingPlanId: member.weddingPlanId,
        role: member.role,
      },
      dedupeKey: `${member.userId}:sharing:${member.id}:updated:${member.updatedAt.getTime()}`,
    });

    return this.toMemberResponse(member);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findMemberOrThrow(id);
    const access = await this.permissions.assertMemberManageable(
      existing.weddingPlanId,
      currentUser,
    );
    this.assertPermissionCeiling(
      access,
      existing.role,
      this.permissionFlagsForRecord(existing),
    );
    await this.prisma.sharedMember.delete({ where: { id } });
    return { id, deleted: true };
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
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    const plan = await this.findPlanWithOwnerOrThrow(weddingPlanId);
    const members = await this.prisma.sharedMember.findMany({
      where: { weddingPlanId },
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
          );
        this.assertPermissionCeiling(
          transactionalAccess,
          role,
          permissionData,
        );
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
          },
          include: this.inviteIncludes(),
        });

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
    return {
      ...this.toInviteResponse(created.invite, created.token),
      delivery,
    };
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
    return invites.map((invite) => this.toInviteResponse(invite));
  }

  async getInviteForCurrentUser(
    currentUser: AuthenticatedUser,
    token: string,
  ): Promise<PlanInviteResponse> {
    const invite = await this.findInviteByTokenOrThrow(token);
    this.assertInviteBelongsToCurrentUser(invite, currentUser);
    return this.toInviteResponse(invite);
  }

  async findInvitesForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<PlanInviteResponse[]> {
    const access = await this.permissions.assertMemberManageable(
      weddingPlanId,
      currentUser,
    );
    const invites = await this.prisma.planInvite.findMany({
      where: {
        weddingPlanId,
        ...(access.isOwner ? {} : { inviterUserId: currentUser.id }),
      },
      include: this.inviteIncludes(),
      orderBy: { createdAt: "desc" },
    });
    return invites.map((invite) => this.toInviteResponse(invite));
  }

  async cancelInvite(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    inviteId: string,
  ): Promise<PlanInviteResponse> {
    await this.permissions.assertMemberManageable(
      weddingPlanId,
      currentUser,
    );

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
  ): Promise<PlanInviteResponse> {
    await this.permissions.assertMemberManageable(
      weddingPlanId,
      currentUser,
    );

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
          data: { tokenHash: this.hashInviteToken(token) },
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
    return {
      ...this.toInviteResponse(reissued.invite, reissued.token),
      delivery,
    };
  }

  async acceptInvite(
    currentUser: AuthenticatedUser,
    token: string,
  ): Promise<{ invite: PlanInviteResponse; member: SharedMemberResponse }> {
    const invite = await this.findInviteByTokenOrThrow(token);
    this.assertInviteCanBeAccepted(invite, currentUser);

    const acceptedAt = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
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
        update: {
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
    };
  }

  async declineInvite(
    currentUser: AuthenticatedUser,
    token: string,
  ): Promise<PlanInviteResponse> {
    const invite = await this.findInviteByTokenOrThrow(token);
    this.assertInviteCanBeAccepted(invite, currentUser);

    const declinedAt = new Date();
    const declined = await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.planInvite.updateMany({
        where: {
          id: invite.id,
          ...this.inviteClaimTokenFilter(invite, token),
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
        where: { id: invite.id },
        include: this.inviteIncludes(),
      });
      if (!updated) {
        throw new ConflictException("Invite is no longer pending");
      }

      await this.notifications.createNotificationInTransaction(tx, {
        userId: invite.inviterUserId,
        weddingPlanId: invite.weddingPlanId,
        type: NotificationType.SHARING_INVITE_DECLINED,
        title: "تم رفض الدعوة",
        body: `${currentUser.name} رفض دعوة المشاركة في خطة الزفاف.`,
        entityType: "plan_invite",
        entityId: invite.id,
        routeTarget: `/wedding-plans/${invite.weddingPlanId}/sharing`,
        data: {
          inviteId: invite.id,
          weddingPlanId: invite.weddingPlanId,
        },
        dedupeKey: `${invite.inviterUserId}:plan-invite:${invite.id}:declined`,
      });
      return updated;
    });

    return this.toInviteResponse(declined);
  }

  async updateMemberForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    memberId: string,
    dto: UpdateSharedMemberDto,
  ): Promise<SharedMemberResponse> {
    const access = await this.permissions.assertMemberManageable(
      weddingPlanId,
      currentUser,
    );
    this.assertNotOwnerMemberId(memberId);

    const existing = await this.findMemberForPlanOrThrow(
      weddingPlanId,
      memberId,
    );
    this.assertPermissionCeiling(
      access,
      existing.role,
      this.permissionFlagsForRecord(existing),
    );
    const role = this.assignableRole(dto.role ?? existing.role);
    const permissionData = this.permissionDataForUpdate(existing, dto, role);
    this.assertPermissionCeiling(access, role, permissionData);
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
    const member = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.sharedMember.update({
        where: { id: existing.id },
        data: {
          ...(dto.role !== undefined ? { role } : {}),
          ...permissionData,
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
      return updated;
    });

    return this.toMemberResponse(member);
  }

  async removeMemberFromPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    memberId: string,
  ): Promise<{ id: string; deleted: true }> {
    const access = await this.permissions.assertMemberManageable(
      weddingPlanId,
      currentUser,
    );
    const plan = access.plan;
    if (this.isOwnerMemberId(memberId) || memberId === plan.ownerUserId) {
      throw new BadRequestException("Last owner cannot be removed");
    }

    const existing = await this.findMemberForPlanOrThrow(
      weddingPlanId,
      memberId,
    );
    this.assertPermissionCeiling(
      access,
      existing.role,
      this.permissionFlagsForRecord(existing),
    );
    await this.prisma.$transaction(async (tx) => {
      await tx.sharedMember.delete({ where: { id: existing.id } });
      await this.notifications.purgeMoneyForMember(
        tx,
        existing.userId,
        weddingPlanId,
      );
    });
    return { id: existing.id, deleted: true };
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

  private async findMemberOrThrow(id: string): Promise<SharedMember> {
    const member = await this.prisma.sharedMember.findUnique({ where: { id } });
    if (!member) {
      throw new NotFoundException("Shared member not found");
    }
    return member;
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
    if (invite.inviteeUserId && invite.inviteeUserId !== currentUser.id) {
      throw new NotFoundException("Invite not found");
    }
    if (
      invite.phone &&
      !PhoneNormalizer.areEquivalent(currentUser.phone, invite.phone)
    ) {
      throw new NotFoundException("Invite not found");
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
    if (invite.inviteeUserId && invite.inviteeUserId === currentUser.id) {
      return;
    }
    if (
      invite.phone &&
      PhoneNormalizer.areEquivalent(currentUser.phone, invite.phone)
    ) {
      return;
    }
    throw new NotFoundException("Invite not found");
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

  private permissionDataForUpdate(
    existing: SharedMember,
    dto: UpdateSharedMemberDto,
    role: SharedMemberRole,
  ): PermissionFlags {
    const roleChanged = dto.role !== undefined && dto.role !== existing.role;
    const defaults = rolePermissionDefaults(role);
    const canManageMoney =
      dto.canManageMoney ??
      (roleChanged ? defaults.canManageMoney : existing.canManageMoney);
    return {
      canViewMoney:
        canManageMoney ||
        (dto.canViewMoney ??
          (roleChanged ? defaults.canViewMoney : existing.canViewMoney)),
      canEditPlan:
        dto.canEditPlan ??
        (roleChanged ? defaults.canEditPlan : existing.canEditPlan),
      canManageTasks:
        dto.canManageTasks ??
        (roleChanged ? defaults.canManageTasks : existing.canManageTasks),
      canManageGuests:
        dto.canManageGuests ??
        (roleChanged ? defaults.canManageGuests : existing.canManageGuests),
      canManageProviders:
        dto.canManageProviders ??
        (roleChanged
          ? defaults.canManageProviders
          : existing.canManageProviders),
      canInviteMembers:
        dto.canInviteMembers ??
        (roleChanged ? defaults.canInviteMembers : existing.canInviteMembers),
      canManageMoney,
      receiveNotifications:
        dto.receiveNotifications ??
        (roleChanged
          ? defaults.receiveNotifications
          : existing.receiveNotifications),
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
      ...(member.user
        ? { user: toApplicationUserContact(member.user) }
        : {}),
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
    return {
      id: invite.id,
      weddingPlanId: invite.weddingPlanId,
      token: presentedToken ?? invite.id,
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
      status: this.inviteStatus(invite),
      expiresAt: invite.expiresAt,
      acceptedAt: invite.acceptedAt,
      declinedAt: invite.declinedAt,
      revokedAt: invite.revokedAt,
      createdAt: invite.createdAt,
      updatedAt: invite.updatedAt,
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
