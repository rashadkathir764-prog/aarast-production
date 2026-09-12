import {
  BadRequestException,
  Inject,
  Injectable,
} from "@nestjs/common";
import {
  AppRole,
  BudgetCategory,
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionScopeStatus,
  ContributionSection,
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  OnboardingPath,
  Prisma,
  WeddingPersona,
  WeddingCostStatus,
  WeddingPlan,
  WeddingPlanStatus,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { SafeUser, toSafeUser } from "../modules/identity/public/safe-user";
import { PhoneNormalizer } from "../shared-kernel/phone/phone-normalizer";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { requiredMoneyAmount } from "../shared-kernel/money/money";
import {
  COLLABORATION_HISTORY_PORT,
  type CollaborationHistoryPort as ContributionHistoryService,
} from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
import { CompleteOnboardingDto } from "../onboarding/dto/complete-onboarding.dto";
import { ImportLocalPlanDto } from "../onboarding/dto/import-local-plan.dto";
import { PrismaService } from "../platform/database/prisma.service";
import {
  assertWeddingPlanWritable,
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  PlanAccessContext,
} from "../modules/collaboration/public/collaboration-permission.port";
import { assertActiveMutationActorForUpdateInTransaction } from "../modules/identity/public/user-lifecycle-lock";
import { CreateWeddingPlanDto } from "./dto/create-wedding-plan.dto";
import { UpdateWeddingPlanDto } from "./dto/update-wedding-plan.dto";
import {
  cityFromWeddingLocation,
  normalizeWeddingLocationInput,
  WeddingLocationResponse,
  weddingLocationResponse,
} from "../modules/planning/public/wedding-location";

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
  allocatedAmount: string | null;
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
    costs: number;
    payments: number;
    paymentSchedules: number;
    tasks: number;
    guests: number;
  };
  alreadyImported: boolean;
}

@Injectable()
export class WeddingPlansService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(COLLABORATION_HISTORY_PORT)
    private readonly contributionHistory: ContributionHistoryService,
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

    const plan = await runSerializableTransaction(this.prisma, async (tx) => {
      await assertActiveMutationActorForUpdateInTransaction(
        tx,
        currentUser.id,
      );
      const created = await tx.weddingPlan.create({
        data: {
          ownerUserId: currentUser.id,
          title: this.requiredText(dto.title, "title"),
          city,
          ...(dto.location !== undefined
            ? { location: location ?? Prisma.DbNull }
            : {}),
          weddingDate: this.optionalDate(dto.weddingDate),
          priorities: this.normalizePriorities(dto.priorities),
          estimatedBudget: this.optionalPositiveBudget(dto.estimatedBudget),
          currency: this.normalizedCurrency(dto.currency),
          onboardingPath: dto.onboardingPath ?? null,
          persona: dto.persona ?? null,
          ...(selectedCategories.length > 0
            ? {
                budgetCategories: {
                  create: selectedCategories.map((name) => ({
                    name,
                    normalizedName: this.normalizedCategoryName(name),
                  })),
                },
              }
            : {}),
        },
      });

      await this.createContributorHistoryScopeInTransaction(tx, created);

      await tx.user.update({
        where: { id: currentUser.id },
        data: { activeWeddingPlanId: created.id },
      });

      return created;
    });

    return this.toResponse(plan);
  }

  async findMine(
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse[]> {
    const plans = await this.prisma.weddingPlan.findMany({
      where: { ownerUserId: currentUser.id },
      orderBy: { createdAt: "desc" },
    });

    return plans.map((plan) => this.toResponse(plan));
  }

  async findAccessible(
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse[]> {
    const plans = await this.prisma.weddingPlan.findMany({
      where: this.accessiblePlansWhere(currentUser.id),
      orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
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

    return null;
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
    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const context =
        await this.permissions.assertPlanManageableForUpdateInTransaction(
          tx,
          id,
          currentUser,
        );
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
            ? (cityFromWeddingLocation(location) ?? context.plan.city)
            : undefined;

      const plan = await tx.weddingPlan.update({
        where: { id },
        data: {
          ...(dto.title !== undefined
            ? { title: this.requiredText(dto.title, "title") }
            : {}),
          ...(city !== undefined ? { city } : {}),
          ...(dto.location !== undefined
            ? { location: location ?? Prisma.DbNull }
            : {}),
          ...(dto.weddingDate !== undefined
            ? { weddingDate: this.optionalDate(dto.weddingDate) }
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
      await this.recordPlanContribution(
        tx,
        context,
        plan,
        ContributionAction.UPDATED,
      );
      return { context, plan };
    });

    return this.toResponse(result.plan, {
      ...result.context,
      plan: result.plan,
    });
  }

  async archive(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingPlanResponse> {
    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const context =
        await this.permissions.assertPlanManageableForUpdateInTransaction(
          tx,
          id,
          currentUser,
        );
      const archivedAt = new Date();
      const plan = await tx.weddingPlan.update({
        where: { id },
        data: { status: WeddingPlanStatus.ARCHIVED },
      });
      // The permission assertion above holds the plan's UPDATE lock. Invite
      // acceptance takes the same lifecycle lock before claiming an invite, so
      // either acceptance commits first or it observes the archived plan.
      await tx.planInvite.updateMany({
        where: {
          weddingPlanId: id,
          acceptedAt: null,
          declinedAt: null,
          revokedAt: null,
          expiresAt: { gt: archivedAt },
        },
        data: { revokedAt: archivedAt },
      });
      await this.recordPlanContribution(
        tx,
        context,
        plan,
        ContributionAction.STATUS_CHANGED,
      );
      await tx.contributorHistoryScope.upsert({
        where: { weddingPlanId: id },
        create: {
          weddingPlanId: id,
          status: ContributionScopeStatus.ARCHIVED,
          archivedAt: plan.updatedAt,
          historyCoverageStartsAt: plan.updatedAt,
        },
        update: {
          status: ContributionScopeStatus.ARCHIVED,
          archivedAt: plan.updatedAt,
        },
      });
      return { context, plan };
    });

    return this.toResponse(result.plan, {
      ...result.context,
      plan: result.plan,
    });
  }

  async setActive(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingPlanResponse> {
    const context = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const transactionalContext =
          await this.permissions.assertPlanReadableForUserUpdateInTransaction(
            tx,
            id,
            currentUser,
          );
        assertWeddingPlanWritable(transactionalContext.plan);
        await tx.user.update({
          where: { id: currentUser.id },
          data: { activeWeddingPlanId: id },
        });
        return transactionalContext;
      },
    );

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

    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      await assertActiveMutationActorForUpdateInTransaction(
        tx,
        currentUser.id,
      );
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
          estimatedBudget: this.optionalPositiveBudget(dto.estimatedBudget),
          currency: this.normalizedCurrency(dto.currency),
          onboardingPath: path,
          persona: dto.persona ?? null,
          onboardingCompletedAt: now,
        },
      });

      await this.createContributorHistoryScopeInTransaction(tx, plan);

      if (selectedCategories.length > 0) {
        await tx.budgetCategory.createMany({
          data: selectedCategories.map((name) => ({
            weddingPlanId: plan.id,
            name,
            normalizedName: this.normalizedCategoryName(name),
          })),
        });
      }

      const [budgetCategories, user] = await Promise.all([
        tx.budgetCategory.findMany({
          where: { weddingPlanId: plan.id },
          orderBy: { createdAt: "asc" },
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

  /** Imports the local plan and its unified money ledger exactly once. */
  async importLocalPlan(
    currentUser: AuthenticatedUser,
    dto: ImportLocalPlanDto,
  ): Promise<LocalPlanImportResponse> {
    const migrationId = this.requiredText(
      dto.clientMigrationId,
      "clientMigrationId",
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

    // Validate the complete ledger before opening the transaction. A bad row
    // must fail without creating even the plan shell.
    const costs = (dto.costs ?? []).map((cost, costIndex) => {
      const totalAmount = new Prisma.Decimal(
        this.requiredPositiveAmount(
          cost.totalAmount,
          `costs[${costIndex}].totalAmount`,
        ),
      );
      const payments = (cost.payments ?? []).map((payment, paymentIndex) => ({
        amount: new Prisma.Decimal(
          this.requiredPositiveAmount(
            payment.amount,
            `costs[${costIndex}].payments[${paymentIndex}].amount`,
          ),
        ),
        paidAt:
          this.parseDateField(
            payment.paidAt ?? undefined,
            `costs[${costIndex}].payments[${paymentIndex}].paidAt`,
          ) ?? now,
        method: this.optionalText(payment.method ?? undefined),
        note: this.optionalText(payment.note ?? undefined),
      }));
      const paidAmount = payments.reduce(
        (sum, payment) => sum.plus(payment.amount),
        new Prisma.Decimal(0),
      );
      if (paidAmount.gt(totalAmount)) {
        throw new BadRequestException(
          `costs[${costIndex}].payments exceed totalAmount`,
        );
      }
      const remainingAmount = totalAmount.minus(paidAmount);
      const paymentSchedules = (cost.paymentSchedules ?? []).map(
        (schedule, scheduleIndex) => {
          const dueDate = this.parseDateField(
            schedule.dueDate,
            `costs[${costIndex}].paymentSchedules[${scheduleIndex}].dueDate`,
          );
          if (!dueDate) {
            throw new BadRequestException(
              `costs[${costIndex}].paymentSchedules[${scheduleIndex}].dueDate is required`,
            );
          }
          const amount = new Prisma.Decimal(
            this.requiredPositiveAmount(
              schedule.amount,
              `costs[${costIndex}].paymentSchedules[${scheduleIndex}].amount`,
            ),
          );
          if (amount.gt(remainingAmount)) {
            throw new BadRequestException(
              `costs[${costIndex}].paymentSchedules[${scheduleIndex}].amount exceeds the remaining cost`,
            );
          }
          return {
            amount,
            dueDate,
            note: this.optionalText(schedule.note ?? undefined),
          };
        },
      );
      return {
        title: this.requiredText(cost.title, `costs[${costIndex}].title`),
        totalAmount,
        paidAmount,
        categoryName: this.requiredText(
          cost.categoryName,
          `costs[${costIndex}].categoryName`,
        ),
        partyName: this.optionalText(cost.partyName ?? undefined),
        partyPhone: PhoneNormalizer.normalizeOptional(cost.partyPhone),
        agreementDate: this.parseDateField(
          cost.agreementDate ?? undefined,
          `costs[${costIndex}].agreementDate`,
        ),
        note: this.optionalText(cost.note ?? undefined),
        payments,
        paymentSchedules,
      };
    });

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
        normalizedName: name.replace(/\s+/g, " "),
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

    const categoryNames = this.normalizeStringList(
      [...selectedCategories, ...costs.map((cost) => cost.categoryName)],
      50,
    );

    try {
      const plan = await runSerializableTransaction(this.prisma, async (tx) => {
        await assertActiveMutationActorForUpdateInTransaction(
          tx,
          currentUser.id,
        );
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
            estimatedBudget: this.optionalPositiveBudget(dto.estimatedBudget),
            currency: this.normalizedCurrency(dto.currency),
            onboardingPath: path,
            persona: dto.persona ?? null,
            onboardingCompletedAt: now,
            importMigrationId: migrationId,
          },
        });

        await this.createContributorHistoryScopeInTransaction(tx, createdPlan);

        if (categoryNames.length > 0) {
          await tx.budgetCategory.createMany({
            data: categoryNames.map((name) => ({
              weddingPlanId: createdPlan.id,
              name,
              normalizedName: this.normalizedCategoryName(name),
            })),
          });
        }

        const categories = await tx.budgetCategory.findMany({
          where: { weddingPlanId: createdPlan.id },
        });
        const categoryIdByName = new Map(
          categories.map((category) => [category.normalizedName, category.id]),
        );

        for (const [index, cost] of costs.entries()) {
          const budgetCategoryId = categoryIdByName.get(
            this.normalizedCategoryName(cost.categoryName),
          );
          if (!budgetCategoryId) {
            throw new BadRequestException(
              `costs[${index}].categoryName must map to a budget category`,
            );
          }
          const status = cost.paidAmount.isZero()
            ? WeddingCostStatus.OPEN
            : cost.paidAmount.eq(cost.totalAmount)
              ? WeddingCostStatus.PAID
              : WeddingCostStatus.PARTIALLY_PAID;
          await tx.weddingCost.create({
            data: {
              weddingPlanId: createdPlan.id,
              budgetCategoryId,
              title: cost.title,
              partyName: cost.partyName,
              partyPhone: cost.partyPhone,
              totalAmount: cost.totalAmount,
              paidAmount: cost.paidAmount,
              agreementDate: cost.agreementDate,
              status,
              note: cost.note,
              payments: {
                create: cost.payments.map((payment) => ({
                  amount: payment.amount,
                  paidAt: payment.paidAt,
                  method: payment.method,
                  note: payment.note,
                })),
              },
              paymentSchedules: {
                create: cost.paymentSchedules,
              },
            },
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
        error.code === "P2002"
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
    const [
      user,
      budgetCategories,
      costsCount,
      paymentsCount,
      paymentSchedulesCount,
      tasksCount,
      guestsCount,
    ] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({ where: { id: currentUser.id } }),
      this.prisma.budgetCategory.findMany({
        where: { weddingPlanId: plan.id },
        orderBy: { createdAt: "asc" },
      }),
      this.prisma.weddingCost.count({ where: { weddingPlanId: plan.id } }),
      this.prisma.costPayment.count({
        where: { weddingCost: { weddingPlanId: plan.id } },
      }),
      this.prisma.paymentSchedule.count({
        where: { weddingCost: { weddingPlanId: plan.id } },
      }),
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
        costs: costsCount,
        payments: paymentsCount,
        paymentSchedules: paymentSchedulesCount,
        tasks: tasksCount,
        guests: guestsCount,
      },
      alreadyImported,
    };
  }

  private requiredAmount(value: string | number, field: string): string {
    return requiredMoneyAmount(value, field);
  }

  private requiredPositiveAmount(
    value: string | number,
    field: string,
  ): string {
    const normalized = this.requiredAmount(value, field);
    if (Number(normalized) <= 0) {
      throw new BadRequestException(`${field} must be greater than zero`);
    }
    return normalized;
  }

  private parseDateField(
    value: string | undefined,
    field: string,
  ): Date | null {
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
      throw new BadRequestException(
        "weddingDate must be a valid ISO date string",
      );
    }
    return new Date(timestamp);
  }

  private optionalPositiveBudget(
    value: string | number | undefined,
  ): string | null {
    if (value === undefined) return null;
    const amount = new Prisma.Decimal(
      requiredMoneyAmount(value, "estimatedBudget"),
    );
    if (!amount.gt(0)) {
      throw new BadRequestException(
        "estimatedBudget must be greater than zero when set",
      );
    }
    return amount.toString();
  }

  private normalizedCurrency(value: string | undefined): string {
    const currency = (value?.trim() || "YER").toUpperCase();
    if (!/^[A-Z]{3}$/.test(currency)) {
      throw new BadRequestException("currency must be a three-letter ISO code");
    }
    return currency;
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
      const trimmed = value.trim().replace(/\s+/gu, " ");
      const key = this.normalizedCategoryName(trimmed);
      if (!trimmed || seen.has(key)) continue;
      normalized.push(trimmed);
      seen.add(key);
      if (normalized.length >= limit) break;
    }

    return normalized;
  }

  private normalizedCategoryName(value: string): string {
    return value.trim().replace(/\s+/gu, " ").toLocaleLowerCase("ar");
  }

  private defaultOnboardingPlanTitle(
    persona: WeddingPersona | undefined,
    city: string | null,
  ): string {
    const base =
      persona === WeddingPersona.BRIDE
        ? "Bride wedding plan"
        : persona === WeddingPersona.HELPER
          ? "Family wedding plan"
          : "Wedding plan";

    return city ? `${base} - ${city}` : base;
  }

  private accessiblePlansWhere(userId: string): Prisma.WeddingPlanWhereInput {
    return {
      OR: [{ ownerUserId: userId }, { sharedMembers: { some: { userId } } }],
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
    const context = await this.permissions.assertPlanReadable(
      plan.id,
      currentUser,
    );
    return this.toResponse(context.plan, context);
  }

  private async recordPlanContribution(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    plan: WeddingPlan,
    action: ContributionAction,
  ): Promise<void> {
    await this.contributionHistory.recordForContextInTransaction(tx, context, {
      section: ContributionSection.PLAN,
      entityType: ContributionEntityType.PLAN,
      entityId: plan.id,
      action,
      snapshot: buildContributionSnapshot(ContributionEntityType.PLAN, {
        planTitle: plan.title,
        weddingDate: plan.weddingDate,
        status: plan.status,
      }),
      dedupeKey: `plan:${plan.id}:${action.toLowerCase()}:${plan.updatedAt.toISOString()}`,
      requiredPermission: ContributionPermission.MANAGE_PLAN,
      occurredAt: plan.updatedAt,
    });
  }

  private async createContributorHistoryScopeInTransaction(
    tx: Prisma.TransactionClient,
    plan: Pick<WeddingPlan, "id" | "createdAt">,
  ): Promise<void> {
    await tx.contributorHistoryScope.create({
      data: {
        weddingPlanId: plan.id,
        status: ContributionScopeStatus.ACTIVE,
        historyCoverageStartsAt: plan.createdAt,
      },
    });
  }

  private toResponse(
    plan: WeddingPlan,
    context?: PlanAccessContext,
  ): WeddingPlanResponse {
    const canViewMoney = !context || this.permissions.canViewMoney(context);

    return {
      id: plan.id,
      ownerUserId: plan.ownerUserId,
      title: plan.title,
      city: plan.city,
      location: weddingLocationResponse(plan.location, plan.city),
      weddingDate: plan.weddingDate,
      priorities: plan.priorities,
      estimatedBudget: canViewMoney
        ? (plan.estimatedBudget?.toString() ?? null)
        : null,
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
      allocatedAmount: category.allocatedAmount?.toString() ?? null,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    };
  }
}
