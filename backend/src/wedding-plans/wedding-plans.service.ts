import { BadRequestException, Injectable } from '@nestjs/common';
import {
  BudgetCategory,
  OnboardingPath,
  Prisma,
  WeddingPersona,
  WeddingPlan,
  WeddingPlanStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { SafeUser, toSafeUser } from '../auth/safe-user';
import { CompleteOnboardingDto } from '../onboarding/dto/complete-onboarding.dto';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService, PlanAccessContext } from '../sharing/permission.service';
import { CreateWeddingPlanDto } from './dto/create-wedding-plan.dto';
import { UpdateWeddingPlanDto } from './dto/update-wedding-plan.dto';

export interface WeddingPlanResponse {
  id: string;
  ownerUserId: string;
  title: string;
  city: string | null;
  location: Prisma.JsonValue | null;
  weddingDate: Date | null;
  priorities: string[];
  estimatedBudget: string | null;
  currency: string;
  onboardingPath: OnboardingPath | null;
  persona: WeddingPersona | null;
  onboardingCompletedAt: Date | null;
  status: WeddingPlanStatus;
  createdAt: Date;
  updatedAt: Date;
}

export interface OnboardingBudgetCategoryResponse {
  id: string;
  weddingPlanId: string;
  name: string;
  targetAmount: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface OnboardingCompletionResponse {
  user: SafeUser;
  activeWeddingPlan: WeddingPlanResponse;
  budgetCategories: OnboardingBudgetCategoryResponse[];
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
    const selectedCategories = this.normalizeSelectedCategories(
      dto.selectedCategories,
    );

    const plan = await this.prisma.weddingPlan.create({
      data: {
        ownerUserId: currentUser.id,
        title: this.requiredText(dto.title, 'title'),
        city: this.optionalText(dto.city),
        ...(dto.location !== undefined
          ? { location: this.optionalLocation(dto.location) }
          : {}),
        weddingDate: this.optionalDate(dto.weddingDate),
        priorities: this.normalizePriorities(dto.priorities),
        estimatedBudget: this.optionalNonNegativeDecimal(dto.estimatedBudget),
        currency: this.optionalText(dto.currency) ?? 'YER',
        onboardingPath: dto.onboardingPath ?? null,
        persona: dto.persona ?? null,
        ...(selectedCategories.length > 0
          ? {
              budgetCategories: {
                create: selectedCategories.map((name) => ({ name })),
              },
            }
          : {}),
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

  async findAccessible(
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse[]> {
    const plans = await this.prisma.weddingPlan.findMany({
      where: this.accessiblePlansWhere(currentUser.id),
      orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
    });

    return Promise.all(
      plans.map((plan) => this.toReadableResponse(plan, currentUser)),
    );
  }

  async findActive(
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse | null> {
    const user = await this.prisma.user.findUnique({
      where: { id: currentUser.id },
      select: { activeWeddingPlanId: true },
    });

    if (user?.activeWeddingPlanId) {
      const activePlan = await this.findAccessiblePlanningPlan(
        currentUser,
        user.activeWeddingPlanId,
      );
      if (activePlan) {
        return this.toReadableResponse(activePlan, currentUser);
      }
    }

    const fallbackPlan = await this.prisma.weddingPlan.findFirst({
      where: {
        ...this.accessiblePlansWhere(currentUser.id),
        status: WeddingPlanStatus.PLANNING,
      },
      orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
    });

    return fallbackPlan
      ? this.toReadableResponse(fallbackPlan, currentUser)
      : null;
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
          ? { estimatedBudget: this.optionalNonNegativeDecimal(dto.estimatedBudget) }
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

  async setActive(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingPlanResponse> {
    const context = await this.permissions.assertPlanReadable(id, currentUser);

    if (context.plan.status === WeddingPlanStatus.ARCHIVED) {
      throw new BadRequestException('Archived wedding plans cannot be active');
    }

    await this.prisma.user.update({
      where: { id: currentUser.id },
      data: { activeWeddingPlanId: id },
    });

    return this.toResponse(context.plan, context);
  }

  async completeOnboarding(
    currentUser: AuthenticatedUser,
    dto: CompleteOnboardingDto,
  ): Promise<OnboardingCompletionResponse> {
    const path = dto.path ?? OnboardingPath.USER;
    const city = this.optionalText(dto.city) ?? this.cityFromLocation(dto.location);
    const selectedCategories = this.normalizeSelectedCategories(
      dto.selectedCategories,
    );
    const now = new Date();

    const result = await this.prisma.$transaction(async (tx) => {
      const plan = await tx.weddingPlan.create({
        data: {
          ownerUserId: currentUser.id,
          title:
            this.optionalText(dto.title) ??
            this.defaultOnboardingPlanTitle(dto.persona, city),
          city,
          ...(dto.location !== undefined
            ? { location: this.optionalLocation(dto.location) }
            : {}),
          weddingDate: this.optionalDate(dto.weddingDate),
          priorities: this.normalizePriorities(dto.priorities),
          estimatedBudget: this.optionalNonNegativeDecimal(dto.estimatedBudget),
          currency: this.optionalText(dto.currency) ?? 'YER',
          onboardingPath: path,
          persona: dto.persona ?? null,
          onboardingCompletedAt: now,
        },
      });

      if (selectedCategories.length > 0) {
        await tx.budgetCategory.createMany({
          data: selectedCategories.map((name) => ({
            weddingPlanId: plan.id,
            name,
          })),
        });
      }

      const [budgetCategories, user] = await Promise.all([
        tx.budgetCategory.findMany({
          where: { weddingPlanId: plan.id },
          orderBy: { createdAt: 'asc' },
        }),
        tx.user.update({
          where: { id: currentUser.id },
          data: {
            activeWeddingPlanId: plan.id,
            onboardingPath: path,
            persona: dto.persona ?? null,
            onboardingCompletedAt: now,
          },
        }),
      ]);

      return { budgetCategories, plan, user };
    });

    return {
      user: toSafeUser(result.user),
      activeWeddingPlan: this.toResponse(result.plan),
      budgetCategories: result.budgetCategories.map((category) =>
        this.toBudgetCategoryResponse(category),
      ),
    };
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

  private optionalNonNegativeDecimal(
    value: string | number | undefined,
  ): string | null {
    if (value === undefined) return null;

    const normalized = String(value).trim();
    if (!normalized || !/^\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException(
        'estimatedBudget must be a valid non-negative decimal value',
      );
    }

    return normalized;
  }

  private optionalLocation(
    value: Record<string, unknown> | undefined,
  ): Prisma.InputJsonObject | undefined {
    if (value === undefined) return undefined;

    const normalized: Record<string, Prisma.InputJsonValue> = {};
    for (const [key, raw] of Object.entries(value)) {
      if (!key.trim() || raw === undefined || raw === null) continue;
      if (typeof raw === 'string') {
        const trimmed = raw.trim();
        if (trimmed) normalized[key] = trimmed;
        continue;
      }
      if (
        typeof raw === 'number' ||
        typeof raw === 'boolean' ||
        Array.isArray(raw) ||
        typeof raw === 'object'
      ) {
        normalized[key] = raw as Prisma.InputJsonValue;
      }
    }

    return Object.keys(normalized).length > 0
      ? (normalized as Prisma.InputJsonObject)
      : undefined;
  }

  private normalizePriorities(values: string[] | undefined): string[] {
    return this.normalizeStringList(values, 12);
  }

  private normalizeSelectedCategories(values: string[] | undefined): string[] {
    return this.normalizeStringList(values, 25);
  }

  private normalizeStringList(
    values: string[] | undefined,
    limit: number,
  ): string[] {
    if (!values) return [];

    const normalized: string[] = [];
    const seen = new Set<string>();

    for (const value of values) {
      const trimmed = value.trim();
      const key = trimmed.toLocaleLowerCase('en-US');
      if (!trimmed || seen.has(key)) continue;
      normalized.push(trimmed);
      seen.add(key);
      if (normalized.length >= limit) break;
    }

    return normalized;
  }

  private cityFromLocation(
    location: Record<string, unknown> | undefined,
  ): string | null {
    if (!location) return null;

    for (const key of ['city', 'district', 'governorate']) {
      const value = location[key];
      if (typeof value === 'string' && value.trim()) {
        return value.trim();
      }
    }

    return null;
  }

  private defaultOnboardingPlanTitle(
    persona: WeddingPersona | undefined,
    city: string | null,
  ): string {
    const base =
      persona === WeddingPersona.BRIDE
        ? 'Bride wedding plan'
        : persona === WeddingPersona.HELPER
          ? 'Family wedding plan'
          : 'Wedding plan';

    return city ? `${base} - ${city}` : base;
  }

  private accessiblePlansWhere(userId: string): Prisma.WeddingPlanWhereInput {
    return {
      OR: [
        { ownerUserId: userId },
        { sharedMembers: { some: { userId } } },
      ],
    };
  }

  private async findAccessiblePlanningPlan(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingPlan | null> {
    return this.prisma.weddingPlan.findFirst({
      where: {
        id,
        status: WeddingPlanStatus.PLANNING,
        ...this.accessiblePlansWhere(currentUser.id),
      },
    });
  }

  private async toReadableResponse(
    plan: WeddingPlan,
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse> {
    const context = await this.permissions.assertPlanReadable(plan.id, currentUser);
    return this.toResponse(context.plan, context);
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
      location: plan.location,
      weddingDate: plan.weddingDate,
      priorities: plan.priorities,
      estimatedBudget: canViewBudget ? plan.estimatedBudget?.toString() ?? null : null,
      currency: plan.currency,
      onboardingPath: plan.onboardingPath,
      persona: plan.persona,
      onboardingCompletedAt: plan.onboardingCompletedAt,
      status: plan.status,
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
    };
  }

  private toBudgetCategoryResponse(
    category: BudgetCategory,
  ): OnboardingBudgetCategoryResponse {
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
