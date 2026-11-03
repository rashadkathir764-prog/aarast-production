import { createHash, randomBytes } from "node:crypto";
import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestStatus,
  NotificationPriority,
  NotificationType,
  type PlanEventTimeSlot,
  Prisma,
  WeddingPlanStatus,
  type WeddingPlan,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { noticeRoutes } from "../shared-kernel/routes/notification-routes";
import { gendered } from "../shared-kernel/voice/address-form";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  seesWholePlan,
} from "../modules/collaboration/public/collaboration-permission.port";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort,
} from "../modules/collaboration/public/collaboration-scope.port";
import {
  MEDIA_STORAGE_PORT,
  type MediaStoragePort,
} from "../modules/media/public/media-storage.port";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
  type ReadablePlanEvent,
} from "../modules/planning/public/plan-read.port";
import { weddingLocationResponse } from "../modules/planning/public/wedding-location";
import {
  type InvitationCardFields,
  type InvitationCardInput,
  isAcceptableMapUrl,
  mergeInvitationCard,
  planEventLabel,
  planEventTimeLabel,
} from "../modules/guests/domain/invitation-card";
import {
  findRsvpGuestByTokenHash,
  recordRsvpAnswer,
  storeRsvpTokenHash,
  type RsvpGuest,
} from "../modules/guests/infrastructure/guest-rsvp.repository";
import {
  findGuestById,
  findGuestEventInvite,
  findGuestInvitationCard,
  type GuestEventInviteRow,
  type GuestInvitationCardRow,
  listGuestEventInvites,
  lockGuestForUpdate,
  recordGuestEventAnswer,
  updateGuest,
  upsertGuestInvitationCard,
} from "../modules/guests/infrastructure/guests.repository";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";

/** A guest may bring at most this many companions through the link. */
export const RSVP_MAX_COMPANIONS = 20;

const DEFAULT_PUBLIC_ORIGIN = "https://aarast.shadowgardn.com";
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const CARD_PHOTO_PURPOSE = "guest-invitation-card" as const;

/** The wedding row's own time and venue (D65), when the owner saved them. */
export interface WeddingMoment {
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
  /** The time as the page says it («بعد العشاء», «الساعة 20:30»). */
  timeLabel: string | null;
  placeLabel: string | null;
}

/** D83: one event beyond the wedding, as the invited guest reads it. */
export interface PublicEventInvitation {
  id: string;
  label: string;
  date: string | null;
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
  timeLabel: string | null;
  placeLabel: string | null;
  attendanceStatus: GuestAttendanceStatus;
  companionsCount: number;
  respondedAt: Date | null;
}

export interface PublicInvitation {
  guestName: string;
  planTitle: string;
  weddingDate: string | null;
  locationLabel: string | null;
  attendanceStatus: GuestAttendanceStatus;
  companionsCount: number;
  maxCompanions: number;
  respondedAt: Date | null;
  /** D83: the wedding's time and venue, the card, and the other events. */
  wedding: WeddingMoment | null;
  card: InvitationCardFields | null;
  /** «يتشرف فلان بدعوتكم لحضور», in the plan's form; null without a host line. */
  hostPhrase: string | null;
  events: PublicEventInvitation[];
}

export function hostPhrase(
  hostLine: string | null | undefined,
  persona: string | null | undefined,
): string | null {
  const host = hostLine?.trim() ?? "";
  if (!host) return null;
  return persona === "BRIDE"
    ? `تتشرف ${host} بدعوتكن لحضور`
    : `يتشرف ${host} بدعوتكم لحضور`;
}

export interface InvitationCardResponse extends InvitationCardFields {
  weddingPlanId: string;
  updatedAt: Date | null;
}

/** What the message and the page need beyond the guest and the plan. */
interface InvitationContext {
  events: ReadablePlanEvent[];
  invites: GuestEventInviteRow[];
  card: GuestInvitationCardRow | null;
}

export function rsvpTokenHash(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

/** The public site the link opens on: INVITE_PUBLIC_ORIGIN, HTTPS only. */
export function rsvpPublicOrigin(
  environment: NodeJS.ProcessEnv = process.env,
): string {
  const raw = environment.INVITE_PUBLIC_ORIGIN?.trim() || DEFAULT_PUBLIC_ORIGIN;
  const parsed = new URL(raw);
  if (parsed.protocol !== "https:") {
    throw new Error("INVITE_PUBLIC_ORIGIN must be a public HTTPS origin");
  }
  return parsed.origin;
}

function formatDay(date: Date): string {
  return `${date.getUTCDate()}/${date.getUTCMonth() + 1}/${date.getUTCFullYear()}`;
}

export interface RsvpMessageInput {
  guestName: string;
  planTitle: string;
  weddingDate: Date | null;
  locationLabel: string | null;
  url: string;
  /** The plan's party: a bride's plan speaks to women (D55). */
  persona?: string | null;
  wedding?: WeddingMoment | null;
  card?: InvitationCardFields | null;
  /** D83: the events this guest is invited to beyond the wedding. */
  events?: ReadonlyArray<{
    label: string;
    date: Date | null;
    timeSlot: PlanEventTimeSlot | null;
    exactTime: string | null;
    placeLabel: string | null;
  }>;
  /** e08: the reminder for who has not answered, with their new link. */
  reminder?: boolean;
}

function whenLine(event: {
  date: Date | null;
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
}): string | null {
  const parts = [
    ...(event.date ? [formatDay(event.date)] : []),
    ...(planEventTimeLabel(event) ? [planEventTimeLabel(event)!] : []),
  ];
  return parts.length ? parts.join(" ") : null;
}

/**
 * The WhatsApp text the plan owner sends; the link is the guest's own. One
 * source for the words (D83): the app sends what the server built.
 */
export function buildRsvpMessage(input: RsvpMessageInput): string {
  const name = input.guestName.trim();
  if (input.reminder) {
    return [
      `أهلًا ${name}`,
      input.weddingDate
        ? `نذكرك ب${input.planTitle} يوم ${formatDay(input.weddingDate)}.`
        : `نذكرك ب${input.planTitle}.`,
      "هذا رابطك الجديد للرد بضغطة:",
      input.url,
    ].join("\n");
  }
  const host = hostPhrase(input.card?.hostLine, input.persona);
  const wedding = input.wedding ?? null;
  const weddingWhen = whenLine({
    date: input.weddingDate,
    timeSlot: wedding?.timeSlot ?? null,
    exactTime: wedding?.exactTime ?? null,
  });
  const weddingPlace = wedding?.placeLabel?.trim() || input.locationLabel;
  const events = (input.events ?? []).map((event) => {
    const when = whenLine(event);
    const place = event.placeLabel?.trim() ?? "";
    return `• ${event.label}${when ? `: ${when}` : ""}${place ? ` · ${place}` : ""}`;
  });
  return [
    `أهلًا ${name} 🌸`,
    host
      ? `${host} ${input.planTitle}.`
      : `يسعدنا دعوتك لحضور ${input.planTitle}.`,
    ...(input.card?.freeText ? [input.card.freeText] : []),
    ...(weddingWhen ? [`الموعد: ${weddingWhen}`] : []),
    ...(weddingPlace ? [`المكان: ${weddingPlace}`] : []),
    ...(events.length ? ["والدعوة تشمل أيضًا:", ...events] : []),
    ...(input.card?.mapUrl
      ? [`الموقع على الخريطة: ${input.card.mapUrl}`]
      : input.card?.address
        ? [`العنوان: ${input.card.address}`]
        : []),
    "نرجو تأكيد حضورك من الرابط:",
    input.url,
  ].join("\n");
}

/**
 * Personal invitation links and RSVP (V1 checklist 4.7). Whoever manages the
 * plan's guests sends each guest their own link over WhatsApp; the guest
 * answers on a public page without an account, and the guest list updates.
 * The link token is never stored, only its hash; a new link replaces the old.
 */
@Injectable()
export class GuestRsvpService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly scope: CollaborationScopePort,
    @Inject(PLAN_READ_PORT)
    private readonly plans: PlanReadPort,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
    @Inject(MEDIA_STORAGE_PORT)
    private readonly media: MediaStoragePort,
  ) {}

  async createInvitationLink(
    currentUser: AuthenticatedUser,
    guestId: string,
    options: { reminder?: boolean } = {},
  ) {
    const token = randomBytes(32).toString("base64url");
    const origin = rsvpPublicOrigin();
    return runSerializableTransaction(this.prisma, async (tx) => {
      const guest = await findGuestById(tx, guestId);
      if (!guest) throw new NotFoundException("Guest not found");
      const context = await this.permissions.assertGuestManageableInTransaction(
        tx,
        guest.weddingPlanId,
        currentUser,
      );
      // A contributor manages only the guests they added.
      if (!seesWholePlan(context) && context.sharedMember) {
        const own = await this.scope.qualifyingEntityIdsInTransaction(
          tx,
          guest.weddingPlanId,
          currentUser.id,
          [ContributionEntityType.GUEST],
          [ContributionAction.CREATED],
        );
        if (!own.includes(guest.id)) throw new NotFoundException("Guest not found");
      }
      if (!(await lockGuestForUpdate(tx, guest.id, guest.weddingPlanId))) {
        throw new NotFoundException("Guest not found");
      }
      const plan = await this.livePlan(tx, guest.weddingPlanId);
      const stored = await storeRsvpTokenHash(
        tx,
        guest.id,
        rsvpTokenHash(token),
        guest.invitationStatus === GuestInvitationStatus.NOT_SENT,
      );
      const url = new URL(`/rsvp/${token}`, origin).toString();
      const invitation = await this.invitationContext(tx, plan.id, guest.id);
      return {
        guestId: guest.id,
        url,
        phone: guest.normalizedPhone,
        invitationStatus: stored.invitationStatus,
        message: buildRsvpMessage({
          guestName: guest.name,
          planTitle: plan.title,
          weddingDate: plan.weddingDate,
          locationLabel: this.locationLabel(plan),
          url,
          persona: plan.persona,
          wedding: this.weddingMoment(invitation.events),
          card: invitation.card ? this.cardFields(invitation.card) : null,
          events: this.invitedEvents(invitation).map(({ event }) => ({
            label: planEventLabel(event),
            date: event.date,
            timeSlot: event.timeSlot,
            exactTime: event.exactTime,
            placeLabel: event.placeLabel,
          })),
          reminder: options.reminder === true,
        }),
      };
    });
  }

  async getInvitation(token: string): Promise<PublicInvitation> {
    const hash = this.hashOrThrow(token);
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const guest = await findRsvpGuestByTokenHash(tx, hash);
        if (!guest) throw this.linkNotFound();
        const plan = await this.livePlan(tx, guest.weddingPlanId);
        return this.publicView(
          guest,
          plan,
          await this.invitationContext(tx, plan.id, guest.id),
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  /** D83: the plan's invitation card, for whoever manages its guests. */
  async getInvitationCard(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<InvitationCardResponse> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        await this.permissions.assertGuestManageableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        return this.cardResponse(
          weddingPlanId,
          await findGuestInvitationCard(tx, weddingPlanId),
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  /**
   * D83: writes the card. A missing field keeps its value, null clears it.
   * The photo is the writer's own verified public upload, consumed by the
   * card; the one it replaces is released for deletion.
   */
  async setInvitationCard(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    input: InvitationCardInput,
  ): Promise<InvitationCardResponse> {
    const photoGiven = input.photoUrl !== undefined;
    // A blank photo clears it without a media check; a given one must be
    // the writer's own verified upload.
    const wantedPhoto = !photoGiven
      ? undefined
      : input.photoUrl?.trim()
        ? await this.media.verifyPublicMediaUrl(
            currentUser,
            input.photoUrl,
            CARD_PHOTO_PURPOSE,
          )
        : null;
    return runSerializableTransaction(this.prisma, async (tx) => {
      await this.permissions.assertGuestManageableInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      const current = await findGuestInvitationCard(tx, weddingPlanId);
      const next = mergeInvitationCard(
        current ? this.cardFields(current) : null,
        { ...input, ...(photoGiven ? { photoUrl: wantedPhoto } : {}) },
      );
      if (next.mapUrl && !isAcceptableMapUrl(next.mapUrl)) {
        throw new BadRequestException({
          statusCode: 400,
          code: "INVITATION_CARD_MAP_URL_INVALID",
          message: "رابط الخريطة لازم يكون رابط كامل يبدأ بـ https.",
        });
      }
      const photoChanged = photoGiven && (current?.photoUrl ?? null) !== next.photoUrl;
      if (photoChanged && current?.photoUrl) {
        await this.media.scheduleTargetDeletion(
          { type: "GUEST_INVITATION_CARD", id: current.id },
          tx,
        );
      }
      const saved = await upsertGuestInvitationCard(tx, weddingPlanId, next);
      if (photoChanged && next.photoUrl) {
        await this.media.consumePublicMediaUrl(
          currentUser,
          next.photoUrl,
          CARD_PHOTO_PURPOSE,
          { type: "GUEST_INVITATION_CARD", id: saved.id },
          tx,
        );
      }
      return this.cardResponse(weddingPlanId, saved);
    });
  }

  async respond(
    token: string,
    attendance: "CONFIRMED" | "DECLINED",
    companionsCount: number | undefined,
    planEventId?: string,
  ): Promise<PublicInvitation> {
    const hash = this.hashOrThrow(token);
    const companions = attendance === "DECLINED" ? 0 : (companionsCount ?? 0);
    if (
      !Number.isInteger(companions) ||
      companions < 0 ||
      companions > RSVP_MAX_COMPANIONS
    ) {
      throw new BadRequestException({
        statusCode: 400,
        code: "RSVP_INVALID_COMPANIONS",
        message: `Companions must be between 0 and ${RSVP_MAX_COMPANIONS}`,
      });
    }
    return runSerializableTransaction(this.prisma, async (tx) => {
      const guest = await findRsvpGuestByTokenHash(tx, hash);
      if (!guest) throw this.linkNotFound();
      if (!(await lockGuestForUpdate(tx, guest.id, guest.weddingPlanId))) {
        throw this.linkNotFound();
      }
      const plan = await this.livePlan(tx, guest.weddingPlanId);
      const respondedAt = new Date();
      const confirmed = attendance === "CONFIRMED";
      if (planEventId) {
        return this.respondToEvent(tx, guest, plan, planEventId, {
          confirmed,
          companions,
          respondedAt,
        });
      }
      const updated = await recordRsvpAnswer(tx, guest.id, {
        attendanceStatus: confirmed
          ? GuestAttendanceStatus.CONFIRMED
          : GuestAttendanceStatus.DECLINED,
        status: confirmed ? GuestStatus.CONFIRMED : GuestStatus.DECLINED,
        companionsCount: companions,
        respondedAt,
        invitationStatus:
          guest.invitationStatus === GuestInvitationStatus.NOT_SENT
            ? GuestInvitationStatus.SENT
            : guest.invitationStatus,
      });
      await this.notifications.createNotificationInTransaction(tx, {
        userId: plan.ownerUserId,
        weddingPlanId: plan.id,
        type: NotificationType.GUEST_RESPONDED,
        priority: NotificationPriority.NORMAL,
        // The plan's guests are its own side's (a bride's plan: women), and
        // its owner reads in that same form (D55), so the reader's form
        // names the guest too.
        title: confirmed
          ? gendered(`${guest.name} أكّد حضوره`, `${guest.name} أكّدت حضورها`)
          : gendered(`${guest.name} اعتذر عن الحضور`, `${guest.name} اعتذرت عن الحضور`),
        body:
          confirmed && companions > 0
            ? gendered(`ومعه ${companions} من المرافقين.`, `ومعها ${companions} من المرافقات.`)
            : "الرد وصل من رابط الدعوة.",
        entityType: "guest",
        entityId: guest.id,
        routeTarget: noticeRoutes.guest(plan.id, guest.id),
        data: { guestId: guest.id, weddingPlanId: plan.id, attendance },
        dedupeKey: `${plan.ownerUserId}:guest-responded:${guest.id}:${respondedAt.getTime()}`,
      });
      return this.publicView(
        updated,
        plan,
        await this.invitationContext(tx, plan.id, guest.id),
      );
    });
  }

  /** D83: the guest's reply to one event beyond the wedding. */
  private async respondToEvent(
    tx: Prisma.TransactionClient,
    guest: RsvpGuest,
    plan: WeddingPlan,
    planEventId: string,
    answer: { confirmed: boolean; companions: number; respondedAt: Date },
  ): Promise<PublicInvitation> {
    const invite = await findGuestEventInvite(tx, guest.id, planEventId);
    if (!invite) {
      throw new NotFoundException({
        statusCode: 404,
        code: "RSVP_EVENT_NOT_INVITED",
        message: "This invitation does not include that event",
      });
    }
    await recordGuestEventAnswer(tx, guest.id, planEventId, {
      attendanceStatus: answer.confirmed
        ? GuestAttendanceStatus.CONFIRMED
        : GuestAttendanceStatus.DECLINED,
      companionsCount: answer.companions,
      respondedAt: answer.respondedAt,
    });
    // Answering any event through the link means the invitation arrived.
    let current = guest;
    if (guest.invitationStatus === GuestInvitationStatus.NOT_SENT) {
      await updateGuest(tx, guest.id, {
        invitationStatus: GuestInvitationStatus.SENT,
      });
      current = { ...guest, invitationStatus: GuestInvitationStatus.SENT };
    }
    const context = await this.invitationContext(tx, plan.id, guest.id);
    const event = context.events.find((candidate) => candidate.id === planEventId);
    const label = event ? planEventLabel(event) : "المناسبة";
    await this.notifications.createNotificationInTransaction(tx, {
      userId: plan.ownerUserId,
      weddingPlanId: plan.id,
      type: NotificationType.GUEST_RESPONDED,
      priority: NotificationPriority.NORMAL,
      title: answer.confirmed
        ? gendered(
            `${guest.name} أكّد حضوره في ${label}`,
            `${guest.name} أكّدت حضورها في ${label}`,
          )
        : gendered(
            `${guest.name} اعتذر عن ${label}`,
            `${guest.name} اعتذرت عن ${label}`,
          ),
      body:
        answer.confirmed && answer.companions > 0
          ? gendered(
              `ومعه ${answer.companions} من المرافقين.`,
              `ومعها ${answer.companions} من المرافقات.`,
            )
          : "الرد وصل من رابط الدعوة.",
      entityType: "guest",
      entityId: guest.id,
      routeTarget: noticeRoutes.guest(plan.id, guest.id),
      data: {
        guestId: guest.id,
        weddingPlanId: plan.id,
        planEventId,
        attendance: answer.confirmed ? "CONFIRMED" : "DECLINED",
      },
      dedupeKey: `${plan.ownerUserId}:guest-responded:${guest.id}:${planEventId}:${answer.respondedAt.getTime()}`,
    });
    return this.publicView(current, plan, context);
  }

  private async invitationContext(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    guestId: string,
  ): Promise<InvitationContext> {
    const [events, invites, card] = await Promise.all([
      this.plans.listPlanEvents(tx, weddingPlanId),
      listGuestEventInvites(tx, [guestId]),
      findGuestInvitationCard(tx, weddingPlanId),
    ]);
    return { events, invites, card };
  }

  private weddingMoment(events: readonly ReadablePlanEvent[]): WeddingMoment | null {
    const wedding = events.find((event) => event.type === "WEDDING");
    return wedding
      ? {
          timeSlot: wedding.timeSlot,
          exactTime: wedding.exactTime,
          timeLabel: planEventTimeLabel(wedding),
          placeLabel: wedding.placeLabel,
        }
      : null;
  }

  /** The events this guest is invited to, in the plan's order; a deleted event drops out. */
  private invitedEvents(
    context: InvitationContext,
  ): Array<{ event: ReadablePlanEvent; invite: GuestEventInviteRow }> {
    const byEvent = new Map(context.invites.map((invite) => [invite.planEventId, invite]));
    return context.events.flatMap((event) => {
      const invite = byEvent.get(event.id);
      return invite && event.type !== "WEDDING" ? [{ event, invite }] : [];
    });
  }

  private publicEvents(context: InvitationContext): PublicEventInvitation[] {
    return this.invitedEvents(context).map(({ event, invite }) => ({
      id: event.id,
      label: planEventLabel(event),
      date: event.date ? event.date.toISOString().slice(0, 10) : null,
      timeSlot: event.timeSlot,
      exactTime: event.exactTime,
      timeLabel: planEventTimeLabel(event),
      placeLabel: event.placeLabel,
      attendanceStatus: invite.attendanceStatus,
      companionsCount: invite.companionsCount,
      respondedAt: invite.respondedAt,
    }));
  }

  private cardFields(card: GuestInvitationCardRow): InvitationCardFields {
    return {
      hostLine: card.hostLine,
      freeText: card.freeText,
      photoUrl: card.photoUrl,
      mapUrl: card.mapUrl,
      address: card.address,
    };
  }

  private cardResponse(
    weddingPlanId: string,
    card: GuestInvitationCardRow | null,
  ): InvitationCardResponse {
    return {
      weddingPlanId,
      ...(card
        ? this.cardFields(card)
        : { hostLine: null, freeText: null, photoUrl: null, mapUrl: null, address: null }),
      updatedAt: card?.updatedAt ?? null,
    };
  }

  private hashOrThrow(token: string): string {
    if (!TOKEN_PATTERN.test(token)) throw this.linkNotFound();
    return rsvpTokenHash(token);
  }

  private linkNotFound(): NotFoundException {
    return new NotFoundException({
      statusCode: 404,
      code: "RSVP_LINK_NOT_FOUND",
      message: "This invitation link is not valid",
    });
  }

  /** An archived or missing plan closes every link. */
  private async livePlan(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<WeddingPlan> {
    const plan = await this.plans.getPlan(tx, weddingPlanId);
    if (!plan || plan.status === WeddingPlanStatus.ARCHIVED) {
      throw this.linkNotFound();
    }
    return plan;
  }

  private locationLabel(plan: WeddingPlan): string | null {
    const location = weddingLocationResponse(plan.location, plan.city);
    return location?.mediumLabel ?? location?.displayLabel ?? null;
  }

  private publicView(
    guest: RsvpGuest,
    plan: WeddingPlan,
    context: InvitationContext,
  ): PublicInvitation {
    return {
      guestName: guest.name,
      planTitle: plan.title,
      weddingDate: plan.weddingDate
        ? plan.weddingDate.toISOString().slice(0, 10)
        : null,
      locationLabel: this.locationLabel(plan),
      attendanceStatus: guest.attendanceStatus,
      companionsCount: guest.companionsCount,
      maxCompanions: RSVP_MAX_COMPANIONS,
      respondedAt: guest.respondedAt,
      wedding: this.weddingMoment(context.events),
      card: context.card ? this.cardFields(context.card) : null,
      hostPhrase: hostPhrase(context.card?.hostLine, plan.persona),
      events: this.publicEvents(context),
    };
  }
}
