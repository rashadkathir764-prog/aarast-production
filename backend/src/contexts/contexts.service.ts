import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  SharedMember,
  WeddingPlan,
  WeddingPlanStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { PrismaService } from "../prisma/prisma.service";
import {
  PermissionService,
  PlanAccessContext,
} from "../sharing/permission.service";

export enum AvailableContextRole {
  OWNER = "OWNER",
  CONTRIBUTOR = "CONTRIBUTOR",
  PROVIDER = "PROVIDER",
}

export interface AvailableContextPermissions {
  canViewPlan: boolean;
  canEditPlan: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canInviteMembers: boolean;
  canViewMoney: boolean;
  canManageMoney: boolean;
  canManageProviderProfile: boolean;
}

export type ContextUnavailableReason = "PLAN_ARCHIVED";

export interface AvailableContext {
  contextKey: string;
  role: AvailableContextRole;
  weddingPlanId: string | null;
  providerId: string | null;
  displayName: string;
  permissions: AvailableContextPermissions;
  isAvailable: boolean;
  unavailableReason: ContextUnavailableReason | null;
}

type ParsedContextKey =
  | {
      role: AvailableContextRole.OWNER | AvailableContextRole.CONTRIBUTOR;
      weddingPlanId: string;
    }
  | {
      role: AvailableContextRole.PROVIDER;
      providerId: string;
    };

@Injectable()
export class ContextsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
  ) {}

  async list(currentUser: AuthenticatedUser): Promise<AvailableContext[]> {
    const [ownedPlans, memberships, provider] = await Promise.all([
      this.prisma.weddingPlan.findMany({
        where: { ownerUserId: currentUser.id },
      }),
      this.prisma.sharedMember.findMany({
        where: { userId: currentUser.id },
        include: { weddingPlan: true },
      }),
      this.prisma.provider.findUnique({
        where: { userId: currentUser.id },
      }),
    ]);

    const contexts: AvailableContext[] = [];
    const ownedPlanIds = new Set<string>();

    for (const plan of this.sortPlans(ownedPlans)) {
      ownedPlanIds.add(plan.id);
      contexts.push(this.planContext(plan, AvailableContextRole.OWNER, null));
    }

    const contributorMemberships = memberships
      .filter((membership) => !ownedPlanIds.has(membership.weddingPlanId))
      .sort(
        (left, right) =>
          right.weddingPlan.updatedAt.getTime() -
          left.weddingPlan.updatedAt.getTime(),
      );
    for (const membership of contributorMemberships) {
      contexts.push(
        this.planContext(
          membership.weddingPlan,
          AvailableContextRole.CONTRIBUTOR,
          membership,
        ),
      );
    }

    if (provider) {
      contexts.push({
        contextKey: this.providerContextKey(provider.id),
        role: AvailableContextRole.PROVIDER,
        weddingPlanId: null,
        providerId: provider.id,
        displayName: provider.businessName,
        permissions: this.providerPermissions(),
        isAvailable: true,
        unavailableReason: null,
      });
    }

    return contexts;
  }

  async validate(
    currentUser: AuthenticatedUser,
    rawContextKey: string,
  ): Promise<AvailableContext> {
    const parsed = this.parseContextKey(rawContextKey);
    let context: AvailableContext | null = null;

    if (parsed.role === AvailableContextRole.OWNER) {
      const plan = await this.prisma.weddingPlan.findFirst({
        where: {
          id: parsed.weddingPlanId,
          ownerUserId: currentUser.id,
        },
      });
      if (plan) {
        context = this.planContext(
          plan,
          AvailableContextRole.OWNER,
          null,
        );
      }
    } else if (parsed.role === AvailableContextRole.CONTRIBUTOR) {
      const membership = await this.prisma.sharedMember.findUnique({
        where: {
          weddingPlanId_userId: {
            weddingPlanId: parsed.weddingPlanId,
            userId: currentUser.id,
          },
        },
        include: { weddingPlan: true },
      });
      if (
        membership &&
        membership.weddingPlan.ownerUserId !== currentUser.id
      ) {
        context = this.planContext(
          membership.weddingPlan,
          AvailableContextRole.CONTRIBUTOR,
          membership,
        );
      }
    } else if ("providerId" in parsed) {
      const provider = await this.prisma.provider.findFirst({
        where: {
          id: parsed.providerId,
          userId: currentUser.id,
        },
      });
      if (provider) {
        context = {
          contextKey: this.providerContextKey(provider.id),
          role: AvailableContextRole.PROVIDER,
          weddingPlanId: null,
          providerId: provider.id,
          displayName: provider.businessName,
          permissions: this.providerPermissions(),
          isAvailable: true,
          unavailableReason: null,
        };
      }
    }

    if (!context) {
      throw new NotFoundException({
        statusCode: 404,
        code: "CONTEXT_NOT_FOUND",
        message: "Context not found",
      });
    }
    if (!context.isAvailable) {
      throw new ConflictException({
        statusCode: 409,
        code: "CONTEXT_UNAVAILABLE",
        message: "Context is no longer available",
        unavailableReason: context.unavailableReason,
      });
    }

    return context;
  }

  private planContext(
    plan: WeddingPlan,
    role: AvailableContextRole.OWNER | AvailableContextRole.CONTRIBUTOR,
    sharedMember: SharedMember | null,
  ): AvailableContext {
    const access: PlanAccessContext = {
      plan,
      isOwner: role === AvailableContextRole.OWNER,
      sharedMember,
    };
    const isAvailable = plan.status === WeddingPlanStatus.PLANNING;

    return {
      contextKey: this.planContextKey(plan.id, role),
      role,
      weddingPlanId: plan.id,
      providerId: null,
      displayName: plan.title,
      permissions: {
        canViewPlan: true,
        canEditPlan: this.permissions.canManagePlan(access),
        canManageTasks: this.permissions.canManageTasks(access),
        canManageGuests: this.permissions.canManageGuests(access),
        canManageProviders: this.permissions.canManageProviders(access),
        canInviteMembers: this.permissions.canManageMembers(access),
        canViewMoney: this.permissions.canViewMoney(access),
        canManageMoney: this.permissions.canManageMoney(access),
        canManageProviderProfile: false,
      },
      isAvailable,
      unavailableReason: isAvailable ? null : "PLAN_ARCHIVED",
    };
  }

  private providerPermissions(): AvailableContextPermissions {
    return {
      canViewPlan: false,
      canEditPlan: false,
      canManageTasks: false,
      canManageGuests: false,
      canManageProviders: false,
      canInviteMembers: false,
      canViewMoney: false,
      canManageMoney: false,
      canManageProviderProfile: true,
    };
  }

  private parseContextKey(rawContextKey: string): ParsedContextKey {
    const contextKey = rawContextKey.trim();
    if (contextKey !== rawContextKey) {
      this.invalidContextKey();
    }

    const planMatch = /^plan:([^:]{1,128}):(owner|contributor)$/.exec(
      contextKey,
    );
    if (planMatch) {
      return {
        role:
          planMatch[2] === "owner"
            ? AvailableContextRole.OWNER
            : AvailableContextRole.CONTRIBUTOR,
        weddingPlanId: planMatch[1],
      };
    }

    const providerMatch = /^provider:([^:]{1,128})$/.exec(contextKey);
    if (providerMatch) {
      return {
        role: AvailableContextRole.PROVIDER,
        providerId: providerMatch[1],
      };
    }

    return this.invalidContextKey();
  }

  private invalidContextKey(): never {
    throw new BadRequestException({
      statusCode: 400,
      code: "INVALID_CONTEXT_KEY",
      message: "Invalid context key",
    });
  }

  private planContextKey(
    weddingPlanId: string,
    role: AvailableContextRole.OWNER | AvailableContextRole.CONTRIBUTOR,
  ): string {
    const suffix =
      role === AvailableContextRole.OWNER ? "owner" : "contributor";
    return `plan:${weddingPlanId}:${suffix}`;
  }

  private providerContextKey(providerId: string): string {
    return `provider:${providerId}`;
  }

  private sortPlans<T extends WeddingPlan>(plans: T[]): T[] {
    return [...plans].sort(
      (left, right) => right.updatedAt.getTime() - left.updatedAt.getTime(),
    );
  }
}
