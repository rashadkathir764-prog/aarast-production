import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { createHash } from "node:crypto";
import {
  AppRole,
  BudgetCategory,
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
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
  CostEntryKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { SafeUser } from "../modules/identity/public/safe-user";
import {
  ACTIVE_PLAN_PORT,
  type ActivePlanPort,
} from "../modules/identity/public/active-plan.port";
import {
  USER_READ_PORT,
  type UserReadPort,
} from "../modules/identity/public/user-read.port";
import {
  FINANCE_PORT,
  type FinancePort,
  riyadhDay,
} from "../modules/finance/public/finance.port";
import { GUESTS_PORT, type GuestsPort } from "../modules/guests/public/guests.port";
import { GUEST_NAME_MAX, GUEST_NOTES_MAX } from "../modules/guests/public/guest-text-limits";
import {
  attendanceFromStatus,
  statusFromAttendance,
} from "../modules/guests/public/guest-reply";
import { TASKS_PORT, type TasksPort } from "../modules/tasks/public/tasks.port";
import {
  TASK_DESCRIPTION_MAX,
  TASK_TITLE_MAX,
} from "../modules/tasks/public/task-text-limits";
import { withinCharacters } from "../shared-kernel/text/text-length";
import { daysBetween } from "../shared-kernel/voice/day-words";
import { shiftPlanEventDates } from "../modules/planning/infrastructure/plan-events.repository";
import { PhoneNormalizer } from "../shared-kernel/phone/phone-normalizer";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { requiredMoneyAmount } from "../shared-kernel/money/money";
import {
  COLLABORATION_HISTORY_PORT,
  type CollaborationHistoryPort as ContributionHistoryService,
} from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
import {
  CompleteOnboardingDto,
  PLAN_STARTER_ITEMS_MAX,
} from "../onboarding/dto/complete-onboarding.dto";
import { ImportLocalPlanDto } from "../onboarding/dto/import-local-plan.dto";
import { PrismaService } from "../platform/database/prisma.service";
import {
  archiveWeddingPlan,
  createWeddingPlan,
  findAccessiblePlanningWeddingPlan,
  findImportedWeddingPlan,
  listAccessibleWeddingPlans,
  listOwnedWeddingPlans,
  updateWeddingPlan,
} from "../modules/planning/infrastructure/wedding-plan.repository";
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
  /** D109. */
  estimatedAmount: string | null;
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
    @Inject(USER_READ_PORT)
    private readonly users: UserReadPort,
    @Inject(ACTIVE_PLAN_PORT)
    private readonly activePlan: ActivePlanPort,
    @Inject(FINANCE_PORT)
    private readonly finance: FinancePort,
    @Inject(TASKS_PORT)
    private readonly tasks: TasksPort,
    @Inject(GUESTS_PORT)
    private readonly guests: GuestsPort,
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
      const created = await createWeddingPlan(tx, {
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
      });
      if (selectedCategories.length > 0) {
        await this.finance.createBudgetCategoriesInTransaction(
          tx,
          created.id,
          selectedCategories,
        );
      }

      await this.contributionHistory.createHistoryScopeInTransaction(
        tx,
        created,
      );

      await this.activePlan.setActivePlanPointerInTransaction(
        tx,
        currentUser.id,
        created.id,
      );

      return created;
    });

    return this.toResponse(plan);
  }

  async findMine(
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse[]> {
    const plans = await listOwnedWeddingPlans(this.prisma, currentUser.id);

    return plans.map((plan) => this.toResponse(plan));
  }

  async findAccessible(
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse[]> {
    const memberPlanIds = await this.permissions.listMemberPlanIds(
      this.prisma,
      currentUser.id,
    );
    const plans = await listAccessibleWeddingPlans(
      this.prisma,
      currentUser.id,
      memberPlanIds,
    );

    // RA-BE-97: a plan closed to this reader (D63: its owner waits out the
    // account's deletion) is left out, as the account's contexts leave it
    // out; one such plan made the whole list a 404.
    const readable = await Promise.all(
      plans.map((plan) => this.readableResponseOrNull(plan, currentUser)),
    );
    return readable.filter(
      (plan): plan is WeddingPlanResponse => plan !== null,
    );
  }

  async findActive(
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse | null> {
    const activeWeddingPlanId = await this.users.getActivePlanPointer(
      this.prisma,
      currentUser.id,
    );

    if (activeWeddingPlanId) {
      const activePlan = await this.findAccessiblePlanningPlan(
        currentUser,
        activeWeddingPlanId,
      );
      if (activePlan) {
        // RA-BE-97: closed to this reader (D63) reads as no open plan, not
        // as a 404 the phone took for a missing item or an offline copy.
        return this.readableResponseOrNull(activePlan, currentUser);
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
      // RA-BE-96: whose wedding the plan is (groom or bride) sets the mahr's
      // side and what «معك» counts; only its owner says it. An editor's
      // request that carries it is refused, not quietly applied.
      if (dto.persona !== undefined && !context.isOwner) {
        throw new ForbiddenException({
          statusCode: 403,
          code: "PLAN_PERSONA_OWNER_ONLY",
          message: "صاحب الخطة بس يغيّر هذا.",
        });
      }
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

      const previousWeddingDate = context.plan.weddingDate;
      const plan = await updateWeddingPlan(tx, id, {
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
      });
      // RA-BE-72: a wedding moved from one day to another takes its dated
      // events with it («نرتب كل شيء على الموعد الجديد»); they stayed on
      // the old days in the wedding week, the reply page and the invite.
      if (previousWeddingDate && plan.weddingDate) {
        const days = daysBetween(previousWeddingDate, plan.weddingDate);
        if (days !== 0) {
          await shiftPlanEventDates(tx, id, days);
          // RA-BE-116: its open tasks too when the person said so, by the
          // date's own difference, with the right that moves the date.
          if (dto.moveOpenTasks === true) {
            await this.tasks.shiftOpenTaskDatesInTransaction(
              tx,
              id,
              days,
              currentUser.id,
            );
          }
        }
      }
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
      // RA-BE-70: archiving has no way back and revokes every invite, so it
      // is the owner's, as the app offers it; editing the plan is not enough.
      if (!context.isOwner) {
        throw new ForbiddenException({
          statusCode: 403,
          code: "PLAN_ARCHIVE_OWNER_ONLY",
          message: "أرشفة الخطة لصاحبها بس.",
        });
      }
      const archivedAt = new Date();
      const plan = await archiveWeddingPlan(tx, id);
      // The permission assertion above holds the plan's UPDATE lock. Invite
      // acceptance takes the same lifecycle lock before claiming an invite, so
      // either acceptance commits first or it observes the archived plan.
      await this.permissions.revokeLivePlanInvitesInTransaction(
        tx,
        id,
        archivedAt,
      );
      await this.recordPlanContribution(
        tx,
        context,
        plan,
        ContributionAction.STATUS_CHANGED,
      );
      await this.contributionHistory.archiveHistoryScopeInTransaction(
        tx,
        plan,
      );
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
        await this.activePlan.setActivePlanPointerInTransaction(
          tx,
          currentUser.id,
          id,
        );
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
      const plan = await createWeddingPlan(tx, {
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
      });

      await this.contributionHistory.createHistoryScopeInTransaction(tx, plan);

      const budgetCategories =
        await this.finance.createBudgetCategoriesInTransaction(
          tx,
          plan.id,
          selectedCategories,
        );
      if (dto.mahr) {
        await this.finance.recordMahrInTransaction(
          tx,
          plan.id,
          plan.persona,
          dto.mahr,
          now,
        );
      }
      const user = await this.activePlan.completeOnboardingInTransaction(
        tx,
        currentUser.id,
        {
          activeWeddingPlanId: plan.id,
          appRole:
            path === OnboardingPath.PROVIDER
              ? AppRole.PROVIDER
              : AppRole.WEDDING_USER,
          onboardingPath: path,
          persona: dto.persona ?? null,
          onboardingCompletedAt: now,
        },
      );

      return { budgetCategories, plan, user };
    });

    return {
      user: result.user,
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

    const payloadHash = localPlanImportHash(dto);
    const existing = await findImportedWeddingPlan(
      this.prisma,
      currentUser.id,
      migrationId,
    );
    if (existing) {
      return this.replayImport(existing, currentUser, payloadHash);
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
        // D106: checked against the dates below; a date that is not there
        // leaves it a plain payment.
        lowersScheduleIndex: payment.lowersScheduleIndex ?? null,
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
          const written = new Prisma.Decimal(
            this.requiredPositiveAmount(
              schedule.amount,
              `costs[${costIndex}].paymentSchedules[${scheduleIndex}].amount`,
            ),
          );
          // A reminder never asks for more than the whole agreement; one
          // above it (the agreement made smaller after) is taken at the
          // agreement's total instead of refusing the plan for ever.
          const amount = written.gt(totalAmount) ? totalAmount : written;
          // D106: a reminder day of its own between today and the due day;
          // one out of that range goes back to the default, never refused.
          const remindAt = this.parseDateField(
            schedule.remindAt ?? undefined,
            `costs[${costIndex}].paymentSchedules[${scheduleIndex}].remindAt`,
          );
          const remindDay = remindAt ? riyadhDay(remindAt) : null;
          return {
            amount,
            dueDate,
            note: this.optionalText(schedule.note ?? undefined),
            remindAt:
              remindDay !== null &&
              remindDay >= riyadhDay(now) &&
              remindDay <= riyadhDay(dueDate)
                ? remindAt
                : null,
            rescheduledFrom: this.parseDateField(
              schedule.rescheduledFrom ?? undefined,
              `costs[${costIndex}].paymentSchedules[${scheduleIndex}].rescheduledFrom`,
            ),
          };
        },
      )
        // RA-BE-63: a reminder is capped by what is left only when it is
        // written; a payment made straight on the agreement afterwards may
        // leave it above what is left, and it asks for the lesser
        // (scheduleAmountDue). The import takes the phone's plan in that
        // state, as the account does. A fully paid agreement keeps no pending
        // reminder (a full payment cancels them, R4).
        .filter(() => remainingAmount.gt(0));
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
        payments: payments.map((payment) => ({
          ...payment,
          lowersScheduleIndex:
            payment.lowersScheduleIndex !== null &&
            payment.lowersScheduleIndex < paymentSchedules.length
              ? payment.lowersScheduleIndex
              : null,
        })),
        paymentSchedules,
        // D59: who pays it, as the phone kept it.
        payer: cost.payer ?? null,
        payerName: this.optionalText(cost.payerName ?? undefined),
        // D107: an expense is paid in full; one that is not comes in as an
        // agreement rather than refusing the plan.
        entryKind:
          cost.entryKind === CostEntryKind.EXPENSE && paidAmount.equals(totalAmount)
            ? CostEntryKind.EXPENSE
            : CostEntryKind.AGREEMENT,
        estimateCover: cost.estimateCover,
        estimatePart:
          cost.estimatePart === null || cost.estimatePart === undefined || String(cost.estimatePart).trim() === ""
            ? null
            : new Prisma.Decimal(
                this.requiredPositiveAmount(cost.estimatePart, `costs[${costIndex}].estimatePart`),
              ),
      };
    });

    // D109: each item's own estimate and its allocation, by name.
    const itemAmounts = (dto.itemAmounts ?? []).map((item, index) => ({
      name: this.requiredText(item.name, `itemAmounts[${index}].name`),
      allocatedAmount: this.importedAmount(item.allocatedAmount, `itemAmounts[${index}].allocatedAmount`),
      estimatedAmount: this.importedAmount(item.estimatedAmount, `itemAmounts[${index}].estimatedAmount`),
    }));
    // The money in the phone's plan recorded (D103, D108).
    const fundingSources = (dto.fundingSources ?? []).map((source, index) => {
      const status = source.status ?? FundingSourceStatus.RECEIVED;
      return {
        kind: source.kind,
        sourceName: this.requiredText(source.sourceName, `fundingSources[${index}].sourceName`),
        sourcePhone: PhoneNormalizer.normalizeOptional(source.sourcePhone),
        contributorName: this.optionalText(source.contributorName ?? undefined),
        amount: new Prisma.Decimal(
          this.requiredPositiveAmount(source.amount, `fundingSources[${index}].amount`),
        ),
        status,
        receivedAt: this.parseDateField(source.receivedAt ?? undefined, `fundingSources[${index}].receivedAt`),
        expectedAt: this.parseDateField(source.expectedAt ?? undefined, `fundingSources[${index}].expectedAt`),
        note: this.optionalText(source.note ?? undefined),
        repayments: (source.repayments ?? []).map((repayment, repaymentIndex) => ({
          amount: new Prisma.Decimal(
            this.requiredPositiveAmount(
              repayment.amount,
              `fundingSources[${index}].repayments[${repaymentIndex}].amount`,
            ),
          ),
          dueDate: this.parseDateField(
            repayment.dueDate ?? undefined,
            `fundingSources[${index}].repayments[${repaymentIndex}].dueDate`,
          ),
          status: repayment.status ?? LoanRepaymentStatus.PLANNED,
          paidAt: this.parseDateField(
            repayment.paidAt ?? undefined,
            `fundingSources[${index}].repayments[${repaymentIndex}].paidAt`,
          ),
          note: this.optionalText(repayment.note ?? undefined),
        })),
      };
    });

    const tasks = (dto.tasks ?? []).map((task, index) => ({
      title: this.withinLength(
        this.requiredText(task.title, `tasks[${index}].title`),
        TASK_TITLE_MAX,
        `tasks[${index}].title`,
      ),
      description: this.withinLength(
        this.optionalText(task.description ?? undefined),
        TASK_DESCRIPTION_MAX,
        `tasks[${index}].description`,
      ),
      dueDate: this.parseDateField(
        task.dueDate ?? undefined,
        `tasks[${index}].dueDate`,
      ),
      taskCategory: this.withinLength(
        this.optionalText(task.taskCategory ?? undefined),
        60,
        `tasks[${index}].taskCategory`,
      ),
      reminderAt: this.parseDateField(
        task.reminderAt ?? undefined,
        `tasks[${index}].reminderAt`,
      ),
      status: task.status ?? WeddingTaskStatus.TODO,
      priority: task.priority ?? WeddingTaskPriority.MEDIUM,
    }));

    // RA-BE-83: a plan holds one guest per number. A second guest on a
    // number already taken (the family's number for «أبو محمد» and «أم
    // محمد») is kept by name, the number noted, instead of being dropped.
    const nameByPhone = new Map<string, string>();
    const guests = (dto.guests ?? []).map((guest, index) => {
      const name = this.withinLength(
        this.requiredText(guest.name, `guests[${index}].name`),
        GUEST_NAME_MAX,
        `guests[${index}].name`,
      );
      const givenPhone = PhoneNormalizer.normalizeOptional(guest.phone);
      const sharesWith = givenPhone ? nameByPhone.get(givenPhone) : undefined;
      if (givenPhone && sharesWith === undefined) {
        nameByPhone.set(givenPhone, name);
      }
      const phone = sharesWith === undefined ? givenPhone : null;
      const notes = this.optionalText(guest.notes ?? undefined);
      const sharedNote =
        sharesWith === undefined
          ? null
          : `رقمه نفس رقم ${sharesWith}: ${givenPhone}`;
      const keptNotes =
        sharedNote === null
          ? notes
          : [notes, sharedNote].filter(Boolean).join("\n");
      return {
        name,
        normalizedName: name.replace(/\s+/g, " "),
        phone,
        normalizedPhone: phone,
        side: guest.side ?? GuestSide.OTHER,
        // One reply in two columns (guest-reply.ts), as a guest added in
        // the account: a phone's «confirmed» sent as `status` only was kept
        // with no reply, and the list and the home disagreed on it.
        status:
          guest.status ??
          statusFromAttendance(guest.attendanceStatus) ??
          GuestStatus.INVITED,
        invitationStatus:
          guest.invitationStatus ?? GuestInvitationStatus.NOT_SENT,
        attendanceStatus:
          guest.attendanceStatus ?? attendanceFromStatus(guest.status),
        seatsCount: guest.seatsCount ?? 1,
        companionsCount: guest.companionsCount ?? 0,
        // The noted number never pushes the person's own words past the
        // limit: when there is no room for it, their words stay as written.
        notes: this.withinLength(
          keptNotes !== null && !withinCharacters(keptNotes, GUEST_NOTES_MAX)
            ? notes
            : keptNotes,
          GUEST_NOTES_MAX,
          `guests[${index}].notes`,
        ),
      };
    });

    // J1-13: every picked item and every agreement's item, none dropped: an
    // agreement whose item was cut off could not be imported at all. The
    // request's own caps bound how many there are.
    const importedItemNames = [
      ...selectedCategories,
      ...costs.map((cost) => cost.categoryName),
    ];
    const categoryNames = this.normalizeStringList(
      importedItemNames,
      importedItemNames.length,
    );

    try {
      const plan = await runSerializableTransaction(this.prisma, async (tx) => {
        await assertActiveMutationActorForUpdateInTransaction(
          tx,
          currentUser.id,
        );
        const createdPlan = await createWeddingPlan(tx, {
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
            importPayloadHash: payloadHash,
        });

        await this.contributionHistory.createHistoryScopeInTransaction(
          tx,
          createdPlan,
        );

        const categories =
          await this.finance.createBudgetCategoriesInTransaction(
            tx,
            createdPlan.id,
            categoryNames,
          );
        const categoryIdByName = new Map(
          categories.map((category) => [category.normalizedName, category.id]),
        );

        const importedCosts = costs.map((cost, index) => {
          const budgetCategoryId = categoryIdByName.get(
            this.normalizedCategoryName(cost.categoryName),
          );
          if (!budgetCategoryId) {
            throw new BadRequestException(
              `costs[${index}].categoryName must map to a budget category`,
            );
          }
          return {
            budgetCategoryId,
            title: cost.title,
            partyName: cost.partyName,
            partyPhone: cost.partyPhone,
            totalAmount: cost.totalAmount,
            paidAmount: cost.paidAmount,
            agreementDate: cost.agreementDate,
            note: cost.note,
            payments: cost.payments,
            paymentSchedules: cost.paymentSchedules,
            payer: cost.payer,
            payerName: cost.payerName,
            entryKind: cost.entryKind,
            estimateCover: cost.estimateCover,
            estimatePart: cost.estimatePart,
          };
        });
        // RA-BE-113: every agreement in a few statements (RA-BE-64's caps).
        await this.finance.createImportedCostsInTransaction(
          tx,
          createdPlan.id,
          importedCosts,
        );

        // D109: the items' estimates and allocations, by name.
        await this.finance.setImportedItemAmountsInTransaction(
          tx,
          createdPlan.id,
          createdPlan.estimatedBudget,
          itemAmounts.flatMap((item) => {
            const budgetCategoryId = categoryIdByName.get(
              this.normalizedCategoryName(item.name),
            );
            return budgetCategoryId
              ? [{ budgetCategoryId, allocatedAmount: item.allocatedAmount, estimatedAmount: item.estimatedAmount }]
              : [];
          }),
        );
        await this.finance.createImportedFundingSourcesInTransaction(
          tx,
          createdPlan.id,
          createdPlan.persona,
          fundingSources,
        );

        if (dto.mahr) {
          await this.finance.recordMahrInTransaction(
            tx,
            createdPlan.id,
            createdPlan.persona,
            dto.mahr,
            now,
          );
        }

        await this.tasks.createImportedTasksInTransaction(
          tx,
          createdPlan.id,
          tasks,
        );

        await this.guests.createImportedGuestsInTransaction(
          tx,
          createdPlan.id,
          guests,
        );

        await this.activePlan.completeOnboardingInTransaction(
          tx,
          currentUser.id,
          {
            activeWeddingPlanId: createdPlan.id,
            appRole:
              path === OnboardingPath.PROVIDER
                ? AppRole.PROVIDER
                : AppRole.WEDDING_USER,
            onboardingPath: path,
            persona: dto.persona ?? null,
            onboardingCompletedAt: now,
          },
        );

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
        const winner = await findImportedWeddingPlan(
          this.prisma,
          currentUser.id,
          migrationId,
        );
        if (winner) {
          return this.replayImport(winner, currentUser, payloadHash);
        }
      }
      throw error;
    }
  }

  /**
   * RA-BE-65: the same save again answers with the plan it made. A save with
   * the same id and other content means the first save reached the account
   * and its answer was lost, then the plan changed on the phone: answering
   * with the first plan would let the phone drop what changed since. It is
   * refused with its code, and the phone keeps its plan and asks.
   */
  private async replayImport(
    plan: WeddingPlan,
    currentUser: AuthenticatedUser,
    payloadHash: string,
  ): Promise<LocalPlanImportResponse> {
    if (plan.importPayloadHash !== null && plan.importPayloadHash !== payloadHash) {
      throw new ConflictException({
        statusCode: 409,
        code: "LOCAL_PLAN_SAVED_BEFORE",
        message:
          "خطتك انحفظت في حسابك من محاولة قبل، وتغيّرت على الجوال بعدها.",
      });
    }
    return this.buildImportResponse(plan, currentUser, true);
  }

  private async buildImportResponse(
    plan: WeddingPlan,
    currentUser: AuthenticatedUser,
    alreadyImported: boolean,
  ): Promise<LocalPlanImportResponse> {
    const [user, budgetCategories, moneyCounts, tasksCount, guestsCount] =
      await Promise.all([
        this.users.getSafeUser(this.prisma, currentUser.id),
        this.finance.listBudgetCategories(this.prisma, plan.id),
        this.finance.getPlanImportCounts(this.prisma, plan.id),
        this.tasks.countPlanTasks(this.prisma, plan.id),
        this.guests.countPlanGuests(this.prisma, plan.id),
      ]);
    if (!user) {
      throw new NotFoundException("User not found");
    }

    return {
      user,
      activeWeddingPlan: this.toResponse(plan),
      budgetCategories: budgetCategories.map((category) =>
        this.toBudgetCategoryResponse(category),
      ),
      imported: {
        costs: moneyCounts.costs,
        payments: moneyCounts.payments,
        paymentSchedules: moneyCounts.paymentSchedules,
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

  /** An imported amount that may be absent; zero stays zero. */
  private importedAmount(
    value: string | number | null | undefined,
    field: string,
  ): Prisma.Decimal | null {
    if (value === null || value === undefined || String(value).trim() === "") {
      return null;
    }
    return new Prisma.Decimal(this.requiredAmount(value, field));
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

  /**
   * RA-BE-15: the import's guests and tasks are held to the phone's lengths
   * here, their requests (`ImportLocalGuestDto`, `ImportLocalTaskDto`) being
   * byte-pinned by the R12B parity proof.
   */
  private withinLength<T extends string | null>(value: T, maximum: number, field: string): T {
    if (value !== null && !withinCharacters(value, maximum)) {
      throw new BadRequestException(`${field} must be at most ${maximum} characters`);
    }
    return value;
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
    // The request's cap (J1-13), so no picked item is silently dropped.
    return this.normalizeStringList(values, PLAN_STARTER_ITEMS_MAX);
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

  // A plan is accessible to its owner and to its shared members; the
  // membership is collaboration's and is read through its port.
  private async findAccessiblePlanningPlan(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingPlan | null> {
    const memberPlanIds = await this.permissions.listMemberPlanIds(
      this.prisma,
      currentUser.id,
    );
    return findAccessiblePlanningWeddingPlan(
      this.prisma,
      id,
      currentUser.id,
      memberPlanIds,
    );
  }

  private async readableResponseOrNull(
    plan: WeddingPlan,
    currentUser: AuthenticatedUser,
  ): Promise<WeddingPlanResponse | null> {
    try {
      return await this.toReadableResponse(plan, currentUser);
    } catch (error) {
      if (error instanceof NotFoundException) return null;
      throw error;
    }
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
      estimatedAmount: category.estimatedAmount?.toString() ?? null,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    };
  }
}

/**
 * RA-BE-65: what a local plan's import holds, as one fingerprint. Keys are
 * sorted and every list is compared as a set of its items, so the same plan
 * read again in another order is the same save; the migration id itself is
 * left out. Computed from the request as sent, before defaults (a payment's
 * time defaults to now) are filled in.
 */
export function localPlanImportHash(dto: ImportLocalPlanDto): string {
  const { clientMigrationId: _migrationId, ...content } = dto;
  return createHash("sha256").update(canonicalJson(content)).digest("hex");
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).sort().join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => item !== undefined)
      .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0));
    return `{${entries
      .map(([key, item]) => `${JSON.stringify(key)}:${canonicalJson(item)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}
