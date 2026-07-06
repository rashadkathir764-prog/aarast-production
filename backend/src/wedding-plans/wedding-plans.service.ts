import { BadRequestException, Injectable } from '@nestjs/common';
import {
  AppRole,
  BudgetCategory,
  ExpenseStatus,
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  OnboardingPath,
  Prisma,
  WeddingPersona,
  WeddingPlan,
  WeddingPlanStatus,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { SafeUser, toSafeUser } from '../auth/safe-user';
import { PhoneNormalizer } from '../common/phone/phone-normalizer';
import { requiredMoneyAmount } from '../common/validation/money';
import { CompleteOnboardingDto } from '../onboarding/dto/complete-onboarding.dto';
import { ImportLocalPlanDto } from '../onboarding/dto/import-local-plan.dto';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService, PlanAccessContext } from '../sharing/permission.service';
import { CreateWeddingPlanDto } from './dto/create-wedding-plan.dto';
import { UpdateWeddingPlanDto } from './dto/update-wedding-plan.dto';
import {
  cityFromWeddingLocation,
  normalizeWeddingLocationInput,
  WeddingLocationResponse,
  weddingLocationResponse,
} from './wedding-location';

export interface WeddingPlanResponse {
  id: string;
  ownerUserId: string;
  title: string;
  city: string | null;
  location: WeddingLocationResponse | null;
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

export interface LocalPlanImportResponse extends OnboardingCompletionResponse {
  imported: {
    expenses: number;
    tasks: number;
    guests: number;
  };
  alreadyImported: boolean;
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
    const location =
      dto.location !== undefined
        ? normalizeWeddingLocationInput(dto.location, dto.city)
        : null;
    const city =
      this.optionalText(dto.city) ?? cityFromWeddingLocation(location);

    const plan = await this.prisma.$transaction(async (tx) => {
      const created = await tx.weddingPlan.create({
        data: {
          ownerUserId: currentUser.id,
          title: this.requiredText(dto.title, 'title'),
          city,
          ...(dto.location !== undefined
            ? { location: location ?? Prisma.DbNull }
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

      await tx.user.update({
        where: { id: currentUser.id },
        data: { activeWeddingPlanId: created.id },
      });

      return created;
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
    const context = await this.permissions.assertPlanManageable(id, currentUser);
    const location =
      dto.location !== undefined
        ? normalizeWeddingLocationInput(
            dto.location,
            dto.city ?? context.plan.city,
          )
        : null;
    const city =
      dto.city !== undefined
        ? this.optionalText(dto.city)
        : dto.location !== undefined
          ? cityFromWeddingLocation(location) ?? context.plan.city
          : undefined;

    const plan = await this.prisma.weddingPlan.update({
      where: { id },
      data: {
        ...(dto.title !== undefined
          ? { title: this.requiredText(dto.title, 'title') }
          : {}),
        ...(city !== undefined ? { city } : {}),
        ...(dto.location !== undefined
          ? { location: location ?? Prisma.DbNull }
          : {}),
        ...(dto.weddingDate !== undefined
          ? { weddingDate: this.optionalDate(dto.weddingDate) }
          : {}),
        ...(dto.estimatedBudget !== undefined
          ? { estimatedBudget: this.optionalNonNegativeDecimal(dto.estimatedBudget) }
          : {}),
        ...(dto.currency !== undefined
          ? { currency: this.requiredText(dto.currency, 'currency') }
          : {}),
        ...(dto.priorities !== undefined
          ? { priorities: this.normalizePriorities(dto.priorities) }
          : {}),
        ...(dto.onboardingPath !== undefined
          ? { onboardingPath: dto.onboardingPath }
          : {}),
        ...(dto.persona !== undefined ? { persona: dto.persona } : {}),
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
    const location =
      dto.location !== undefined
        ? normalizeWeddingLocationInput(dto.location, dto.city)
        : null;
    const city =
      this.optionalText(dto.city) ?? cityFromWeddingLocation(location);
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
            ? { location: location ?? Prisma.DbNull }
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
            appRole:
              path === OnboardingPath.PROVIDER
                ? AppRole.PROVIDER
                : AppRole.WEDDING_USER,
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

  /**
   * One-shot migration of a guest-mode local plan (plan seed + expenses +
   * tasks + guests) into the authenticated account, inside a single
   * transaction. Idempotent via `clientMigrationId`: a retry after a
   * timeout returns the already-imported plan instead of duplicating it —
   * a guest's weeks of planning must never be lost or doubled.
   */
  async importLocalPlan(
    currentUser: AuthenticatedUser,
    dto: ImportLocalPlanDto,
  ): Promise<LocalPlanImportResponse> {
    const migrationId = this.requiredText(
      dto.clientMigrationId,
      'clientMigrationId',
    );

    const existing = await this.prisma.weddingPlan.findFirst({
      where: { ownerUserId: currentUser.id, importMigrationId: migrationId },
    });
    if (existing) {
      return this.buildImportResponse(existing, currentUser, true);
    }

    const path = dto.path ?? OnboardingPath.USER;
    const location =
      dto.location !== undefined
        ? normalizeWeddingLocationInput(dto.location, dto.city)
        : null;
    const city =
      this.optionalText(dto.city) ?? cityFromWeddingLocation(location);
    const selectedCategories = this.normalizeSelectedCategories(
      dto.selectedCategories,
    );
    const now = new Date();

    // Validate every imported row BEFORE opening the transaction so a bad
    // row fails fast as a 400 without partial writes.
    const expenses = (dto.expenses ?? []).map((expense, index) => ({
      title: this.requiredText(expense.title, `expenses[${index}].title`),
      amount: this.requiredAmount(expense.amount, `expenses[${index}].amount`),
      categoryName: this.optionalText(expense.categoryName ?? undefined),
      status: expense.status ?? ExpenseStatus.PAID,
      expenseDate: this.parseDateField(
        expense.expenseDate ?? undefined,
        `expenses[${index}].expenseDate`,
      ),
      note: this.optionalText(expense.note ?? undefined),
    }));

    const tasks = (dto.tasks ?? []).map((task, index) => ({
      title: this.requiredText(task.title, `tasks[${index}].title`),
      description: this.optionalText(task.description ?? undefined),
      dueDate: this.parseDateField(
        task.dueDate ?? undefined,
        `tasks[${index}].dueDate`,
      ),
      taskCategory: this.optionalText(task.taskCategory ?? undefined),
      reminderAt: this.parseDateField(
        task.reminderAt ?? undefined,
        `tasks[${index}].reminderAt`,
      ),
      status: task.status ?? WeddingTaskStatus.TODO,
      priority: task.priority ?? WeddingTaskPriority.MEDIUM,
    }));

    const guests = (dto.guests ?? []).map((guest, index) => {
      const name = this.requiredText(guest.name, `guests[${index}].name`);
      const phone = PhoneNormalizer.normalizeOptional(guest.phone);
      return {
        name,
        normalizedName: name.replace(/\s+/g, ' '),
        phone,
        normalizedPhone: phone,
        side: guest.side ?? GuestSide.OTHER,
        status: guest.status ?? GuestStatus.INVITED,
        invitationStatus:
          guest.invitationStatus ?? GuestInvitationStatus.NOT_SENT,
        attendanceStatus:
          guest.attendanceStatus ?? GuestAttendanceStatus.PENDING,
        seatsCount: guest.seatsCount ?? 1,
        companionsCount: guest.companionsCount ?? 0,
        notes: this.optionalText(guest.notes ?? undefined),
      };
    });

    // Categories = onboarding selection ∪ names referenced by expenses.
    const categoryNames = this.normalizeStringList(
      [
        ...selectedCategories,
        ...expenses
          .map((expense) => expense.categoryName)
          .filter((name): name is string => Boolean(name)),
      ],
      50,
    );

    try {
      const plan = await this.prisma.$transaction(async (tx) => {
        const createdPlan = await tx.weddingPlan.create({
          data: {
            ownerUserId: currentUser.id,
            title:
              this.optionalText(dto.title) ??
              this.defaultOnboardingPlanTitle(dto.persona, city),
            city,
            ...(dto.location !== undefined
              ? { location: location ?? Prisma.DbNull }
              : {}),
            weddingDate: this.optionalDate(dto.weddingDate),
            priorities: this.normalizePriorities(dto.priorities),
            estimatedBudget: this.optionalNonNegativeDecimal(
              dto.estimatedBudget,
            ),
            currency: this.optionalText(dto.currency) ?? 'YER',
            onboardingPath: path,
            persona: dto.persona ?? null,
            onboardingCompletedAt: now,
            importMigrationId: migrationId,
          },
        });

        if (categoryNames.length > 0) {
          await tx.budgetCategory.createMany({
            data: categoryNames.map((name) => ({
              weddingPlanId: createdPlan.id,
              name,
            })),
          });
        }

        const categories = await tx.budgetCategory.findMany({
          where: { weddingPlanId: createdPlan.id },
        });
        const categoryIdByName = new Map(
          categories.map((category) => [
            category.name.trim().toLocaleLowerCase('en-US'),
            category.id,
          ]),
        );

        if (expenses.length > 0) {
          await tx.expense.createMany({
            data: expenses.map((expense) => ({
              weddingPlanId: createdPlan.id,
              budgetCategoryId: expense.categoryName
                ? (categoryIdByName.get(
                    expense.categoryName.toLocaleLowerCase('en-US'),
                  ) ?? null)
                : null,
              title: expense.title,
              amount: expense.amount,
              status: expense.status,
              expenseDate: expense.expenseDate,
              note: expense.note,
            })),
          });
        }

        if (tasks.length > 0) {
          await tx.weddingTask.createMany({
            data: tasks.map((task) => ({
              weddingPlanId: createdPlan.id,
              ...task,
            })),
          });
        }

        if (guests.length > 0) {
          await tx.guest.createMany({
            data: guests.map((guest) => ({
              weddingPlanId: createdPlan.id,
              ...guest,
            })),
            skipDuplicates: true,
          });
        }

        await tx.user.update({
          where: { id: currentUser.id },
          data: {
            activeWeddingPlanId: createdPlan.id,
            appRole:
              path === OnboardingPath.PROVIDER
                ? AppRole.PROVIDER
                : AppRole.WEDDING_USER,
            onboardingPath: path,
            persona: dto.persona ?? null,
            onboardingCompletedAt: now,
          },
        });

        return createdPlan;
      });

      return this.buildImportResponse(plan, currentUser, false);
    } catch (error) {
      // Two concurrent submissions with the same migration id: the loser
      // hits the unique constraint — treat it as an idempotent replay.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const winner = await this.prisma.weddingPlan.findFirst({
          where: {
            ownerUserId: currentUser.id,
            importMigrationId: migrationId,
          },
        });
        if (winner) {
          return this.buildImportResponse(winner, currentUser, true);
        }
      }
      throw error;
    }
  }

  private async buildImportResponse(
    plan: WeddingPlan,
    currentUser: AuthenticatedUser,
    alreadyImported: boolean,
  ): Promise<LocalPlanImportResponse> {
    const [user, budgetCategories, expensesCount, tasksCount, guestsCount] =
      await Promise.all([
        this.prisma.user.findUniqueOrThrow({ where: { id: currentUser.id } }),
        this.prisma.budgetCategory.findMany({
          where: { weddingPlanId: plan.id },
          orderBy: { createdAt: 'asc' },
        }),
        this.prisma.expense.count({ where: { weddingPlanId: plan.id } }),
        this.prisma.weddingTask.count({ where: { weddingPlanId: plan.id } }),
        this.prisma.guest.count({ where: { weddingPlanId: plan.id } }),
      ]);

    return {
      user: toSafeUser(user),
      activeWeddingPlan: this.toResponse(plan),
      budgetCategories: budgetCategories.map((category) =>
        this.toBudgetCategoryResponse(category),
      ),
      imported: {
        expenses: expensesCount,
        tasks: tasksCount,
        guests: guestsCount,
      },
      alreadyImported,
    };
  }

  private requiredAmount(value: string | number, field: string): string {
    return requiredMoneyAmount(value, field);
  }

  private parseDateField(value: string | undefined, field: string): Date | null {
    if (value === undefined) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    const timestamp = Date.parse(trimmed);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException(`${field} must be a valid ISO date string`);
    }
    return new Date(timestamp);
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
    return requiredMoneyAmount(value, 'estimatedBudget');
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
      location: weddingLocationResponse(plan.location, plan.city),
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
