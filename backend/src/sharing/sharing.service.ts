import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  NotificationType,
  PlanInvite,
  Prisma,
  SharedMember,
  SharedMemberRole,
  User,
  WeddingPlan,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePlanInviteDto } from './dto/create-plan-invite.dto';
import { CreateSharedMemberDto } from './dto/create-shared-member.dto';
import { UpdateSharedMemberDto } from './dto/update-shared-member.dto';
import { PermissionService, PlanAccessContext } from './permission.service';

export interface SharedMemberResponse {
  id: string;
  weddingPlanId: string;
  userId: string;
  user?: SafeSharedMemberUser;
  role: SharedMemberRole;
  canViewBudget: boolean;
  canViewExpenses: boolean;
  canViewDebts: boolean;
  canManageTasks: boolean;
  canManageFinancialRecords: boolean;
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
  phone: string | null;
  inviteeUserId: string | null;
  inviterUserId: string;
  role: SharedMemberRole;
  canViewBudget: boolean;
  canViewExpenses: boolean;
  canViewDebts: boolean;
  canManageTasks: boolean;
  canManageFinancialRecords: boolean;
  status: 'PENDING' | 'ACCEPTED' | 'REVOKED' | 'EXPIRED';
  expiresAt: Date;
  acceptedAt: Date | null;
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
}

export interface PermissionSummaryResponse {
  weddingPlanId: string;
  userId: string;
  isOwner: boolean;
  role: SharedMemberRole | null;
  canViewBudget: boolean;
  canViewExpenses: boolean;
  canViewDebts: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageFinancialRecords: boolean;
  canManagePlan: boolean;
  canManageMembers: boolean;
}

type PlanInviteWithRelations = PlanInvite & {
  weddingPlan?: Pick<
    WeddingPlan,
    'id' | 'title' | 'city' | 'weddingDate' | 'status'
  >;
  inviter?: SafeSharedMemberUser;
  invitee?: SafeSharedMemberUser | null;
};

type PermissionFlags = Pick<
  SharedMemberResponse,
  | 'canViewBudget'
  | 'canViewExpenses'
  | 'canViewDebts'
  | 'canManageTasks'
  | 'canManageFinancialRecords'
>;

@Injectable()
export class SharingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
    private readonly notifications: NotificationsService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateSharedMemberDto,
  ): Promise<SharedMemberResponse> {
    const plan = await this.permissions.assertPlanOwner(weddingPlanId, currentUser);
    const user = await this.findTargetUser(dto);
    const role = this.assignableRole(dto.role ?? SharedMemberRole.VIEWER);
    const userId = user.id;

    if (userId === plan.ownerUserId) {
      throw new BadRequestException('Owner cannot be added as a shared member');
    }

    const existing = await this.prisma.sharedMember.findUnique({
      where: { weddingPlanId_userId: { weddingPlanId, userId } },
    });
    if (existing) {
      throw new ConflictException('User is already shared on this wedding plan');
    }

    const member = await this.prisma.sharedMember.create({
      data: {
        weddingPlanId,
        userId,
        role,
        ...this.permissionDataForCreate(role, dto),
      },
      include: {
        user: { select: { id: true, name: true, phone: true } },
      },
    });

    await this.notifications.createNotification({
      userId,
      weddingPlanId,
      type: NotificationType.SHARING_INVITATION,
      title: 'Wedding plan shared',
      body: `You were added to "${plan.title}" with role ${member.role}.`,
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
    await this.permissions.assertPlanOwner(weddingPlanId, currentUser);

    const members = await this.prisma.sharedMember.findMany({
      where: { weddingPlanId },
      include: {
        user: { select: { id: true, name: true, phone: true } },
      },
      orderBy: { createdAt: 'asc' },
    });

    return members.map((member) => this.toMemberResponse(member));
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateSharedMemberDto,
  ): Promise<SharedMemberResponse> {
    const existing = await this.findMemberOrThrow(id);
    await this.permissions.assertPlanOwner(existing.weddingPlanId, currentUser);
    const role = this.assignableRole(dto.role ?? existing.role);

    const member = await this.prisma.sharedMember.update({
      where: { id },
      data: {
        ...(dto.role !== undefined ? { role } : {}),
        ...this.permissionDataForUpdate(existing, dto, role),
      },
      include: {
        user: { select: { id: true, name: true, phone: true } },
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
      title: 'Sharing permissions updated',
      body: `Your permissions were updated for "${plan?.title ?? 'wedding plan'}".`,
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
    await this.permissions.assertPlanOwner(existing.weddingPlanId, currentUser);
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
        user: { select: { id: true, name: true, phone: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return members.map((member) =>
      this.toSharedPlanResponse(member.weddingPlan, member),
    );
  }

  async findMembersForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<PlanMemberResponse[]> {
    await this.permissions.assertPlanOwner(weddingPlanId, currentUser);
    const plan = await this.findPlanWithOwnerOrThrow(weddingPlanId);
    const members = await this.prisma.sharedMember.findMany({
      where: { weddingPlanId },
      include: { user: { select: { id: true, name: true, phone: true } } },
      orderBy: { createdAt: 'asc' },
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
    const plan = await this.permissions.assertPlanOwner(weddingPlanId, currentUser);
    const target = await this.findInviteTarget(dto);
    const role = this.assignableRole(dto.role ?? SharedMemberRole.VIEWER);

    if (target.user?.id === plan.ownerUserId) {
      throw new BadRequestException('Owner cannot be invited to own wedding plan');
    }

    if (target.user) {
      const existingMember = await this.prisma.sharedMember.findUnique({
        where: {
          weddingPlanId_userId: {
            weddingPlanId,
            userId: target.user.id,
          },
        },
      });
      if (existingMember) {
        throw new ConflictException('User is already shared on this wedding plan');
      }
    }

    const invite = await this.createInviteWithUniqueToken({
      weddingPlanId,
      inviterUserId: currentUser.id,
      inviteeUserId: target.user?.id ?? null,
      phone: target.phone,
      role,
      ...this.permissionDataForCreate(role, dto),
      expiresAt: this.expiresAt(dto.expiresInDays),
    });

    if (target.user) {
      await this.notifications.createNotification({
        userId: target.user.id,
        weddingPlanId,
        type: NotificationType.SHARING_INVITATION,
        title: 'Wedding plan invitation',
        body: `You received an invitation to "${plan.title}".`,
        data: {
          inviteId: invite.id,
          weddingPlanId,
          role: invite.role,
        },
        dedupeKey: `${target.user.id}:plan-invite:${invite.id}`,
      });
    }

    return this.toInviteResponse(invite);
  }

  async getInvite(token: string): Promise<PlanInviteResponse> {
    const invite = await this.findInviteByTokenOrThrow(token);
    return this.toInviteResponse(invite);
  }

  async acceptInvite(
    currentUser: AuthenticatedUser,
    token: string,
  ): Promise<{ invite: PlanInviteResponse; member: SharedMemberResponse }> {
    const invite = await this.findInviteByTokenOrThrow(token);
    this.assertInviteCanBeAccepted(invite, currentUser);

    const acceptedAt = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      const member = await tx.sharedMember.upsert({
        where: {
          weddingPlanId_userId: {
            weddingPlanId: invite.weddingPlanId,
            userId: currentUser.id,
          },
        },
        update: {
          role: invite.role,
          canViewBudget: invite.canViewBudget,
          canViewExpenses: invite.canViewExpenses,
          canViewDebts: invite.canViewDebts,
          canManageTasks: invite.canManageTasks,
          canManageFinancialRecords: invite.canManageFinancialRecords,
        },
        create: {
          weddingPlanId: invite.weddingPlanId,
          userId: currentUser.id,
          role: invite.role,
          canViewBudget: invite.canViewBudget,
          canViewExpenses: invite.canViewExpenses,
          canViewDebts: invite.canViewDebts,
          canManageTasks: invite.canManageTasks,
          canManageFinancialRecords: invite.canManageFinancialRecords,
        },
        include: {
          user: { select: { id: true, name: true, phone: true } },
        },
      });

      const acceptedInvite = await tx.planInvite.update({
        where: { id: invite.id },
        data: {
          acceptedAt,
          inviteeUserId: currentUser.id,
        },
        include: this.inviteIncludes(),
      });

      return { member, acceptedInvite };
    });

    await this.notifications.createNotification({
      userId: invite.inviterUserId,
      weddingPlanId: invite.weddingPlanId,
      type: NotificationType.SHARING_UPDATED,
      title: 'Invitation accepted',
      body: `${currentUser.name} accepted your wedding plan invitation.`,
      data: {
        inviteId: invite.id,
        sharedMemberId: result.member.id,
        weddingPlanId: invite.weddingPlanId,
      },
      dedupeKey: `${invite.inviterUserId}:plan-invite:${invite.id}:accepted`,
    });

    return {
      invite: this.toInviteResponse(result.acceptedInvite),
      member: this.toMemberResponse(result.member),
    };
  }

  async updateMemberForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    memberId: string,
    dto: UpdateSharedMemberDto,
  ): Promise<SharedMemberResponse> {
    await this.permissions.assertPlanOwner(weddingPlanId, currentUser);
    this.assertNotOwnerMemberId(memberId);

    const existing = await this.findMemberForPlanOrThrow(weddingPlanId, memberId);
    const role = this.assignableRole(dto.role ?? existing.role);
    const member = await this.prisma.sharedMember.update({
      where: { id: existing.id },
      data: {
        ...(dto.role !== undefined ? { role } : {}),
        ...this.permissionDataForUpdate(existing, dto, role),
      },
      include: { user: { select: { id: true, name: true, phone: true } } },
    });

    return this.toMemberResponse(member);
  }

  async removeMemberFromPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    memberId: string,
  ): Promise<{ id: string; deleted: true }> {
    const plan = await this.permissions.assertPlanOwner(weddingPlanId, currentUser);
    if (this.isOwnerMemberId(memberId) || memberId === plan.ownerUserId) {
      throw new BadRequestException('Last owner cannot be removed');
    }

    const existing = await this.findMemberForPlanOrThrow(weddingPlanId, memberId);
    await this.prisma.sharedMember.delete({ where: { id: existing.id } });
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
      throw new NotFoundException('Shared member not found');
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
      throw new NotFoundException('Shared member not found');
    }
    return member;
  }

  private async findPlanWithOwnerOrThrow(
    weddingPlanId: string,
  ): Promise<WeddingPlan & { owner: SafeSharedMemberUser }> {
    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      include: { owner: { select: { id: true, name: true, phone: true } } },
    });
    if (!plan) {
      throw new NotFoundException('Wedding plan not found');
    }
    return plan;
  }

  private async findTargetUser(dto: CreateSharedMemberDto): Promise<User> {
    const userId = dto.userId?.trim();
    const phone = dto.phone?.trim();

    if (userId && phone) {
      throw new BadRequestException('Provide either userId or phone, not both');
    }

    if (!userId && !phone) {
      throw new BadRequestException('Provide either userId or phone');
    }

    let user: User | null;
    if (userId) {
      user = await this.prisma.user.findUnique({ where: { id: userId } });
    } else if (phone) {
      user = await this.prisma.user.findUnique({ where: { phone } });
    } else {
      user = null;
    }

    if (!user) {
      throw new BadRequestException(
        phone
          ? 'No registered user found for this phone'
          : 'userId must reference an existing user',
      );
    }

    return user;
  }

  private async findInviteTarget(
    dto: CreatePlanInviteDto,
  ): Promise<{ user: User | null; phone: string | null }> {
    const userId = this.optionalText(dto.userId);
    const phone = this.optionalText(dto.phone);

    if (userId && phone) {
      throw new BadRequestException('Provide either userId or phone, not both');
    }

    if (!userId && !phone) {
      throw new BadRequestException('Provide either userId or phone');
    }

    if (userId) {
      const user = await this.prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        throw new BadRequestException('userId must reference an existing user');
      }
      return { user, phone: user.phone };
    }

    const user = phone
      ? await this.prisma.user.findUnique({ where: { phone } })
      : null;
    return { user, phone };
  }

  private async createInviteWithUniqueToken(
    data: Omit<Prisma.PlanInviteUncheckedCreateInput, 'token'>,
  ): Promise<PlanInvite> {
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        return await this.prisma.planInvite.create({
          data: {
            ...data,
            token: randomBytes(32).toString('base64url'),
          },
        });
      } catch (error) {
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2002'
        ) {
          continue;
        }
        throw error;
      }
    }

    throw new ConflictException('Could not create a unique invite token');
  }

  private async findInviteByTokenOrThrow(
    token: string,
  ): Promise<PlanInviteWithRelations> {
    const invite = await this.prisma.planInvite.findUnique({
      where: { token },
      include: this.inviteIncludes(),
    });
    if (!invite) {
      throw new NotFoundException('Invite not found');
    }
    return invite;
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
      inviter: { select: { id: true, name: true, phone: true } },
      invitee: { select: { id: true, name: true, phone: true } },
    } satisfies Prisma.PlanInviteInclude;
  }

  private assertInviteCanBeAccepted(
    invite: PlanInvite,
    currentUser: AuthenticatedUser,
  ): void {
    if (invite.revokedAt) {
      throw new BadRequestException('Invite has been revoked');
    }
    if (invite.acceptedAt) {
      throw new ConflictException('Invite has already been accepted');
    }
    if (invite.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException('Invite has expired');
    }
    if (invite.inviteeUserId && invite.inviteeUserId !== currentUser.id) {
      throw new NotFoundException('Invite not found');
    }
    if (invite.phone && currentUser.phone !== invite.phone) {
      throw new NotFoundException('Invite not found');
    }
  }

  private assignableRole(role: SharedMemberRole): SharedMemberRole {
    if (role === SharedMemberRole.OWNER) {
      throw new BadRequestException('OWNER is reserved for the wedding plan owner');
    }
    return role;
  }

  private permissionDataForCreate(
    role: SharedMemberRole,
    dto: CreateSharedMemberDto | CreatePlanInviteDto,
  ): PermissionFlags {
    const defaults = this.rolePermissionDefaults(role);
    return {
      canViewBudget: dto.canViewBudget ?? defaults.canViewBudget,
      canViewExpenses: dto.canViewExpenses ?? defaults.canViewExpenses,
      canViewDebts: dto.canViewDebts ?? defaults.canViewDebts,
      canManageTasks: dto.canManageTasks ?? defaults.canManageTasks,
      canManageFinancialRecords:
        dto.canManageFinancialRecords ?? defaults.canManageFinancialRecords,
    };
  }

  private permissionDataForUpdate(
    existing: SharedMember,
    dto: UpdateSharedMemberDto,
    role: SharedMemberRole,
  ): PermissionFlags {
    const roleChanged = dto.role !== undefined && dto.role !== existing.role;
    const defaults = this.rolePermissionDefaults(role);
    return {
      canViewBudget:
        dto.canViewBudget ?? (roleChanged ? defaults.canViewBudget : existing.canViewBudget),
      canViewExpenses:
        dto.canViewExpenses ??
        (roleChanged ? defaults.canViewExpenses : existing.canViewExpenses),
      canViewDebts:
        dto.canViewDebts ?? (roleChanged ? defaults.canViewDebts : existing.canViewDebts),
      canManageTasks:
        dto.canManageTasks ??
        (roleChanged ? defaults.canManageTasks : existing.canManageTasks),
      canManageFinancialRecords:
        dto.canManageFinancialRecords ??
        (roleChanged
          ? defaults.canManageFinancialRecords
          : existing.canManageFinancialRecords),
    };
  }

  private rolePermissionDefaults(role: SharedMemberRole): PermissionFlags {
    if (role === SharedMemberRole.FINANCE_MANAGER) {
      return {
        canViewBudget: true,
        canViewExpenses: true,
        canViewDebts: true,
        canManageTasks: false,
        canManageFinancialRecords: true,
      };
    }

    if (
      role === SharedMemberRole.EDITOR ||
      role === SharedMemberRole.HELPER ||
      role === SharedMemberRole.CONTRIBUTOR ||
      role === SharedMemberRole.MANAGER
    ) {
      return {
        canViewBudget: false,
        canViewExpenses: false,
        canViewDebts: false,
        canManageTasks: true,
        canManageFinancialRecords: false,
      };
    }

    return {
      canViewBudget: false,
      canViewExpenses: false,
      canViewDebts: false,
      canManageTasks: false,
      canManageFinancialRecords: false,
    };
  }

  private expiresAt(expiresInDays?: number): Date {
    const days = expiresInDays ?? 14;
    return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  }

  private optionalText(value: string | null | undefined): string | null {
    const trimmed = value?.trim() ?? '';
    return trimmed || null;
  }

  private isOwnerMemberId(memberId: string): boolean {
    return memberId.startsWith('owner:');
  }

  private assertNotOwnerMemberId(memberId: string): void {
    if (this.isOwnerMemberId(memberId)) {
      throw new BadRequestException('Owner member cannot be edited');
    }
  }

  private toMemberResponse(
    member: SharedMember & { user?: SafeSharedMemberUser },
  ): SharedMemberResponse {
    return {
      id: member.id,
      weddingPlanId: member.weddingPlanId,
      userId: member.userId,
      ...(member.user ? { user: member.user } : {}),
      role: member.role,
      canViewBudget: member.canViewBudget,
      canViewExpenses: member.canViewExpenses,
      canViewDebts: member.canViewDebts,
      canManageTasks: member.canManageTasks,
      canManageFinancialRecords: member.canManageFinancialRecords,
      createdAt: member.createdAt,
      updatedAt: member.updatedAt,
    };
  }

  private toPlanMemberResponse(
    member: SharedMember & { user?: SafeSharedMemberUser },
  ): PlanMemberResponse {
    return {
      ...this.toMemberResponse(member),
      isOwner: false,
    };
  }

  private toOwnerMemberResponse(
    plan: WeddingPlan & { owner: SafeSharedMemberUser },
  ): PlanMemberResponse {
    return {
      id: `owner:${plan.ownerUserId}`,
      weddingPlanId: plan.id,
      userId: plan.ownerUserId,
      user: plan.owner,
      role: SharedMemberRole.OWNER,
      canViewBudget: true,
      canViewExpenses: true,
      canViewDebts: true,
      canManageTasks: true,
      canManageFinancialRecords: true,
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

  private toInviteResponse(invite: PlanInviteWithRelations): PlanInviteResponse {
    return {
      id: invite.id,
      weddingPlanId: invite.weddingPlanId,
      token: invite.token,
      phone: invite.phone,
      inviteeUserId: invite.inviteeUserId,
      inviterUserId: invite.inviterUserId,
      role: invite.role,
      canViewBudget: invite.canViewBudget,
      canViewExpenses: invite.canViewExpenses,
      canViewDebts: invite.canViewDebts,
      canManageTasks: invite.canManageTasks,
      canManageFinancialRecords: invite.canManageFinancialRecords,
      status: this.inviteStatus(invite),
      expiresAt: invite.expiresAt,
      acceptedAt: invite.acceptedAt,
      revokedAt: invite.revokedAt,
      createdAt: invite.createdAt,
      updatedAt: invite.updatedAt,
      ...(invite.weddingPlan ? { weddingPlan: invite.weddingPlan } : {}),
      ...(invite.inviter ? { inviter: invite.inviter } : {}),
      ...(invite.invitee !== undefined ? { invitee: invite.invitee } : {}),
    };
  }

  private inviteStatus(
    invite: Pick<PlanInvite, 'acceptedAt' | 'revokedAt' | 'expiresAt'>,
  ): PlanInviteResponse['status'] {
    if (invite.revokedAt) return 'REVOKED';
    if (invite.acceptedAt) return 'ACCEPTED';
    if (invite.expiresAt.getTime() < Date.now()) return 'EXPIRED';
    return 'PENDING';
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
        : context.sharedMember?.role ?? null,
      canViewBudget: this.permissions.canReadFinancial(context, 'budget'),
      canViewExpenses: this.permissions.canReadFinancial(context, 'expenses'),
      canViewDebts: this.permissions.canReadFinancial(context, 'debts'),
      canManageTasks: this.permissions.canManageTasks(context),
      canManageGuests: this.permissions.canManageGuests(context),
      canManageFinancialRecords:
        this.permissions.canManageFinancialRecords(context),
      canManagePlan: this.permissions.canManagePlan(context),
      canManageMembers: context.isOwner,
    };
  }
}
