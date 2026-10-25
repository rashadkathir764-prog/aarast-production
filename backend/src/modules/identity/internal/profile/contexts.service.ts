import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  Provider,
  ProviderStatus,
  SharedMember,
  WeddingPlan,
  WeddingPersona,
  WeddingPlanStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../../public/identity-session.types";
import { PrismaService } from "../../../../platform/database/prisma.service";
import {
  providerAccessPolicy,
  ProviderAccessCapabilities,
  ProviderAccessMode,
} from "../../../marketplace/public/provider-access-policy";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  PlanAccessContext,
  readerAddressForm,
  readsPlanSections,
} from "../../../collaboration/public/collaboration-permission.port";
import type { AddressForm } from "../../../../shared-kernel/voice/address-form";
import {
  canonicalPlanContextKey,
  canonicalProviderContextKey,
} from "../../public/context-key";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../../../planning/public/plan-read.port";
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from "../../../marketplace/public/provider-read.port";

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
export type ContextLifecycle = WeddingPlanStatus | ProviderStatus;
export type ContextAccessMode = ProviderAccessMode;

export interface AvailableContext {
  contextKey: string;
  role: AvailableContextRole;
  weddingPlanId: string | null;
  providerId: string | null;
  membershipId: string | null;
  membershipAuthorityVersion: number | null;
  persona: WeddingPersona | null;
  /**
   * B5/D59: how the app speaks to this reader in this plan, resolved once
   * by the server (`addressFormOf`: the account's persona, else the member
   * role, else the plan's side) so the phone never works it out itself.
   * Null for a provider context.
   */
  readerForm: AddressForm | null;
  displayName: string;
  lifecycle: ContextLifecycle;
  accessMode: ContextAccessMode;
  capabilities: ProviderAccessCapabilities;
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
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(PLAN_READ_PORT)
    private readonly plans: PlanReadPort,
    @Inject(PROVIDER_READ_PORT)
    private readonly providers: ProviderReadPort,
  ) {}

  async list(currentUser: AuthenticatedUser): Promise<AvailableContext[]> {
    const [ownedPlans, memberships, provider] = await Promise.all([
      this.plans.listOwnedPlans(this.prisma, currentUser.id),
      this.permissions.listMemberships(this.prisma, currentUser.id),
      this.providers.getProviderByUserId(this.prisma, currentUser.id),
    ]);
    // The membership rows are collaboration's; their plans are planning's.
    const memberPlans = new Map(
      (
        await this.plans.getPlans(
          this.prisma,
          memberships.map((membership) => membership.weddingPlanId),
        )
      ).map((plan) => [plan.id, plan]),
    );

    const contexts: AvailableContext[] = [];
    const ownedPlanIds = new Set<string>();

    for (const plan of this.sortPlans(ownedPlans)) {
      ownedPlanIds.add(plan.id);
      contexts.push(
        this.planContext(currentUser, plan, AvailableContextRole.OWNER, null),
      );
    }

    const contributorMemberships = memberships
      .filter((membership) => !ownedPlanIds.has(membership.weddingPlanId))
      .map((membership) => ({
        membership,
        plan: memberPlans.get(membership.weddingPlanId),
      }))
      .filter(
        (entry): entry is { membership: SharedMember; plan: WeddingPlan } =>
          entry.plan !== undefined,
      )
      .sort(
        (left, right) =>
          right.plan.updatedAt.getTime() - left.plan.updatedAt.getTime(),
      );
    for (const { membership, plan } of contributorMemberships) {
      contexts.push(
        this.planContext(
          currentUser,
          plan,
          AvailableContextRole.CONTRIBUTOR,
          membership,
        ),
      );
    }

    if (provider) {
      contexts.push(this.providerContext(provider));
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
      const plan = await this.plans.findOwnedPlan(
        this.prisma,
        parsed.weddingPlanId,
        currentUser.id,
      );
      if (plan) {
        context = this.planContext(
          currentUser,
          plan,
          AvailableContextRole.OWNER,
          null,
        );
      }
    } else if (parsed.role === AvailableContextRole.CONTRIBUTOR) {
      const membership = await this.permissions.getMembership(
        this.prisma,
        parsed.weddingPlanId,
        currentUser.id,
      );
      const plan = membership
        ? await this.plans.getPlan(this.prisma, membership.weddingPlanId)
        : null;
      if (membership && plan && plan.ownerUserId !== currentUser.id) {
        context = this.planContext(
          currentUser,
          plan,
          AvailableContextRole.CONTRIBUTOR,
          membership,
        );
      }
    } else if ("providerId" in parsed) {
      const provider = await this.providers.findOwnedProvider(
        this.prisma,
        parsed.providerId,
        currentUser.id,
      );
      if (provider) {
        context = this.providerContext(provider);
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
    reader: Pick<AuthenticatedUser, "persona">,
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
    const canEditPlan =
      isAvailable && this.permissions.canManagePlan(access);
    const canManageTasks =
      isAvailable && this.permissions.canManageTasks(access);
    const canManageGuests =
      isAvailable && this.permissions.canManageGuests(access);
    const canManageProviders =
      isAvailable && this.permissions.canManageProviders(access);
    const canInviteMembers =
      isAvailable && this.permissions.canManageMembers(access);
    const canManageMoney =
      isAvailable && this.permissions.canManageMoney(access);

    return {
      contextKey: this.planContextKey(plan.id, role),
      role,
      weddingPlanId: plan.id,
      providerId: null,
      membershipId: sharedMember?.id ?? null,
      membershipAuthorityVersion: sharedMember?.authorityVersion ?? null,
      persona: plan.persona,
      readerForm: readerAddressForm(reader, access),
      displayName: plan.title,
      lifecycle: plan.status,
      accessMode: isAvailable ? "FULL" : "READ_ONLY",
      capabilities: {
        canViewProviderProfile: false,
        canManageProviderProfile: false,
        canUseProviderOperations: false,
      },
      permissions: {
        // D52: every member reads the plan's non-money sections.
        canViewPlan: readsPlanSections(access),
        canEditPlan,
        canManageTasks,
        canManageGuests,
        canManageProviders,
        canInviteMembers,
        canViewMoney: this.permissions.canViewMoney(access),
        canManageMoney,
        canManageProviderProfile: false,
      },
      isAvailable,
      unavailableReason: isAvailable ? null : "PLAN_ARCHIVED",
    };
  }

  private providerContext(provider: Provider): AvailableContext {
    const policy = providerAccessPolicy(provider);
    return {
      contextKey: this.providerContextKey(provider.id),
      role: AvailableContextRole.PROVIDER,
      weddingPlanId: null,
      providerId: provider.id,
      membershipId: null,
      membershipAuthorityVersion: null,
      persona: null,
      readerForm: null,
      displayName: provider.businessName,
      lifecycle: provider.status,
      accessMode: policy.accessMode,
      capabilities: policy.capabilities,
      permissions: this.providerPermissions(
        policy.capabilities.canManageProviderProfile,
      ),
      isAvailable: true,
      unavailableReason: null,
    };
  }

  private providerPermissions(
    canManageProviderProfile: boolean,
  ): AvailableContextPermissions {
    return {
      canViewPlan: false,
      canEditPlan: false,
      canManageTasks: false,
      canManageGuests: false,
      canManageProviders: false,
      canInviteMembers: false,
      canViewMoney: false,
      canManageMoney: false,
      canManageProviderProfile,
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
    return canonicalPlanContextKey(weddingPlanId, suffix);
  }

  private providerContextKey(providerId: string): string {
    return canonicalProviderContextKey(providerId);
  }

  private sortPlans<T extends WeddingPlan>(plans: T[]): T[] {
    return [...plans].sort(
      (left, right) => right.updatedAt.getTime() - left.updatedAt.getTime(),
    );
  }
}
