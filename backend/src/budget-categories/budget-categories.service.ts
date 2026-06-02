import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { BudgetCategory, WeddingPlan } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { OwnershipContextService } from '../auth/ownership-context.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBudgetCategoryDto } from './dto/create-budget-category.dto';
import { UpdateBudgetCategoryDto } from './dto/update-budget-category.dto';

export interface BudgetCategoryResponse {
  id: string;
  weddingPlanId: string;
  name: string;
  targetAmount: string | null;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class BudgetCategoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ownershipContext: OwnershipContextService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateBudgetCategoryDto,
  ): Promise<BudgetCategoryResponse> {
    await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const category = await this.prisma.budgetCategory.create({
      data: {
        weddingPlanId,
        name: this.requiredText(dto.name, 'name'),
        targetAmount: this.optionalNonNegativeDecimal(dto.targetAmount),
      },
    });

    return this.toResponse(category);
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<BudgetCategoryResponse[]> {
    await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const categories = await this.prisma.budgetCategory.findMany({
      where: { weddingPlanId },
      orderBy: { createdAt: 'asc' },
    });

    return categories.map((category) => this.toResponse(category));
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateBudgetCategoryDto,
  ): Promise<BudgetCategoryResponse> {
    await this.findOwnedCategoryOrThrow(currentUser, id);

    const category = await this.prisma.budgetCategory.update({
      where: { id },
      data: {
        ...(dto.name !== undefined
          ? { name: this.requiredText(dto.name, 'name') }
          : {}),
        ...(dto.targetAmount !== undefined
          ? { targetAmount: this.optionalNonNegativeDecimal(dto.targetAmount) }
          : {}),
      },
    });

    return this.toResponse(category);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    await this.findOwnedCategoryOrThrow(currentUser, id);
    await this.prisma.budgetCategory.delete({ where: { id } });
    return { id, deleted: true };
  }

  private async findOwnedCategoryOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<BudgetCategory> {
    const category = await this.prisma.budgetCategory.findUnique({ where: { id } });

    if (!category) {
      throw new NotFoundException('Budget category not found');
    }

    await this.findOwnedWeddingPlanOrThrow(currentUser, category.weddingPlanId);
    return category;
  }

  private async findOwnedWeddingPlanOrThrow(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlan> {
    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
    });

    if (!plan || !this.ownershipContext.isOwner(currentUser, plan.ownerUserId)) {
      throw new NotFoundException('Wedding plan not found');
    }

    return plan;
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private optionalNonNegativeDecimal(
    value: string | number | null | undefined,
  ): string | null {
    if (value === undefined || value === null) return null;

    const normalized = String(value).trim();
    if (!normalized || !/^\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException('amount must be a valid non-negative decimal value');
    }

    return normalized;
  }

  private toResponse(category: BudgetCategory): BudgetCategoryResponse {
    return {
      id: category.id,
      weddingPlanId: category.weddingPlanId,
      name: category.name,
      targetAmount: category.targetAmount?.toString() ?? null,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    };
  }
}