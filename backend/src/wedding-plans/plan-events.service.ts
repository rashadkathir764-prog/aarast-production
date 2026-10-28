import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  Prisma,
  type PlanEventTimeSlot,
  type PlanEventType,
  type WeddingPlan,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  isWeddingPlanWritable,
  type PlanAccessContext,
} from "../modules/collaboration/public/collaboration-permission.port";
import {
  assertEventFacts,
  cleanEventText,
  eventDayText,
  eventStartMinutes,
  parseEventDay,
  type PlanEventKind,
  type PlanEventParty,
  PlanEventRuleViolation,
  type PlanEventSlot,
  PLAN_EVENTS_MAX,
  planDayText,
  suggestedEventTypes,
} from "../modules/planning/domain/plan-event-rules";
import {
  countPlanEventRows,
  createPlanEventRow,
  deletePlanEventRow,
  findPlanEventRow,
  isUniqueViolation,
  listPlanEventRows,
  type PlanEventRow,
  type PlanEventWrite,
  updatePlanEventRow,
} from "../modules/planning/infrastructure/plan-events.repository";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";

/** One event as b12, b04, b05, y06 and y07 read it. */
export interface PlanEventView {
  /** Null for the main event before anything about it was saved. */
  id: string | null;
  type: PlanEventType;
  title: string | null;
  /** `YYYY-MM-DD`; the main event's is the plan's wedding date. */
  date: string | null;
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
  placeLabel: string | null;
  responsibleName: string | null;
  note: string | null;
  isMain: boolean;
}

export interface PlanEventsView {
  weddingPlanId: string;
  /** The plan's party: it decides the customary nights and their names. */
  party: PlanEventParty;
  /** The owner, or a member who may edit the plan, on a plan not archived. */
  canEdit: boolean;
  items: PlanEventView[];
  suggestions: PlanEventType[];
}

export interface PlanEventInput {
  title?: string | null;
  date?: string | null;
  timeSlot?: PlanEventTimeSlot | null;
  exactTime?: string | null;
  placeLabel?: string | null;
  responsibleName?: string | null;
  note?: string | null;
}

export interface CreatePlanEventInput extends PlanEventInput {
  type: PlanEventType;
}

/**
 * D65: the wedding's events (b12, b13). Planning owns them; every member
 * reads them (D52, the week and the day are not money), and the owner or a
 * member who may edit the plan changes them. The main event is the wedding
 * itself: its day is always the plan's date, so «أجّل العرس» moves it.
 */
@Injectable()
export class PlanEventsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
  ) {}

  list(currentUser: AuthenticatedUser, weddingPlanId: string): Promise<PlanEventsView> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const context = await this.permissions.assertPlanReadableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        const rows = await listPlanEventRows(tx, weddingPlanId);
        return this.view(context, rows);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    input: CreatePlanEventInput,
  ): Promise<PlanEventView> {
    return this.write(async (tx) => {
      const context = await this.permissions.assertPlanManageableForUpdateInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      if ((await countPlanEventRows(tx, weddingPlanId)) >= PLAN_EVENTS_MAX) {
        throw new PlanEventRuleViolation(
          "EVENT_LIMIT_REACHED",
          `A plan keeps at most ${PLAN_EVENTS_MAX} events`,
        );
      }
      const data = this.facts(input.type, input, null);
      const row = await createPlanEventRow(tx, weddingPlanId, input.type, data);
      return toView(row, context.plan);
    });
  }

  update(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    eventId: string,
    input: PlanEventInput,
  ): Promise<PlanEventView> {
    return this.write(async (tx) => {
      const context = await this.permissions.assertPlanManageableForUpdateInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      const current = await findPlanEventRow(tx, weddingPlanId, eventId);
      if (!current) throw new NotFoundException("Event not found");
      const data = this.facts(current.type, input, current);
      const row = await updatePlanEventRow(tx, eventId, data);
      return toView(row, context.plan);
    });
  }

  async remove(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    eventId: string,
  ): Promise<{ deleted: true }> {
    return this.write(async (tx) => {
      await this.permissions.assertPlanManageableForUpdateInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      const current = await findPlanEventRow(tx, weddingPlanId, eventId);
      if (!current) throw new NotFoundException("Event not found");
      if (current.type === "WEDDING") {
        throw new PlanEventRuleViolation(
          "EVENT_IS_MAIN",
          "The wedding itself stays; its day moves with the plan's date",
        );
      }
      await deletePlanEventRow(tx, eventId);
      return { deleted: true as const };
    });
  }

  private async write<T>(operation: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    try {
      return await runSerializableTransaction(this.prisma, operation);
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ConflictException({
          statusCode: 409,
          code: "EVENT_TYPE_EXISTS",
          message: "This event is already in the plan",
        });
      }
      if (error instanceof PlanEventRuleViolation) {
        const conflict =
          error.code === "EVENT_IS_MAIN" || error.code === "EVENT_LIMIT_REACHED";
        const body = {
          statusCode: conflict ? 409 : 400,
          code: error.code,
          message: error.message,
        };
        throw conflict ? new ConflictException(body) : new BadRequestException(body);
      }
      throw error;
    }
  }

  /** The stored facts after [input] (absent keeps, null clears). */
  private facts(
    type: PlanEventType,
    input: PlanEventInput,
    current: PlanEventRow | null,
  ): PlanEventWrite {
    const pick = <K extends keyof PlanEventInput>(
      key: K,
      fallback: PlanEventWrite[keyof PlanEventWrite],
    ) => (input[key] === undefined ? fallback : input[key]);
    const date =
      input.date === undefined
        ? (current?.date ?? null)
        : input.date === null
          ? null
          : parseEventDay(input.date);
    const timeSlot = (pick("timeSlot", current?.timeSlot ?? null) ??
      null) as PlanEventTimeSlot | null;
    // A slot other than «ساعة محددة» drops a stored hour.
    const exactTime =
      timeSlot === "EXACT"
        ? cleanEventText(pick("exactTime", current?.exactTime ?? null) as string | null)
        : input.exactTime
          ? input.exactTime
          : null;
    const data: PlanEventWrite = {
      title: cleanEventText(pick("title", current?.title ?? null) as string | null),
      date,
      timeSlot,
      exactTime,
      placeLabel: cleanEventText(
        pick("placeLabel", current?.placeLabel ?? null) as string | null,
      ),
      responsibleName: cleanEventText(
        pick("responsibleName", current?.responsibleName ?? null) as string | null,
      ),
      note: cleanEventText(pick("note", current?.note ?? null) as string | null),
    };
    assertEventFacts({
      type: type as PlanEventKind,
      title: data.title,
      date: data.date,
      timeSlot: data.timeSlot as PlanEventSlot | null,
      exactTime: data.exactTime,
    });
    return data;
  }

  private view(context: PlanAccessContext, rows: PlanEventRow[]): PlanEventsView {
    const plan = context.plan;
    const items = rows.map((row) => toView(row, plan));
    if (!items.some((item) => item.isMain)) {
      items.push({
        id: null,
        type: "WEDDING",
        title: null,
        date: plan.weddingDate ? planDayText(plan.weddingDate) : null,
        timeSlot: null,
        exactTime: null,
        placeLabel: null,
        responsibleName: null,
        note: null,
        isMain: true,
      });
    }
    items.sort(compareEvents);
    const party = (plan.persona ?? null) as PlanEventParty;
    return {
      weddingPlanId: plan.id,
      party,
      canEdit: this.permissions.canManagePlan(context) && isWeddingPlanWritable(plan),
      items,
      suggestions: suggestedEventTypes(
        party,
        rows.map((row) => row.type as PlanEventKind),
      ) as PlanEventType[],
    };
  }
}

function toView(row: PlanEventRow, plan: Pick<WeddingPlan, "weddingDate">): PlanEventView {
  const isMain = row.type === "WEDDING";
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    date: isMain
      ? plan.weddingDate
        ? planDayText(plan.weddingDate)
        : null
      : row.date
        ? eventDayText(row.date)
        : null,
    timeSlot: row.timeSlot,
    exactTime: row.exactTime,
    placeLabel: row.placeLabel,
    responsibleName: row.responsibleName,
    note: row.note,
    isMain,
  };
}

/** By day (an undated one last), then by the time of day it starts. */
function compareEvents(a: PlanEventView, b: PlanEventView): number {
  if (a.date !== b.date) {
    if (a.date === null) return 1;
    if (b.date === null) return -1;
    return a.date < b.date ? -1 : 1;
  }
  return (
    eventStartMinutes(a.timeSlot as PlanEventSlot | null, a.exactTime) -
    eventStartMinutes(b.timeSlot as PlanEventSlot | null, b.exactTime)
  );
}
