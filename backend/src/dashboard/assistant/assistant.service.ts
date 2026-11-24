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
  readerAddressForm,
  seesWholePlan,
} from '../../modules/collaboration/public/collaboration-permission.port';
import {
  ASSISTANT_CONSENT_PORT,
  type AssistantConsentPort,
} from '../../modules/identity/public/assistant-consent.port';
import {
  ASSISTANT_QUOTA_PORT,
  type AssistantQuotaPort,
} from '../../modules/identity/public/assistant-quota.port';
import {
  ASSISTANT_REPORT_PORT,
  type AssistantReportPort,
} from '../../modules/identity/public/assistant-report.port';
import type { AuthenticatedUser } from '../../modules/identity/public/identity-session.types';
import { issueAnswerId, verifiedAnswerId } from './assistant-answer-id';
import { localDate, monthStart } from './assistant-config';
import { AssistantModelError, type AssistantModelReply } from './assistant-model.client';
import { ASSISTANT_MODEL_PRICES, costMicroUsd, reservationMicroUsd } from './assistant-pricing';
import { AssistantRuntime } from './assistant-runtime';
import { ASSISTANT_REPORT_ANSWER_MAX } from './dto/report-assistant-answer.dto';
import {
  ASSISTANT_SYSTEM_PROMPT,
  type AssistantKind,
  type AssistantMarketFacts,
  type AssistantPlanFacts,
  renderAssistantRequest,
} from './assistant.prompt';

const QUOTES_SHOWN = 15;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface AssistantStatusResponse {
  /** The service has a key and a priced model. */
  enabled: boolean;
  /** The reader is the plan's owner or partner. */
  allowed: boolean;
  dailyLimit: number;
  remainingToday: number;
  /** RA-BE-161: when the reader agreed to send the plan's summary, or null. */
  consentedAt: string | null;
}

export interface AssistantConsentResponse {
  /** RA-BE-161: the stored record's date; null once taken back. */
  consentedAt: string | null;
}

/** RA-BE-161: the account's consent, read without any plan (w40). */
export interface AssistantAccountConsentResponse extends AssistantConsentResponse {
  /** Questions per account per day; 0 while the assistant is off. */
  dailyLimit: number;
}

export interface AssistantAnswerResponse {
  kind: AssistantKind;
  answer: string;
  /** The model declined; `answer` then says so in Arabic. */
  declined: boolean;
  /**
   * RA-BE-163: the model stopped at its token limit, so `answer` is only the
   * start of one; the app says so.
   */
  truncated: boolean;
  /** RA-BE-166: the server's id of this answer; a report must carry it. */
  answerId: string;
  /** Market ranges for the plan's city were in the data. */
  marketDataAvailable: boolean;
  remainingToday: number;
}

function refusal(status: HttpStatus, code: string, message: string): HttpException {
  return new HttpException({ statusCode: status, code, message }, status);
}

function assertOwnerOrPartner(context: PlanAccessContext): void {
  if (!seesWholePlan(context)) {
    throw new ForbiddenException({
      statusCode: 403,
      code: 'ASSISTANT_OWNER_OR_PARTNER_ONLY',
      message: 'The assistant serves the plan owner and partner',
    });
  }
}

function iso(value: Date | null): string | null {
  return value ? value.toISOString() : null;
}

/**
 * RA-BE-166: the answer as a report carries it: the phone cuts a longer one
 * to the report's bound (UTF-16 units, as Dart's `substring` and JS's
 * `slice` count), and the report's text is trimmed on arrival.
 */
function reportedAnswerText(answer: string): string {
  return answer.slice(0, ASSISTANT_REPORT_ANSWER_MAX).trim();
}

/** RA-BE-165: the caps reached, said to the reader. */
function capRefusal(outcome: 'SERVICE_BUDGET_REACHED' | 'USER_BUDGET_REACHED' | 'DAILY_LIMIT_REACHED'): HttpException {
  switch (outcome) {
    case 'SERVICE_BUDGET_REACHED':
      return refusal(
        HttpStatus.SERVICE_UNAVAILABLE,
        'ASSISTANT_BUDGET_EXHAUSTED',
        'The assistant reached its monthly limit',
      );
    case 'USER_BUDGET_REACHED':
      return refusal(
        HttpStatus.TOO_MANY_REQUESTS,
        'ASSISTANT_USER_MONTHLY_LIMIT',
        'This account reached its monthly assistant limit',
      );
    case 'DAILY_LIMIT_REACHED':
      return refusal(
        HttpStatus.TOO_MANY_REQUESTS,
        'ASSISTANT_DAILY_LIMIT',
        'The daily question limit is reached',
      );
  }
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

/**
 * The planning assistant (V1 checklist 4.12). It answers the plan's owner or
 * partner from the plan as they see it (never another account's private
 * costs or tasks, money only with money permission, quotes only with
 * provider permission) and from market price ranges, reserves each
 * question against the account's daily limit, its own monthly cap and the
 * service's monthly spending cap in one step (RA-BE-165), and stores no
 * question or answer. It sends only what the consent names
 * (RA-BE-160), and asks only with the asker's stored consent; a partner's
 * question carries the plan's money only with its owner's (RA-BE-161).
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
    @Inject(ASSISTANT_CONSENT_PORT) private readonly consent: AssistantConsentPort,
  ) {}

  async status(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<AssistantStatusResponse> {
    const context = await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    const allowed = seesWholePlan(context);
    const consentedAt = iso(await this.consent.consentedAt(currentUser.id));
    const config = this.runtime.model ? this.runtime.config : null;
    if (!config) return { enabled: false, allowed, dailyLimit: 0, remainingToday: 0, consentedAt };
    const used = allowed
      ? await this.quota.questionsOn(currentUser.id, localDate(new Date()))
      : config.dailyLimit;
    return {
      enabled: true,
      allowed,
      dailyLimit: config.dailyLimit,
      remainingToday: Math.max(0, config.dailyLimit - used),
      consentedAt,
    };
  }

  /**
   * RA-BE-161: the reader agrees, on the consent sheet, that the assistant
   * sends this plan's summary to the model. Whoever may ask may agree; the
   * record is the account's, with its first date.
   */
  async recordConsent(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<AssistantConsentResponse> {
    const context = await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    assertOwnerOrPartner(context);
    return { consentedAt: iso(await this.consent.recordConsent(currentUser.id)) };
  }

  /** RA-BE-161, w40: the reader takes the consent back; asking needs it again. */
  async withdrawConsent(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<AssistantConsentResponse> {
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    return this.withdrawAccountConsent(currentUser);
  }

  /**
   * RA-BE-161: the consent is the account's, so w40 reads it and takes it
   * back without any plan: a partner removed from the plan, or an account
   * whose plans are gone, still holds it until taken back.
   */
  async accountConsent(currentUser: AuthenticatedUser): Promise<AssistantAccountConsentResponse> {
    const config = this.runtime.model ? this.runtime.config : null;
    return {
      consentedAt: iso(await this.consent.consentedAt(currentUser.id)),
      dailyLimit: config?.dailyLimit ?? 0,
    };
  }

  async withdrawAccountConsent(currentUser: AuthenticatedUser): Promise<AssistantConsentResponse> {
    await this.consent.withdrawConsent(currentUser.id);
    return { consentedAt: null };
  }

  async ask(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    input: { kind: AssistantKind; question: string | null },
  ): Promise<AssistantAnswerResponse> {
    const question = input.question?.trim() || null;
    if (input.kind === 'QUESTION' && !question) {
      throw new BadRequestException('question must not be empty');
    }
    const context = await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    assertOwnerOrPartner(context);
    // RA-BE-161: the asker's stored consent, never a flag in the request.
    if (!(await this.consent.consentedAt(currentUser.id))) {
      throw refusal(
        HttpStatus.BAD_REQUEST,
        'ASSISTANT_CONSENT_REQUIRED',
        'The assistant sends plan data to an outside service only with consent',
      );
    }
    const model = this.runtime.model;
    const config = model ? this.runtime.config : null;
    if (!model || !config) {
      throw refusal(HttpStatus.SERVICE_UNAVAILABLE, 'ASSISTANT_DISABLED', 'The assistant is not set up');
    }

    const now = new Date();
    const day = localDate(now);
    const facts = await this.planFacts(context, currentUser, now);
    const userText = renderAssistantRequest(input.kind, facts, question);
    // RA-BE-165: the caps are checked and the call's most cost reserved in
    // one step, before the model is asked.
    const reserved = reservationMicroUsd(ASSISTANT_SYSTEM_PROMPT, userText);
    const reservation = await this.quota.reserveQuestion(currentUser.id, day, {
      dailyLimit: config.dailyLimit,
      monthStart: monthStart(day),
      reserveMicroUsd: reserved,
      serviceMonthlyBudgetMicroUsd: config.monthlyBudgetMicroUsd,
      userMonthlyBudgetMicroUsd: config.userMonthlyBudgetMicroUsd,
    });
    if (reservation.outcome !== 'RESERVED') {
      if (reservation.outcome === 'SERVICE_BUDGET_REACHED') {
        this.logger.warn('Assistant monthly budget reached; questions are refused until next month');
      }
      throw capRefusal(reservation.outcome);
    }

    let reply: AssistantModelReply;
    try {
      reply = await model.ask({ model: config.model, system: ASSISTANT_SYSTEM_PROMPT, userText });
    } catch (error) {
      if (error instanceof AssistantModelError && error.failure !== 'UNANSWERED') {
        // Refused before any answer: nothing was billed.
        await this.quota.releaseQuestion(currentUser.id, day, reserved);
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
      // No answer after the call may have gone out (a timeout, a dropped
      // connection, or any other failure): it may have been billed, so its
      // reserved cost stays spent; the question is given back.
      await this.quota.releaseQuestion(currentUser.id, day, 0n);
      if (error instanceof AssistantModelError) {
        this.logger.warn(`Assistant model gave no answer: ${error.detail}; its reserved cost is kept`);
        throw refusal(HttpStatus.SERVICE_UNAVAILABLE, 'ASSISTANT_BUSY', 'The assistant is busy');
      }
      throw error;
    }

    const cost = costMicroUsd(ASSISTANT_MODEL_PRICES[reply.model] ?? config.price, reply.usage);
    await this.quota.settleQuestion(currentUser.id, day, reserved, {
      inputTokens: reply.usage.inputTokens + reply.usage.cacheReadTokens + reply.usage.cacheWriteTokens,
      outputTokens: reply.usage.outputTokens,
      costMicroUsd: cost,
    });
    if (cost > reserved) {
      this.logger.error(`Assistant call cost ${cost} micro-dollars, above the ${reserved} it reserved`);
    }
    const spent = reservation.serviceSpentBefore;
    const warnAt = (config.monthlyBudgetMicroUsd * 8n) / 10n;
    if (spent < warnAt && spent + cost >= warnAt) {
      this.logger.warn('Assistant spending passed 80% of its monthly budget');
    }

    // RA-BE-163: stopped at its token limit, the text is only a start.
    const truncated = reply.stopReason === 'max_tokens';
    const declined = reply.stopReason === 'refusal' || (reply.text.length === 0 && !truncated);
    const answer = declined
      ? 'لا أستطيع المساعدة في هذا الطلب. جرّب سؤالًا آخر عن تخطيط عرسك.'
      : reply.text;
    const used = await this.quota.questionsOn(currentUser.id, day);
    return {
      kind: input.kind,
      answer,
      declined,
      truncated,
      answerId: issueAnswerId({
        userId: currentUser.id,
        weddingPlanId: context.plan.id,
        kind: input.kind,
        question,
        answer: reportedAnswerText(answer),
      }),
      marketDataAvailable: facts.market.length > 0,
      remainingToday: Math.max(0, config.dailyLimit - used),
    };
  }

  /**
   * RA-ST-04 (D95): the reader reports an answer to the moderation team
   * (Play's AI-generated content policy). Whoever may ask may report. The
   * assistant keeps no answer, so the phone sends it back; RA-BE-166: with
   * the server's answer id, and it is kept only when that id signs this
   * reader, plan, kind, question and text: the team reads what the
   * assistant wrote, never text the phone made.
   */
  async reportAnswer(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    report: {
      answerId: string;
      kind: AssistantKind;
      question: string | null;
      answer: string;
      reason: string;
    },
  ): Promise<{ reported: true }> {
    const context = await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    assertOwnerOrPartner(context);
    const question = report.question?.trim() || null;
    const answerId = verifiedAnswerId(report.answerId, {
      userId: currentUser.id,
      weddingPlanId: context.plan.id,
      kind: report.kind,
      question,
      answer: report.answer,
    });
    if (!answerId) {
      throw refusal(
        HttpStatus.BAD_REQUEST,
        'ASSISTANT_REPORT_ANSWER_UNKNOWN',
        'The reported answer is not one the assistant gave this reader',
      );
    }
    const recorded = await this.reports.recordAnswerReport(currentUser.id, {
      answerId,
      kind: report.kind,
      question,
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

  /**
   * The plan as the reader sees it, read in one snapshot through the owners'
   * ports, and only what the consent names (RA-BE-160). The plan's money
   * (its budget and the offers' prices) goes with a partner's question only
   * when the owner has agreed too (RA-BE-161).
   */
  private async planFacts(
    context: PlanAccessContext,
    reader: AuthenticatedUser,
    now: Date,
  ): Promise<AssistantPlanFacts> {
    const plan = context.plan;
    const readerUserId = reader.id;
    const ownerAgreed =
      context.isOwner || (await this.consent.consentedAt(plan.ownerUserId)) !== null;
    const moneyWithheld = !this.permissions.canViewMoney(context)
      ? ('NO_PERMISSION' as const)
      : !ownerAgreed
        ? ('OWNER_NO_CONSENT' as const)
        : null;
    const canSeeQuotes = this.permissions.canManageProviders(context);
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const today = startOfRiyadhDay(now);
        const [guests, taskDashboard] = await Promise.all([
          this.ports.guests.getPlanGuestCounters(tx, plan.id, null),
          this.ports.tasks.getPlanTaskDashboard(tx, {
            weddingPlanId: plan.id,
            scope: { kind: 'all', readerUserId },
            today,
            endOfToday: endOfRiyadhDay(today),
          }),
        ]);
        const [moneyFacts, quotes, market] = await Promise.all([
          moneyWithheld === null ? this.moneyFacts(tx, context, readerUserId) : null,
          canSeeQuotes ? this.quoteFacts(tx, plan.id, moneyWithheld === null) : null,
          this.marketFacts(tx, plan.city),
        ]);
        const weddingDay = plan.weddingDate ? startOfRiyadhDay(plan.weddingDate) : null;
        return {
          planOf: plan.persona === 'GROOM' || plan.persona === 'BRIDE' ? plan.persona : null,
          // RA-BE-164: the reader, not the plan's owner.
          reader: {
            role: context.isOwner ? ('OWNER' as const) : ('PARTNER' as const),
            form: readerAddressForm(reader, context),
          },
          city: plan.city,
          weddingDate: plan.weddingDate ? localDate(plan.weddingDate) : null,
          daysRemaining: weddingDay
            ? Math.round((weddingDay.getTime() - today.getTime()) / DAY_MS)
            : null,
          currency: plan.currency,
          money: moneyFacts,
          moneyWithheld,
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
   * RA-BE-160: the budget, its items and the mahr's total; nobody's name,
   * nothing of whose money paid, what the owner holds, his loans or the
   * mahr's handing over.
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
      // D114: the assistant reads the budget as the money tab does.
      budgetIncludesMahr: context.plan.budgetIncludesMahr,
      scope: null,
      readerUserId,
      fundingVisible: context.isOwner,
    });
    const fixed = (value: string | null) =>
      value === null ? null : new Prisma.Decimal(value).toFixed(2);
    return {
      budgetTotal: fixed(picture.budget.total),
      mahrInsideBudget: picture.budget.includesMahr === true,
      committedTotal: fixed(picture.budget.confirmedCost) ?? '0.00',
      paidTotal: fixed(picture.budget.paid) ?? '0.00',
      mahr: picture.mahr
        ? { side: picture.mahr.side, total: fixed(picture.mahr.total) ?? '0.00' }
        : null,
      items: picture.categories
        .filter((category) => category.kind !== 'MAHR')
        .map((category) => ({
          name: category.name,
          allocated: fixed(category.allocatedAmount),
          committed: fixed(category.confirmedCost) ?? '0.00',
          paid: fixed(category.paid) ?? '0.00',
        })),
    };
  }

  /**
   * RA-BE-103: the offers as the reader may see them. Their prices are money:
   * a reader who manages providers without the money right (a partner set
   * «المال لا») gets the offers without their prices, as every other offer
   * read does (RA-BE-73), and so does a partner whose owner has not agreed
   * (RA-BE-161). RA-BE-160: an offer is its category, price and status; the
   * provider's name and the service's own title stay out.
   */
  private async quoteFacts(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    showPrices: boolean,
  ): Promise<NonNullable<AssistantPlanFacts['quotes']>> {
    const offers = await this.ports.quotes.listPlanQuoteOffers(tx, weddingPlanId, QUOTES_SHOWN);
    const categories = await this.ports.catalog.getCategories(tx, [
      ...new Set(offers.flatMap((offer) => (offer.serviceCategoryId ? [offer.serviceCategoryId] : []))),
    ]);
    const categoryNames = new Map(categories.map((category) => [category.id, category.nameAr]));
    return offers.map((offer) => ({
      category: offer.serviceCategoryId ? categoryNames.get(offer.serviceCategoryId) ?? null : null,
      amount: showPrices ? money(offer.amount) : null,
      priceHidden: !showPrices,
      currency: offer.currency,
      status: offer.status,
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
