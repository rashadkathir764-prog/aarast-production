import { Injectable, NotFoundException } from '@nestjs/common';
import { SharedMember, SharedMemberRole, WeddingPlan } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';

export type FinancialPermissionType = 'budget' | 'expenses' | 'debts';

export interface PlanAccessContext {
  plan: WeddingPlan;
  isOwner: boolean;
  sharedMember: SharedMember | null;
}

@Injectable()
export class PermissionService {
  constructor(private readonly prisma: PrismaService) {}

  async getPlanAccessContext(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
    });

    if (!plan) {
      throw new NotFoundException('Wedding plan not found');
    }

    const isOwner = plan.ownerUserId === currentUser.id;
    const sharedMember = isOwner
      ? null
      : await this.prisma.sharedMember.findUnique({
          where: {
            weddingPlanId_userId: {
              weddingPlanId,
              userId: currentUser.id,
            },
          },
        });

    return { plan, isOwner, sharedMember };
  }

  async assertPlanOwner(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlan> {
    const context = await this.getPlanAccessContext(weddingPlanId, currentUser);
    if (!context.isOwner) {
      throw new NotFoundException('Wedding plan not found');
    }
    return context.plan;
  }

  async assertPlanReadable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getPlanAccessContext(weddingPlanId, currentUser);
    if (!context.isOwner && !context.sharedMember) {
      throw new NotFoundException('Wedding plan not found');
    }
    return context;
  }

  async assertPlanManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (!context.isOwner && context.sharedMember?.role !== SharedMemberRole.MANAGER) {
      throw new NotFoundException('Wedding plan not found');
    }
    return context;
  }

  async assertTaskManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (context.isOwner) return context;

    const member = context.sharedMember;
    if (member?.role === SharedMemberRole.MANAGER || member?.canManageTasks) {
      return context;
    }

    throw new NotFoundException('Wedding plan not found');
  }

  async assertFinancialReadable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
    type: FinancialPermissionType,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (context.isOwner) return context;
    if (this.canReadFinancial(context, type)) return context;
    throw new NotFoundException('Wedding plan not found');
  }

  async assertFinancialManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (context.isOwner) return context;

    const member = context.sharedMember;
    if (
      member?.role === SharedMemberRole.MANAGER ||
      member?.canManageFinancialRecords
    ) {
      return context;
    }

    throw new NotFoundException('Wedding plan not found');
  }

  canReadFinancial(context: PlanAccessContext, type: FinancialPermissionType): boolean {
    if (context.isOwner) return true;

    const member = context.sharedMember;
    if (!member) return false;
    if (member.role === SharedMemberRole.MANAGER) return true;
    if (type === 'budget') {
      return member.canViewBudget || member.canViewExpenses || member.canViewDebts;
    }
    if (type === 'expenses') return member.canViewExpenses;
    return member.canViewDebts;
  }

  canManageTasks(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    const member = context.sharedMember;
    return Boolean(member?.role === SharedMemberRole.MANAGER || member?.canManageTasks);
  }
}
