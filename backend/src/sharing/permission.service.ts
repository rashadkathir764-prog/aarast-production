import { Injectable, NotFoundException } from "@nestjs/common";
import { SharedMember, SharedMemberRole, WeddingPlan } from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { PrismaService } from "../prisma/prisma.service";

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
      throw new NotFoundException("Wedding plan not found");
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
      throw new NotFoundException("Wedding plan not found");
    }
    return context.plan;
  }

  async assertPlanReadable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getPlanAccessContext(weddingPlanId, currentUser);
    if (!context.isOwner && !context.sharedMember) {
      throw new NotFoundException("Wedding plan not found");
    }
    return context;
  }

  async assertPlanManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (!this.canManagePlan(context)) {
      throw new NotFoundException("Wedding plan not found");
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
    if (this.canManageTasks(context)) {
      return context;
    }

    throw new NotFoundException("Wedding plan not found");
  }

  async assertGuestManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (this.canManageGuests(context)) return context;
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMoneyReadable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (context.isOwner) return context;
    if (this.canViewMoney(context)) return context;
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMoneyManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (context.isOwner) return context;

    const member = context.sharedMember;
    if (this.canManageMoney(context)) {
      return context;
    }

    throw new NotFoundException("Wedding plan not found");
  }

  async assertProviderManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (this.canManageProviders(context)) return context;
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMemberManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (this.canManageMembers(context)) return context;
    throw new NotFoundException("Wedding plan not found");
  }

  canViewMoney(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;

    const member = context.sharedMember;
    if (!member) return false;
    return Boolean(member.canViewMoney || this.canManageMoney(context));
  }

  canManageTasks(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    const member = context.sharedMember;
    return Boolean(
      member?.canManageTasks ||
      member?.role === SharedMemberRole.GROOM ||
      member?.role === SharedMemberRole.BRIDE ||
      member?.role === SharedMemberRole.FAMILY ||
      member?.role === SharedMemberRole.MANAGER ||
      member?.role === SharedMemberRole.EDITOR ||
      member?.role === SharedMemberRole.HELPER ||
      member?.role === SharedMemberRole.CONTRIBUTOR,
    );
  }

  canManageGuests(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    const member = context.sharedMember;
    return Boolean(
      member?.canManageGuests ||
      member?.role === SharedMemberRole.GROOM ||
      member?.role === SharedMemberRole.BRIDE ||
      member?.role === SharedMemberRole.FAMILY ||
      member?.role === SharedMemberRole.MANAGER ||
      member?.role === SharedMemberRole.EDITOR ||
      member?.role === SharedMemberRole.HELPER,
    );
  }

  canManageMoney(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    const member = context.sharedMember;
    return Boolean(
      member?.canManageMoney ||
      member?.role === SharedMemberRole.FINANCE_MANAGER,
    );
  }

  canManagePlan(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    const member = context.sharedMember;
    return Boolean(
      member?.canEditPlan ||
      member?.role === SharedMemberRole.GROOM ||
      member?.role === SharedMemberRole.BRIDE ||
      member?.role === SharedMemberRole.MANAGER ||
      member?.role === SharedMemberRole.EDITOR,
    );
  }

  canManageProviders(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    const member = context.sharedMember;
    return Boolean(
      member?.canManageProviders ||
      member?.role === SharedMemberRole.GROOM ||
      member?.role === SharedMemberRole.BRIDE ||
      member?.role === SharedMemberRole.HELPER ||
      member?.role === SharedMemberRole.CONTRIBUTOR ||
      member?.role === SharedMemberRole.MANAGER,
    );
  }

  canManageMembers(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canInviteMembers);
  }
}
