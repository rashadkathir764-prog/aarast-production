import { BadRequestException, Injectable } from '@nestjs/common';
import { WeddingPlan, WeddingPlanStatus } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService, PlanAccessContext } from '../sharing/permission.service';
import { CreateWeddingPlanDto } from './dto/create-wedding-plan.dto';
import { UpdateWeddingPlanDto } from './dto/update-wedding-plan.dto';

export interface WeddingPlanResponse {
  id: string;
  ownerUserId: string;
  title: string;
  city: string | null;
  weddingDate: Date | null;
  estimatedBudget: string | null;
  currency: string;
  status: WeddingPlanStatus;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class WeddingPlansService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    dto: CreateWeddingPlanDto,
  ): Promise<WeddingPlanResponse> {
    const plan = await this.prisma.weddingPlan.create({
      data: {
        ownerUserId: currentUser.id,
        title: this.requiredText(dto.title, 'title'),
        city: this.optionalText(dto.city),
        weddingDate: this.optionalDate(dto.weddingDate),
        estimatedBudget: this.optionalDecimal(dto.estimatedBudget),
        currency: this.optionalText(dto.currency) ?? 'YER',
      },
    });

    return this.toResponse(plan);
  }

  async findMine(currentUser: AuthenticatedUser): Promise<WeddingPlanResponse[]> {
    const plans = await this.prisma.weddingPlan.findMany({
      where: { ownerUserId: currentUser.id },
      orderBy: { createdAt: 'desc' },
    });

    return plans.map((plan) => this.toResponse(plan));
  }

  async findOne(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingPlanResponse> {
    const context = await this.permissions.assertPlanReadable(id, currentUser);
    return this.toResponse(context.plan, context);
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateWeddingPlanDto,
  ): Promise<WeddingPlanResponse> {
    await this.permissions.assertPlanManageable(id, currentUser);

    const plan = await this.prisma.weddingPlan.update({
      where: { id },
      data: {
        ...(dto.title !== undefined
          ? { title: this.requiredText(dto.title, 'title') }
          : {}),
        ...(dto.city !== undefined ? { city: this.optionalText(dto.city) } : {}),
        ...(dto.weddingDate !== undefined
          ? { weddingDate: this.optionalDate(dto.weddingDate) }
          : {}),
        ...(dto.estimatedBudget !== undefined
          ? { estimatedBudget: this.optionalDecimal(dto.estimatedBudget) }
          : {}),
        ...(dto.currency !== undefined
          ? { currency: this.requiredText(dto.currency, 'currency') }
          : {}),
      },
    });

    return this.toResponse(plan);
  }

  async archive(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingPlanResponse> {
    await this.permissions.assertPlanManageable(id, currentUser);

    const plan = await this.prisma.weddingPlan.update({
      where: { id },
      data: { status: WeddingPlanStatus.ARCHIVED },
    });

    return this.toResponse(plan);
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private optionalText(value: string | undefined): string | null {
    if (value === undefined) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private optionalDate(value: string | undefined): Date | null {
    if (value === undefined) return null;
    const timestamp = Date.parse(value);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException('weddingDate must be a valid ISO date string');
    }
    return new Date(timestamp);
  }

  private optionalDecimal(value: string | number | undefined): string | null {
    if (value === undefined) return null;

    const normalized = String(value).trim();
    if (!normalized || !/^-?\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException('estimatedBudget must be a valid decimal value');
    }

    return normalized;
  }

  private toResponse(
    plan: WeddingPlan,
    context?: PlanAccessContext,
  ): WeddingPlanResponse {
    const canViewBudget =
      !context || this.permissions.canReadFinancial(context, 'budget');

    return {
      id: plan.id,
      ownerUserId: plan.ownerUserId,
      title: plan.title,
      city: plan.city,
      weddingDate: plan.weddingDate,
      estimatedBudget: canViewBudget ? plan.estimatedBudget?.toString() ?? null : null,
      currency: plan.currency,
      status: plan.status,
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
    };
  }
}
