import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { BudgetCategory, Prisma } from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { requiredMoneyAmount } from "../common/validation/money";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
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
    private readonly permissions: PermissionService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateBudgetCategoryDto,
  ): Promise<BudgetCategoryResponse> {
    await this.permissions.assertMoneyManageable(weddingPlanId, currentUser);
    const name = this.requiredText(dto.name, "name");
    const allocation = this.optionalAllocation(dto.allocatedAmount);
    try {
      return await runSerializableTransaction(
        this.prisma,
        async (tx) => {
          const plan = await this.lockPlan(tx, weddingPlanId);
          await this.assertAllocationFits(
            tx,
            weddingPlanId,
            plan.estimatedBudget,
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
          return this.toResponse(category);
        },
      );
    } catch (error) {
      this.rethrowCategoryError(error);
    }
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<BudgetCategoryResponse[]> {
    await this.permissions.assertMoneyReadable(weddingPlanId, currentUser);
    const categories = await this.prisma.budgetCategory.findMany({
      where: { weddingPlanId },
      include: { _count: { select: { weddingCosts: true } } },
      orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    });
    return categories.map((category) => this.toResponse(category));
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateBudgetCategoryDto,
  ): Promise<BudgetCategoryResponse> {
    const existing = await this.findCategoryOrThrow(id);
    await this.permissions.assertMoneyManageable(
      existing.weddingPlanId,
      currentUser,
    );
    try {
      return await runSerializableTransaction(
        this.prisma,
        async (tx) => {
          const plan = await this.lockPlan(tx, existing.weddingPlanId);
          const locked = await tx.budgetCategory.findUnique({ where: { id } });
          if (!locked) throw new NotFoundException("Budget category not found");
          const allocation =
            dto.allocatedAmount === undefined
              ? locked.allocatedAmount
              : this.optionalAllocation(dto.allocatedAmount);
          await this.assertAllocationFits(
            tx,
            locked.weddingPlanId,
            plan.estimatedBudget,
            allocation,
            id,
          );
          const name =
            dto.name === undefined
              ? locked.name
              : this.requiredText(dto.name, "name");
          const category = await tx.budgetCategory.update({
            where: { id },
            data: {
              name,
              normalizedName: this.normalizedName(name),
              allocatedAmount: allocation,
            },
            include: { _count: { select: { weddingCosts: true } } },
          });
          return this.toResponse(category);
        },
      );
    } catch (error) {
      this.rethrowCategoryError(error);
    }
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const category = await this.findCategoryOrThrow(id);
    await this.permissions.assertMoneyManageable(
      category.weddingPlanId,
      currentUser,
    );
    await this.prisma.$transaction(async (tx) => {
      await this.lockPlan(tx, category.weddingPlanId);
      const costsCount = await tx.weddingCost.count({
        where: { budgetCategoryId: id },
      });
      if (costsCount > 0) {
        throw new ConflictException(
          "Move or delete this category costs before deleting the category",
        );
      }
      await tx.budgetCategory.delete({ where: { id } });
    });
    return { id, deleted: true };
  }

  private async lockPlan(tx: Prisma.TransactionClient, id: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "WeddingPlan" WHERE "id" = ${id} FOR UPDATE`,
    );
    if (rows.length === 0)
      throw new NotFoundException("Wedding plan not found");
    return tx.weddingPlan.findUniqueOrThrow({ where: { id } });
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

  private requiredText(value: string, field: string) {
    const trimmed = value.trim().replace(/\s+/gu, " ");
    if (!trimmed) throw new BadRequestException(`${field} must not be empty`);
    return trimmed;
  }

  private normalizedName(value: string) {
    return value.trim().replace(/\s+/gu, " ").toLocaleLowerCase("ar");
  }

  private optionalAllocation(value: string | number | null | undefined) {
    if (value === undefined || value === null || String(value).trim() === "")
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
