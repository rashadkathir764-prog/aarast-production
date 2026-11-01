import { Inject, Injectable, NotFoundException } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  Prisma,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { runRetryableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import { readMoneyPicture } from "../modules/finance/infrastructure/money-picture";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../modules/planning/public/plan-read.port";
import {
  CATALOG_READ_PORT,
  type CatalogReadPort,
} from "../modules/catalog/public/catalog-read.port";
import { listPlanItemsForProviderSearch } from "../modules/finance/infrastructure/budget-item-search.repository";
import { budgetItemSearchCategories } from "../modules/finance/public/provider-category-budget-item";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  PlanAccessContext,
  seesWholePlan,
} from "../modules/collaboration/public/collaboration-permission.port";

@Injectable()
export class MoneySummaryService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(PLAN_READ_PORT)
    private readonly plans: PlanReadPort,
    @Inject(CATALOG_READ_PORT)
    private readonly catalog: CatalogReadPort,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope?: ContributorScopeService,
  ) {}

  async getSummary(currentUser: AuthenticatedUser, weddingPlanId: string) {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        const contributionScope = seesWholePlan(access)
          ? null
          : {
              costIds: await this.requiredContributorScope().qualifyingEntityIdsInTransaction(
                tx,
                weddingPlanId,
                currentUser.id,
                [ContributionEntityType.WEDDING_COST],
                [
                  ContributionAction.CREATED,
                  ContributionAction.COMPLETED,
                  ContributionAction.PAYMENT_RECORDED,
                ],
              ),
              categoryIds: await this.requiredContributorScope().qualifyingEntityIdsInTransaction(
                tx,
                weddingPlanId,
                currentUser.id,
                [ContributionEntityType.BUDGET_CATEGORY],
                [ContributionAction.CREATED],
              ),
            };
        return buildMoneySummaryInTransaction(
          tx,
          this.permissions,
          this.plans,
          this.catalog,
          access,
          contributionScope,
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  private requiredContributorScope(): ContributorScopeService {
    if (!this.contributorScope) {
      throw new Error("ContributorScopeService is required for contributor money summaries");
    }
    return this.contributorScope;
  }
}

/**
 * `GET money-summary`: finance's one money read (`readMoneyPicture`, D59)
 * for this reader, with what they may do. The dashboards and the assistant
 * read the same picture through the finance port.
 */
export async function buildMoneySummaryInTransaction(
  tx: Prisma.TransactionClient,
  permissions: PermissionService,
  plans: PlanReadPort,
  catalog: CatalogReadPort,
  access: PlanAccessContext,
  contributionScope: {
    costIds: readonly string[];
    categoryIds: readonly string[];
  } | null = null,
) {
  const weddingPlanId = access.plan.id;
  const plan = await plans.getPlan(tx, weddingPlanId);
  if (!plan) {
    throw new NotFoundException("Wedding plan not found");
  }
  const [picture, planItems, providerCategories, moneyCatalog] = await Promise.all([
    readMoneyPicture(tx, {
      weddingPlanId,
      persona: plan.persona ?? null,
      // The plan-wide budget belongs to the owner. A contributor receives
      // only totals derived from their own scoped costs/categories, never a
      // value (or a remaining/unallocated derivative) based on the owner's
      // budget.
      totalBudget: contributionScope ? null : plan.estimatedBudget,
      scope: contributionScope,
      readerUserId: access.sharedMember?.userId ?? access.plan.ownerUserId,
      // Funding (savings, family support, gifts, loans) is the owner's
      // private money picture; a contributor's summary never includes it.
      fundingVisible: access.isOwner && contributionScope === null,
    }),
    listPlanItemsForProviderSearch(tx, weddingPlanId),
    catalog.listActiveCategories(tx),
    catalog.listMoneyCatalogItems(tx),
  ]);
  // G40: the directory categories «ابحث» on each item searches, by the rule
  // acceptance files an offer with, over the whole plan's items. D73: the
  // money catalog's explicit links first, the words for the rest.
  const searchCategories = budgetItemSearchCategories(
    planItems,
    providerCategories,
    plan.persona,
    moneyCatalog,
  );
  return {
    weddingPlanId,
    currency: plan.currency,
    ...picture,
    categories: picture.categories.map((category) => ({
      ...category,
      /** G40: empty when no provider's offer lands here (no «ابحث»). */
      providerCategoryIds: searchCategories.get(category.categoryId) ?? [],
    })),
    permissions: {
      canViewMoney: permissions.canViewMoney(access),
      canManageMoney: permissions.canManageMoney(access),
      // V1 checklist 4.10: the owner or partner may record a private cost.
      canRecordPrivateCost:
        permissions.canManageMoney(access) && seesWholePlan(access),
    },
  };
}

export type MoneySummaryResult = Awaited<
  ReturnType<typeof buildMoneySummaryInTransaction>
>;
