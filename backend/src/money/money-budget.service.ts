import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { requiredMoneyAmount } from "../shared-kernel/money/money";
import { budgetAllocationViolation } from "../modules/finance/domain/budget-allocation-policy";
import { raiseFinanceViolation } from "../modules/finance/internal/finance-violation.http";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
} from "../modules/collaboration/public/collaboration-permission.port";
import {
  PLANNING_BUDGET_WRITE_PORT,
  type PlanningBudgetWritePort,
} from "../modules/planning/public/planning-budget-write.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../modules/planning/public/plan-read.port";
import {
  MoneyBudgetCategoryDto,
  ReplaceMoneyBudgetDto,
} from "./dto/replace-money-budget.dto";
import { RecordMahrDto } from "./dto/record-mahr.dto";
import { parseMahrAgreement } from "../modules/finance/public/mahr-agreement";
import { recordPlanMahrInTransaction } from "../modules/finance/infrastructure/mahr.repository";
import {
  buildMoneySummaryInTransaction,
  MoneySummaryResult,
} from "./money-summary.service";
import {
  countWeddingPlanCosts,
  createReplacementBudgetCategory,
  deleteOmittedBudgetCategories,
  findBudgetCategoriesForReplacement,
  listReplacedBudgetCategories,
  replaceBudgetCategoryValues,
  temporarilyRekeyBudgetCategory,
} from '../modules/finance/infrastructure/budget-category.repository';

export interface MoneyBudgetCategoryResult {
  id: string;
  weddingPlanId: string;
  name: string;
  allocatedAmount: string | null;
  costsCount: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface MoneyBudgetReplaceResult {
  summary: MoneySummaryResult;
  categories: MoneyBudgetCategoryResult[];
  idMap: Record<string, string>;
}

@Injectable()
export class MoneyBudgetService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(PLANNING_BUDGET_WRITE_PORT)
    private readonly planningBudgetWriter: PlanningBudgetWritePort,
    @Inject(PLAN_READ_PORT)
    private readonly plans: PlanReadPort,
  ) {}

  async replace(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: ReplaceMoneyBudgetDto,
  ): Promise<MoneyBudgetReplaceResult> {
    const totalBudget = this.totalBudget(dto.totalBudget);
    const currency = this.currency(dto.currency);
    const categories = dto.categories.map((item) => this.category(item));
    this.assertUniqueCategories(categories);
    const allocated = categories.reduce(
      (sum, item) => sum.plus(item.allocatedAmount ?? 0),
      new Prisma.Decimal(0),
    );
    raiseFinanceViolation(budgetAllocationViolation(totalBudget, allocated));

    try {
      return await runSerializableTransaction(this.prisma, async (tx) => {
        const context =
          await this.permissions.assertMoneyManageableForUpdateInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        if (!context.isOwner) {
          throw new NotFoundException("Wedding plan not found");
        }
        const costsCount = await countWeddingPlanCosts(tx, weddingPlanId);
        if (
          costsCount > 0 &&
          currency !== context.plan.currency.toUpperCase()
        ) {
          throw new ConflictException(
            "Currency cannot be changed after the first cost is created",
          );
        }

        const existing = await findBudgetCategoriesForReplacement(tx, weddingPlanId);
        const existingById = new Map(existing.map((item) => [item.id, item]));
        const submittedIds = new Set(
          categories.flatMap((item) => (item.id ? [item.id] : [])),
        );
        for (const item of categories) {
          if (item.id && !existingById.has(item.id)) {
            throw new BadRequestException(
              "Every category id must belong to this wedding plan",
            );
          }
        }
        const idMap: Record<string, string> = {};
        const omitted = existing.filter((item) => !submittedIds.has(item.id));
        const usedOmitted = omitted.find(
          (item) => item._count.weddingCosts > 0,
        );
        if (usedOmitted) {
          throw new ConflictException(
            `Category "${usedOmitted.name}" has costs and cannot be omitted`,
          );
        }
        if (omitted.length > 0) {
          await deleteOmittedBudgetCategories(tx, omitted.map((item) => item.id));
        }

        // Temporary unique keys allow atomic name swaps such as Hall <-> Dress.
        const existingSubmitted = categories.filter(
          (item): item is typeof item & { id: string } => Boolean(item.id),
        );
        for (const item of existingSubmitted) {
          await temporarilyRekeyBudgetCategory(tx, item.id);
        }
        for (const item of existingSubmitted) {
          await replaceBudgetCategoryValues(
            tx,
            item.id,
            item.name,
            item.normalizedName,
            item.allocatedAmount,
          );
        }
        for (const item of categories.filter((category) => !category.id)) {
          const created = await createReplacementBudgetCategory(
            tx,
            weddingPlanId,
            item.name,
            item.normalizedName,
            item.allocatedAmount,
          );
          idMap[item.clientId!] = created.id;
        }
        await this.planningBudgetWriter.updateBudgetInTransaction(tx, {
          weddingPlanId,
          estimatedBudget: totalBudget,
          currency,
        });
        const savedCategories = await listReplacedBudgetCategories(tx, weddingPlanId);
        const summary = await buildMoneySummaryInTransaction(
          tx,
          this.permissions,
          this.plans,
          context,
        );
        return {
          summary,
          categories: savedCategories.map((category) => ({
            id: category.id,
            weddingPlanId: category.weddingPlanId,
            name: category.name,
            allocatedAmount: category.allocatedAmount?.toString() ?? null,
            costsCount: category._count.weddingCosts,
            createdAt: category.createdAt,
            updatedAt: category.updatedAt,
          })),
          idMap,
        };
      });
    } catch (error) {
      if (
        error instanceof BadRequestException ||
        error instanceof ConflictException ||
        error instanceof NotFoundException
      ) {
        throw error;
      }
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === "P2002") {
          throw new ConflictException(
            "Category names must be unique in the plan",
          );
        }
        if (error.code === "P2003") {
          throw new ConflictException("A category still has dependent records");
        }
      }
      throw error;
    }
  }

  /**
   * a06 after the plan exists (b01's mahr step): the owner records the mahr
   * once; later changes go through the item and its payments (the groom) or
   * the funding sources (the bride). Returns the money summary with it.
   */
  async recordMahr(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: RecordMahrDto,
  ): Promise<MoneySummaryResult> {
    const agreement = parseMahrAgreement(dto);
    return runSerializableTransaction(this.prisma, async (tx) => {
      const context =
        await this.permissions.assertMoneyManageableForUpdateInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
      if (!context.isOwner) {
        throw new NotFoundException("Wedding plan not found");
      }
      await recordPlanMahrInTransaction(
        tx,
        weddingPlanId,
        context.plan.persona,
        agreement,
        new Date(),
      );
      return buildMoneySummaryInTransaction(
        tx,
        this.permissions,
        this.plans,
        context,
      );
    });
  }

  private totalBudget(value: string | number | null | undefined) {
    if (
      value === null ||
      value === undefined ||
      (typeof value === "string" && value.trim() === "")
    )
      return null;
    const amount = new Prisma.Decimal(
      requiredMoneyAmount(value, "totalBudget"),
    );
    if (!amount.gt(0)) {
      throw new BadRequestException(
        "totalBudget must be greater than zero when set",
      );
    }
    return amount;
  }

  private currency(value: string) {
    const currency = value.trim().toUpperCase();
    if (!/^[A-Z]{3}$/.test(currency)) {
      throw new BadRequestException("currency must be a three-letter ISO code");
    }
    return currency;
  }

  private category(item: MoneyBudgetCategoryDto) {
    const name = item.name.trim().replace(/\s+/gu, " ");
    if (!name) throw new BadRequestException("Category name must not be empty");
    const rawAllocation = item.allocatedAmount;
    const parsed =
      rawAllocation === null ||
      rawAllocation === undefined ||
      (typeof rawAllocation === "string" && rawAllocation.trim() === "")
        ? null
        : new Prisma.Decimal(
            requiredMoneyAmount(rawAllocation, "allocatedAmount"),
          );
    return {
      id: item.id?.trim() || null,
      clientId: item.clientId?.trim() || null,
      name,
      normalizedName: name.toLocaleLowerCase("ar"),
      allocatedAmount: parsed?.isZero() ? null : parsed,
    };
  }

  private assertUniqueCategories(
    categories: Array<{
      id: string | null;
      clientId: string | null;
      normalizedName: string;
    }>,
  ) {
    for (const item of categories) {
      if (Boolean(item.id) === Boolean(item.clientId)) {
        throw new BadRequestException(
          "Every category must have either id or clientId, but not both",
        );
      }
    }
    const ids = categories.flatMap((item) => (item.id ? [item.id] : []));
    if (new Set(ids).size !== ids.length) {
      throw new BadRequestException("Category ids must not be repeated");
    }
    const clientIds = categories.flatMap((item) =>
      item.clientId ? [item.clientId] : [],
    );
    if (new Set(clientIds).size !== clientIds.length) {
      throw new BadRequestException("Category clientIds must not be repeated");
    }
    const names = categories.map((item) => item.normalizedName);
    if (new Set(names).size !== names.length) {
      throw new BadRequestException(
        "Category names must be unique in the plan",
      );
    }
  }
}
