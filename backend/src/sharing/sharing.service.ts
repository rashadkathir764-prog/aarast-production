import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { SharedMember, SharedMemberRole, WeddingPlan } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSharedMemberDto } from './dto/create-shared-member.dto';
import { UpdateSharedMemberDto } from './dto/update-shared-member.dto';
import { PermissionService } from './permission.service';

export interface SharedMemberResponse {
  id: string;
  weddingPlanId: string;
  userId: string;
  role: SharedMemberRole;
  canViewBudget: boolean;
  canViewExpenses: boolean;
  canViewDebts: boolean;
  canManageTasks: boolean;
  canManageFinancialRecords: boolean;
  createdAt: Date;
  updatedAt: Date;
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

@Injectable()
export class SharingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateSharedMemberDto,
  ): Promise<SharedMemberResponse> {
    const plan = await this.permissions.assertPlanOwner(weddingPlanId, currentUser);
    const userId = this.requiredText(dto.userId, 'userId');

    if (userId === plan.ownerUserId) {
      throw new BadRequestException('Owner cannot be added as a shared member');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new BadRequestException('userId must reference an existing user');
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
        role: dto.role ?? SharedMemberRole.VIEWER,
        canViewBudget: dto.canViewBudget ?? false,
        canViewExpenses: dto.canViewExpenses ?? false,
        canViewDebts: dto.canViewDebts ?? false,
        canManageTasks: dto.canManageTasks ?? false,
        canManageFinancialRecords: dto.canManageFinancialRecords ?? false,
      },
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

    const member = await this.prisma.sharedMember.update({
      where: { id },
      data: {
        ...(dto.role !== undefined ? { role: dto.role } : {}),
        ...(dto.canViewBudget !== undefined
          ? { canViewBudget: dto.canViewBudget }
          : {}),
        ...(dto.canViewExpenses !== undefined
          ? { canViewExpenses: dto.canViewExpenses }
          : {}),
        ...(dto.canViewDebts !== undefined ? { canViewDebts: dto.canViewDebts } : {}),
        ...(dto.canManageTasks !== undefined
          ? { canManageTasks: dto.canManageTasks }
          : {}),
        ...(dto.canManageFinancialRecords !== undefined
          ? { canManageFinancialRecords: dto.canManageFinancialRecords }
          : {}),
      },
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
      include: { weddingPlan: true },
      orderBy: { createdAt: 'desc' },
    });

    return members.map((member) =>
      this.toSharedPlanResponse(member.weddingPlan, member),
    );
  }

  private async findMemberOrThrow(id: string): Promise<SharedMember> {
    const member = await this.prisma.sharedMember.findUnique({ where: { id } });
    if (!member) {
      throw new NotFoundException('Shared member not found');
    }
    return member;
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private toMemberResponse(member: SharedMember): SharedMemberResponse {
    return {
      id: member.id,
      weddingPlanId: member.weddingPlanId,
      userId: member.userId,
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
}
