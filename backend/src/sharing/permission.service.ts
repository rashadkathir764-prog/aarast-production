import { Injectable, NotFoundException } from "@nestjs/common";
import {
  Prisma,
  SharedMember,
  SharedMemberRole,
  WeddingPlan,
} from "@prisma/client";
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
    return this.getPlanAccessContextWithClient(
      this.prisma,
      weddingPlanId,
      currentUser,
    );
  }

  private async getPlanAccessContextWithClient(
    client: PrismaService | Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const plan = await client.weddingPlan.findUnique({
      where: { id: weddingPlanId },
    });

    if (!plan) {
      throw new NotFoundException("Wedding plan not found");
    }

    const isOwner = plan.ownerUserId === currentUser.id;
    const sharedMember = isOwner
      ? null
      : await client.sharedMember.findUnique({
          where: {
            weddingPlanId_userId: {
              weddingPlanId,
              userId: currentUser.id,
            },
          },
        });

    return { plan, isOwner, sharedMember };
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

  async assertProviderManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (this.canManageProviders(context)) return context;
    throw new NotFoundException("Wedding plan not found");
  }

  async assertProviderAndMoneyManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (
      this.canManageProviders(context) &&
      this.canManageMoney(context)
    ) {
      return context;
    }
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

  async assertMemberManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getPlanAccessContextWithClient(
      tx,
      weddingPlanId,
      currentUser,
    );
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
    return Boolean(context.sharedMember?.canManageProviders);
  }

  canManageMembers(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canInviteMembers);
  }

  private async getLockedPlanAccessContext(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const plan = await tx.weddingPlan.findUnique({
      where: { id: weddingPlanId },
    });
    if (!plan) {
      throw new NotFoundException("Wedding plan not found");
    }
    if (plan.ownerUserId === currentUser.id) {
      return { plan, isOwner: true, sharedMember: null };
    }

    // FOR SHARE conflicts with permission updates/deletes. If revocation
    // commits first, this transaction sees the revoked row; if this lock wins,
    // the authorized quote transition serializes before the revocation.
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "userId" = ${currentUser.id}
        FOR SHARE
      `,
    );
    const sharedMember = await tx.sharedMember.findUnique({
      where: {
        weddingPlanId_userId: {
          weddingPlanId,
          userId: currentUser.id,
        },
      },
    });
    return { plan, isOwner: false, sharedMember };
  }
}
