import {
  BadRequestException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { InsightsReadPorts } from '../insights-read-ports';
import { PrismaService } from '../../platform/database/prisma.service';
import { runRetryableTransaction } from '../../platform/database/serializable-transaction';
import { endOfRiyadhDay, startOfRiyadhDay } from '../../shared-kernel/time/business-day';
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort,
  type PlanAccessContext,
  seesWholePlan,
} from '../../modules/collaboration/public/collaboration-permission.port';
import {
  ASSISTANT_QUOTA_PORT,
  type AssistantQuotaPort,
} from '../../modules/identity/public/assistant-quota.port';
import {
  ASSISTANT_REPORT_PORT,
  type AssistantReportPort,
} from '../../modules/identity/public/assistant-report.port';
import type { AuthenticatedUser } from '../../modules/identity/public/identity-session.types';
import { localDate, monthStart } from './assistant-config';
import { AssistantModelError } from './assistant-model.client';
import { ASSISTANT_MODEL_PRICES, costMicroUsd } from './assistant-pricing';
import { AssistantRuntime } from './assistant-runtime';
import {
  ASSISTANT_SYSTEM_PROMPT,
  type AssistantKind,
  type AssistantMarketFacts,
  type AssistantPlanFacts,
  renderAssistantRequest,
} from './assistant.prompt';

const OPEN_TASKS_SHOWN = 15;
const QUOTES_SHOWN = 15;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface AssistantStatusResponse {
  /** The service has a key and a priced model. */
  enabled: boolean;
  /** The reader is the plan's owner or partner. */
  allowed: boolean;
  dailyLimit: number;
  remainingToday: number;
}

export interface AssistantAnswerResponse {
  kind: AssistantKind;
  answer: string;
  /** The model declined; `answer` then says so in Arabic. */
  declined: boolean;
  /** Market ranges for the plan's city were in the data. */
  marketDataAvailable: boolean;
  remainingToday: number;
}

function refusal(status: HttpStatus, code: string, message: string): HttpException {
  return new HttpException({ statusCode: status, code, message }, status);
}

/** Arabic and Latin city names compared loosely (أ/ا، ة/ه، ى/ي, spacing, case). */
function cityKey(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/[\s'’-]/g, '');
}

function money(value: Prisma.Decimal | null | undefined): string | null {
  return value === null || value === undefined ? null : value.toFixed(2);
}

/** A payer group without a written name, as the plan's people say it. */
function payerWord(payer: string | null): string {
  switch (payer) {
    case 'GROOM':
      return 'العريس';
    case 'BRIDE':
      return 'العروسة';
    case 'FAMILY':
      return 'الأهل';
    default:
      return 'شخص آخر';
  }
}

/**
 * The planning assistant (V1 checklist 4.12). It answers the plan's owner or
 * partner from the plan as they see it (never another account's private
 * costs or tasks, money only with money permission, quotes only with
 * provider permission) and from market price ranges, counts each question
 * against the account's daily limit and the service's monthly spending cap,
 * and stores no question or answer.
 */
@Injectable()
export class AssistantService {
  private readonly logger = new Logger(AssistantService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: CollaborationPermissionPort,
    private readonly ports: InsightsReadPorts,
    @Inject(ASSISTANT_QUOTA_PORT) private readonly quota: AssistantQuotaPort,
    private readonly runtime: AssistantRuntime,
    @Inject(ASSISTANT_REPORT_PORT) private readonly reports: AssistantReportPort,
  ) {}

  async status(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<AssistantStatusResponse> {
    const context = await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    const allowed = seesWholePlan(context);
    const config = this.runtime.model ? this.runtime.config : null;
    if (!config) return { enabled: false, allowed, dailyLimit: 0, remainingToday: 0 };
    const used = allowed
      ? await this.quota.questionsOn(currentUser.id, localDate(new Date()))
      : config.dailyLimit;
    return {
      enabled: true,
      allowed,
      dailyLimit: config.dailyLimit,
      remainingToday: Math.max(0, config.dailyLimit - used),
    };
  }

  async ask(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    input: { kind: AssistantKind; question: string | null; consent: boolean },
  ): Promise<AssistantAnswerResponse> {
    if (input.consent !== true) {
      throw refusal(
        HttpStatus.BAD_REQUEST,
        'ASSISTANT_CONSENT_REQUIRED',
        'The assistant sends plan data to an outside service only with consent',
      );
    }
    const question = input.question?.trim() || null;
    if (input.kind === 'QUESTION' && !question) {
      throw new BadRequestException('question must not be empty');
    }
    const context = await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    if (!seesWholePlan(context)) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'ASSISTANT_OWNER_OR_PARTNER_ONLY',
        message: 'The assistant serves the plan owner and partner',
      });
    }
    const model = this.runtime.model;
    const config = model ? this.runtime.config : null;
    if (!model || !config) {
      throw refusal(HttpStatus.SERVICE_UNAVAILABLE, 'ASSISTANT_DISABLED', 'The assistant is not set up');
    }

    const now = new Date();
    const day = localDate(now);
    const spent = await this.quota.spentSince(monthStart(day));
    if (spent >= config.monthlyBudgetMicroUsd) {
      this.logger.warn('Assistant monthly budget reached; questions are refused until next month');
      throw refusal(
        HttpStatus.SERVICE_UNAVAILABLE,
        'ASSISTANT_BUDGET_EXHAUSTED',
        'The assistant reached its monthly limit',
      );
    }

    const facts = await this.planFacts(context, currentUser.id, now);
    if (!(await this.quota.reserveQuestion(currentUser.id, day, config.dailyLimit))) {
      throw refusal(
        HttpStatus.TOO_MANY_REQUESTS,
        'ASSISTANT_DAILY_LIMIT',
        'The daily question limit is reached',
      );
    }

    let reply;
    try {
      reply = await model.ask({
        model: config.model,
        system: ASSISTANT_SYSTEM_PROMPT,
        userText: renderAssistantRequest(input.kind, facts, question),
      });
    } catch (error) {
      await this.quota.releaseQuestion(currentUser.id, day);
      if (error instanceof AssistantModelError) {
        if (error.failure === 'BUSY') {
          this.logger.warn(`Assistant model busy: ${error.detail}`);
          throw refusal(HttpStatus.SERVICE_UNAVAILABLE, 'ASSISTANT_BUSY', 'The assistant is busy');
        }
        this.logger.error(`Assistant model unavailable: ${error.detail}`);
        throw refusal(
          HttpStatus.SERVICE_UNAVAILABLE,
          'ASSISTANT_UNAVAILABLE',
          'The assistant is unavailable',
        );
      }
      throw error;
    }

    const cost = costMicroUsd(ASSISTANT_MODEL_PRICES[reply.model] ?? config.price, reply.usage);
    await this.quota.recordQuestionCost(currentUser.id, day, {
      inputTokens: reply.usage.inputTokens + reply.usage.cacheReadTokens + reply.usage.cacheWriteTokens,
      outputTokens: reply.usage.outputTokens,
      costMicroUsd: cost,
    });
    const warnAt = (config.monthlyBudgetMicroUsd * 8n) / 10n;
    if (spent < warnAt && spent + cost >= warnAt) {
      this.logger.warn('Assistant spending passed 80% of its monthly budget');
    }

    const declined = reply.stopReason === 'refusal' || reply.text.length === 0;
    const used = await this.quota.questionsOn(currentUser.id, day);
    return {
      kind: input.kind,
      answer: declined
        ? 'لا أستطيع المساعدة في هذا الطلب. جرّب سؤالًا آخر عن تخطيط عرسك.'
        : reply.text,
      declined,
      marketDataAvailable: facts.market.length > 0,
      remainingToday: Math.max(0, config.dailyLimit - used),
    };
  }

  /**
   * RA-ST-04 (D95): the reader reports an answer to the moderation team
   * (Play's AI-generated content policy). Whoever may ask may report; the
   * answer is the one the reader sent, since the assistant keeps none.
   */
  async reportAnswer(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    report: { kind: AssistantKind; question: string | null; answer: string; reason: string },
  ): Promise<{ reported: true }> {
    const context = await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    if (!seesWholePlan(context)) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'ASSISTANT_OWNER_OR_PARTNER_ONLY',
        message: 'The assistant serves the plan owner and partner',
      });
    }
    const recorded = await this.reports.recordAnswerReport(currentUser.id, {
      kind: report.kind,
      question: report.question?.trim() || null,
      answer: report.answer,
      reason: report.reason,
    });
    if (!recorded) {
      throw refusal(
        HttpStatus.TOO_MANY_REQUESTS,
        'ASSISTANT_REPORT_LIMIT',
        'Too many reports are waiting for review',
      );
    }
    return { reported: true };
  }

  /** The plan as the reader sees it, read in one snapshot through the owners' ports. */
  private planFacts(
    context: PlanAccessContext,
    readerUserId: string,
    now: Date,
  ): Promise<AssistantPlanFacts> {
    const plan = context.plan;
    const canViewMoney = this.permissions.canViewMoney(context);
    const canSeeQuotes = this.permissions.canManageProviders(context);
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const today = startOfRiyadhDay(now);
        const [guests, taskDashboard, openTasks] = await Promise.all([
          this.ports.guests.getPlanGuestCounters(tx, plan.id, null),
          this.ports.tasks.getPlanTaskDashboard(tx, {
            weddingPlanId: plan.id,
            scope: { kind: 'all', readerUserId },
            today,
            endOfToday: endOfRiyadhDay(today),
          }),
          this.ports.tasks.listUpcomingTasks(tx, plan.id, OPEN_TASKS_SHOWN, readerUserId),
        ]);
        const [moneyFacts, quotes, market] = await Promise.all([
          canViewMoney ? this.moneyFacts(tx, context, readerUserId) : null,
          canSeeQuotes ? this.quoteFacts(tx, plan.id) : null,
          this.marketFacts(tx, plan.city),
        ]);
        const weddingDay = plan.weddingDate ? startOfRiyadhDay(plan.weddingDate) : null;
        return {
          title: plan.title,
          city: plan.city,
          weddingDate: plan.weddingDate ? localDate(plan.weddingDate) : null,
          daysRemaining: weddingDay
            ? Math.round((weddingDay.getTime() - today.getTime()) / DAY_MS)
            : null,
          persona: plan.persona,
          currency: plan.currency,
          priorities: plan.priorities,
          money: moneyFacts,
          guests: {
            total: guests.total,
            confirmed: guests.confirmed,
            pending: guests.pending,
            declined: guests.declined,
          },
          tasks: {
            total: taskDashboard.totalTasks,
            completed: taskDashboard.completedTasks,
            overdue: taskDashboard.overdueTasks,
            open: openTasks.map((task) => ({
              title: task.title,
              dueDate: task.dueDate ? localDate(task.dueDate) : null,
            })),
          },
          quotes,
          market,
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  /**
   * The money as the app shows it (D59): finance's one money read, the one
   * `money-summary` serves. The wedding's budget counts the wedding's items
   * only; the mahr is its own line (the groom's agreement, or the bride's
   * mahr coming in, which is her private funding and so the owner's only).
   */
  private async moneyFacts(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    readerUserId: string,
  ): Promise<NonNullable<AssistantPlanFacts['money']>> {
    const picture = await this.ports.finance.readMoneyPicture(tx, {
      weddingPlanId: context.plan.id,
      persona: context.plan.persona,
      totalBudget: context.plan.estimatedBudget,
      scope: null,
      readerUserId,
      fundingVisible: context.isOwner,
    });
    const fixed = (value: string | null) =>
      value === null ? null : new Prisma.Decimal(value).toFixed(2);
    const mahr = picture.mahr;
    return {
      budgetTotal: fixed(picture.budget.total),
      committedTotal: fixed(picture.budget.confirmedCost) ?? '0.00',
      paidTotal: fixed(picture.budget.paid) ?? '0.00',
      paidByOwner: fixed(picture.costs.paidByOwner) ?? '0.00',
      paidByOthers: picture.payers
        .filter((group) => !group.ownerMoney && new Prisma.Decimal(group.paid).gt(0))
        .map((group) => ({
          payer: group.payerName ?? payerWord(group.payer),
          paid: fixed(group.paid) ?? '0.00',
        })),
      mahr: mahr
        ? {
            side: mahr.side,
            total: fixed(mahr.total) ?? '0.00',
            settled: fixed(mahr.settled) ?? '0.00',
            remaining: fixed(mahr.remaining) ?? '0.00',
            nextDueAt: mahr.nextDueAt ? localDate(mahr.nextDueAt) : null,
          }
        : null,
      categories: picture.categories
        .filter((category) => category.kind !== 'MAHR')
        .map((category) => ({
          name: category.name,
          allocated: fixed(category.allocatedAmount),
          committed: fixed(category.confirmedCost) ?? '0.00',
          paid: fixed(category.paid) ?? '0.00',
        })),
    };
  }

  private async quoteFacts(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<NonNullable<AssistantPlanFacts['quotes']>> {
    const offers = await this.ports.quotes.listPlanQuoteOffers(tx, weddingPlanId, QUOTES_SHOWN);
    const [providers, categories] = await Promise.all([
      this.ports.providers.getProviders(tx, [...new Set(offers.map((offer) => offer.providerId))]),
      this.ports.catalog.getCategories(tx, [
        ...new Set(offers.flatMap((offer) => (offer.serviceCategoryId ? [offer.serviceCategoryId] : []))),
      ]),
    ]);
    const providerNames = new Map(providers.map((provider) => [provider.id, provider.businessName]));
    const categoryNames = new Map(categories.map((category) => [category.id, category.nameAr]));
    return offers.map((offer) => ({
      provider: providerNames.get(offer.providerId) ?? 'مزود',
      service: offer.serviceTitle ?? offer.title,
      category: offer.serviceCategoryId ? categoryNames.get(offer.serviceCategoryId) ?? null : null,
      amount: money(offer.amount),
      currency: offer.currency,
      status: offer.status,
      validUntil: offer.validUntil ? localDate(offer.validUntil) : null,
    }));
  }

  /** Market ranges in the plan's own city only: prices in another city may be in another money zone. */
  private async marketFacts(
    tx: Prisma.TransactionClient,
    planCity: string | null,
  ): Promise<AssistantMarketFacts[]> {
    if (!planCity?.trim()) return [];
    const groups = await this.ports.providers.listMarketPriceGroups(tx);
    if (groups.length === 0) return [];
    const cities = await this.ports.catalog.getCities(tx, [
      ...new Set(groups.map((group) => group.cityId)),
    ]);
    const wanted = cityKey(planCity);
    const cityIds = new Set(
      cities
        .filter((city) => cityKey(city.nameAr) === wanted || (city.nameEn && cityKey(city.nameEn) === wanted))
        .map((city) => city.id),
    );
    const inCity = groups.filter((group) => cityIds.has(group.cityId));
    if (inCity.length === 0) return [];
    const categories = await this.ports.catalog.getCategories(tx, [
      ...new Set(inCity.map((group) => group.categoryId)),
    ]);
    const categoryNames = new Map(categories.map((category) => [category.id, category.nameAr]));
    return inCity.map((group) => ({
      category: categoryNames.get(group.categoryId) ?? 'فئة',
      currency: group.currency,
      providers: group.providers,
      min: group.min,
      median: group.median,
      max: group.max,
    }));
  }
}
