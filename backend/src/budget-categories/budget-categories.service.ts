import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { BudgetCategory } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { requiredMoneyAmount } from '../common/validation/money';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';
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
    private readonly permissionService: PermissionService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateBudgetCategoryDto,
  ): Promise<BudgetCategoryResponse> {
    await this.permissionService.assertFinancialManageable(weddingPlanId, currentUser);

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
    await this.permissionService.assertFinancialReadable(
      weddingPlanId,
      currentUser,
      'budget',
    );

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
    const existing = await this.findCategoryOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      existing.weddingPlanId,
      currentUser,
    );

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
    const category = await this.findCategoryOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      category.weddingPlanId,
      currentUser,
    );
    await this.prisma.budgetCategory.delete({ where: { id } });
    return { id, deleted: true };
  }

  private async findCategoryOrThrow(
    id: string,
  ): Promise<BudgetCategory> {
    const category = await this.prisma.budgetCategory.findUnique({ where: { id } });

    if (!category) {
      throw new NotFoundException('Budget category not found');
    }

    return category;
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
    return requiredMoneyAmount(value, 'amount');
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
