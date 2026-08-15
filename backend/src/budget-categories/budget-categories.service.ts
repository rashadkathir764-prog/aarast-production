import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  BudgetCategory,
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  Prisma,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_HISTORY_PORT,
  type CollaborationHistoryPort as ContributionHistoryService,
} from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../contribution-history/contribution-snapshot.builder";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { requiredMoneyAmount } from "../shared-kernel/money/money";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  type PlanAccessContext,
} from "../modules/collaboration/public/collaboration-permission.port";
import { CreateBudgetCategoryDto } from "./dto/create-budget-category.dto";
import { UpdateBudgetCategoryDto } from "./dto/update-budget-category.dto";

type CategoryWithCount = BudgetCategory & { _count: { weddingCosts: number } };

export interface BudgetCategoryResponse {
  id: string;
  weddingPlanId: string;
  name: string;
  allocatedAmount: string | null;
  costsCount: number;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class BudgetCategoriesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope?: ContributorScopeService,
    @Inject(COLLABORATION_HISTORY_PORT)
    private readonly contributionHistory?: ContributionHistoryService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateBudgetCategoryDto,
  ): Promise<BudgetCategoryResponse> {
    const name = this.requiredText(dto.name, "name");
    const allocation = this.optionalAllocation(dto.allocatedAmount);
    try {
      return await runSerializableTransaction(this.prisma, async (tx) => {
        const context =
          await this.permissions.assertMoneyManageableForUpdateInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        await this.assertAllocationFits(
          tx,
          weddingPlanId,
          context.plan.estimatedBudget,
          allocation,
        );
        const category = await tx.budgetCategory.create({
          data: {
            weddingPlanId,
            name,
            normalizedName: this.normalizedName(name),
            allocatedAmount: allocation,
          },
          include: { _count: { select: { weddingCosts: true } } },
        });
        const history = this.historyForContext(context);
        if (history) await history.recordForContextInTransaction(
          tx,
          context,
          {
            section: ContributionSection.MONEY,
            entityType: ContributionEntityType.BUDGET_CATEGORY,
            entityId: category.id,
            action: ContributionAction.CREATED,
            snapshot: buildContributionSnapshot(
              ContributionEntityType.BUDGET_CATEGORY,
              { title: category.name },
            ),
            dedupeKey: `money:budget-category:${category.id}:created`,
            requiredPermission: ContributionPermission.MANAGE_MONEY,
            occurredAt: category.createdAt,
          },
        );
        return this.toResponse(category);
      });
    } catch (error) {
      this.rethrowCategoryError(error);
    }
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<BudgetCategoryResponse[]> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        const [categoryIds, costIds] = access.isOwner
          ? [null, null]
          : await Promise.all([
              this.requiredContributorScope().qualifyingEntityIdsInTransaction(
                tx,
                weddingPlanId,
                currentUser.id,
                [ContributionEntityType.BUDGET_CATEGORY],
                [ContributionAction.CREATED],
              ),
              this.requiredContributorScope().qualifyingEntityIdsInTransaction(
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
            ]);
        const categories = await tx.budgetCategory.findMany({
          where: {
            weddingPlanId,
            ...(categoryIds ? { id: { in: categoryIds } } : {}),
          },
          include: {
            _count: {
              select: {
                weddingCosts: costIds
                  ? { where: { id: { in: costIds } } }
                  : true,
              },
            },
          },
          orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        });
        return categories.map((category) => this.toResponse(category));
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateBudgetCategoryDto,
  ): Promise<BudgetCategoryResponse> {
    const existing = await this.findCategoryOrThrow(id);
    await this.assertScopedCategory(
      currentUser,
      existing.weddingPlanId,
      id,
    );
    try {
      return await runSerializableTransaction(this.prisma, async (tx) => {
        const context =
          await this.permissions.assertMoneyManageableForUpdateInTransaction(
            tx,
            existing.weddingPlanId,
            currentUser,
          );
        await this.assertScopedCategoryInTransaction(tx, context, id);
        const locked = await tx.budgetCategory.findUnique({ where: { id } });
        if (!locked || locked.weddingPlanId !== existing.weddingPlanId) {
          throw new NotFoundException("Budget category not found");
        }
        const allocation =
          dto.allocatedAmount === undefined
            ? locked.allocatedAmount
            : this.optionalAllocation(dto.allocatedAmount);
        await this.assertAllocationFits(
          tx,
          locked.weddingPlanId,
          context.plan.estimatedBudget,
          allocation,
          id,
        );
        const name =
          dto.name === undefined
            ? locked.name
            : this.requiredText(dto.name, "name");
        const scopedCostIds = context.isOwner
          ? null
          : await this.requiredContributorScope().qualifyingEntityIdsInTransaction(
              tx,
              locked.weddingPlanId,
              currentUser.id,
              [ContributionEntityType.WEDDING_COST],
              [
                ContributionAction.CREATED,
                ContributionAction.COMPLETED,
                ContributionAction.PAYMENT_RECORDED,
              ],
            );
        const category = await tx.budgetCategory.update({
          where: { id },
          data: {
            name,
            normalizedName: this.normalizedName(name),
            allocatedAmount: allocation,
          },
          include: {
            _count: {
              select: {
                weddingCosts: scopedCostIds
                  ? { where: { id: { in: scopedCostIds } } }
                  : true,
              },
            },
          },
        });
        const history = this.historyForContext(context);
        if (history) await history.recordForContextInTransaction(
          tx,
          context,
          {
            section: ContributionSection.MONEY,
            entityType: ContributionEntityType.BUDGET_CATEGORY,
            entityId: category.id,
            action: ContributionAction.UPDATED,
            snapshot: buildContributionSnapshot(
              ContributionEntityType.BUDGET_CATEGORY,
              {
                title: category.name,
                amount: category.allocatedAmount,
              },
            ),
            dedupeKey: `money:budget-category:${category.id}:updated:${category.updatedAt.toISOString()}`,
            requiredPermission: ContributionPermission.MANAGE_MONEY,
            occurredAt: category.updatedAt,
          },
        );
        return this.toResponse(category);
      });
    } catch (error) {
      this.rethrowCategoryError(error);
    }
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const category = await this.findCategoryOrThrow(id);
    await this.assertScopedCategory(
      currentUser,
      category.weddingPlanId,
      id,
    );
    await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableForUpdateInTransaction(
        tx,
        category.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCategoryInTransaction(tx, context, id);
      const locked = await tx.budgetCategory.findUnique({ where: { id } });
      if (!locked || locked.weddingPlanId !== category.weddingPlanId) {
        throw new NotFoundException("Budget category not found");
      }
      const costsCount = await tx.weddingCost.count({
        where: { budgetCategoryId: id },
      });
      if (costsCount > 0) {
        throw new ConflictException(
          "Move or delete this category costs before deleting the category",
        );
      }
      const history = this.historyForContext(context);
      if (history) await history.recordForContextInTransaction(
        tx,
        context,
        {
          section: ContributionSection.MONEY,
          entityType: ContributionEntityType.BUDGET_CATEGORY,
          entityId: locked.id,
          action: ContributionAction.DELETED,
          snapshot: buildContributionSnapshot(
            ContributionEntityType.BUDGET_CATEGORY,
            { title: locked.name, amount: locked.allocatedAmount },
          ),
          dedupeKey: `money:budget-category:${locked.id}:deleted`,
          requiredPermission: ContributionPermission.MANAGE_MONEY,
        },
      );
      await tx.budgetCategory.delete({ where: { id } });
    });
    return { id, deleted: true };
  }

  private async assertAllocationFits(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    totalBudget: Prisma.Decimal | null,
    allocation: Prisma.Decimal | null,
    excludeId?: string,
  ) {
    if (allocation?.gt(0) && totalBudget === null) {
      throw new BadRequestException(
        "Set the general budget before allocating money to categories",
      );
    }
    const result = await tx.budgetCategory.aggregate({
      where: {
        weddingPlanId,
        ...(excludeId ? { id: { not: excludeId } } : {}),
      },
      _sum: { allocatedAmount: true },
    });
    const sum = (result._sum.allocatedAmount ?? new Prisma.Decimal(0)).plus(
      allocation ?? 0,
    );
    if (totalBudget !== null && sum.gt(totalBudget)) {
      throw new BadRequestException(
        "Category allocations cannot exceed the general budget",
      );
    }
  }

  private async findCategoryOrThrow(id: string) {
    const category = await this.prisma.budgetCategory.findUnique({
      where: { id },
    });
    if (!category) throw new NotFoundException("Budget category not found");
    return category;
  }

  private requiredContributorScope(): ContributorScopeService {
    if (!this.contributorScope) {
      throw new Error(
        "ContributorScopeService is required for contributor category access",
      );
    }
    return this.contributorScope;
  }

  private historyForContext(
    context: PlanAccessContext,
  ): ContributionHistoryService | null {
    if (context.isOwner) return null;
    if (!this.contributionHistory) {
      throw new Error(
        "ContributionHistoryService is required for contributor category writes",
      );
    }
    return this.contributionHistory;
  }

  private async assertScopedCategory(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    categoryId: string,
  ): Promise<void> {
    const access = await this.permissions.assertMoneyReadable(
      weddingPlanId,
      currentUser,
    );
    if (access.isOwner) return;
    const categoryIds =
      await this.requiredContributorScope().qualifyingEntityIds(
        weddingPlanId,
        currentUser.id,
        [ContributionEntityType.BUDGET_CATEGORY],
        [ContributionAction.CREATED],
      );
    if (categoryIds.includes(categoryId)) return;
    throw new NotFoundException("Budget category not found");
  }

  private async assertScopedCategoryInTransaction(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    categoryId: string,
  ): Promise<void> {
    if (context.isOwner || !context.sharedMember) return;
    const categoryIds =
      await this.requiredContributorScope().qualifyingEntityIdsInTransaction(
        tx,
        context.plan.id,
        context.sharedMember.userId,
        [ContributionEntityType.BUDGET_CATEGORY],
        [ContributionAction.CREATED],
      );
    if (categoryIds.includes(categoryId)) return;
    throw new NotFoundException("Budget category not found");
  }

  private requiredText(value: string, field: string) {
    const trimmed = value.trim().replace(/\s+/gu, " ");
    if (!trimmed) throw new BadRequestException(`${field} must not be empty`);
    return trimmed;
  }

  private normalizedName(value: string) {
    return value.trim().replace(/\s+/gu, " ").toLocaleLowerCase("ar");
  }

  private optionalAllocation(value: string | number | null | undefined) {
    if (
      value === undefined ||
      value === null ||
      (typeof value === "string" && value.trim() === "")
    )
      return null;
    return new Prisma.Decimal(requiredMoneyAmount(value, "allocatedAmount"));
  }

  private toResponse(category: CategoryWithCount): BudgetCategoryResponse {
    return {
      id: category.id,
      weddingPlanId: category.weddingPlanId,
      name: category.name,
      allocatedAmount: category.allocatedAmount?.toString() ?? null,
      costsCount: category._count.weddingCosts,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    };
  }

  private rethrowCategoryError(error: unknown): never {
    if (
      error instanceof BadRequestException ||
      error instanceof ConflictException ||
      error instanceof NotFoundException
    ) {
      throw error;
    }
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === "P2002") {
        throw new ConflictException("A category with this name already exists");
      }
      if (error.code === "P2003") {
        throw new ConflictException("This category is still in use");
      }
    }
    throw error;
  }
}
