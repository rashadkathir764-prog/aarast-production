import { createHash, createHmac } from "node:crypto";
import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  GuestAttendanceStatus,
  GuestInvitationSendChannel,
  GuestInvitationSendKind,
  GuestInvitationSendStatus,
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
  type InvitationCardPhotoKind,
  isAcceptableMapUrl,
  mergeInvitationCard,
  planEventLabel,
  planEventTimeLabel,
} from "../modules/guests/domain/invitation-card";
import {
  type InvitationSendKind,
  type OccasionStanding,
  dueSend,
  occasionStanding,
  occasionsToName,
  type ToldOccasion,
  toldOccasions,
} from "../modules/guests/domain/guest-invitations";
import {
  createGuestInvitationSend,
  findGuestInvitationSend,
  findRsvpGuestByTokenHash,
  listGuestInvitationSends,
  markRsvpLinkOpened,
  recordRsvpAnswer,
  replaceRsvpLink,
  sendEvents,
  settleGuestInvitationSend,
  storeRsvpLinkHash,
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
import { imageTypeOf, type RsvpPreview } from "./rsvp-preview";

/** A guest may bring at most this many companions through the link. */
export const RSVP_MAX_COMPANIONS = 20;

const DEFAULT_PUBLIC_ORIGIN = "https://aarast.shadowgardn.com";
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const CARD_PHOTO_PURPOSE = "guest-invitation-card" as const;

/**
 * A text past this many characters drops its map links (they stay one tap
 * away on the guest's page): WhatsApp is not known to take a prefilled text
 * of any length, and a guest invited to many occasions makes a long one.
 */
export const RSVP_MESSAGE_SOFT_LIMIT = 1500;

/** The wedding row's own time and venue (D65), and its own place (D116). */
export interface WeddingMoment {
  /** D116: the wedding row's id, to answer it by. */
  id: string;
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
  /** The time as the page says it («بعد العشاء», «الساعة 20:30»). */
  timeLabel: string | null;
  placeLabel: string | null;
  mapUrl: string | null;
  address: string | null;
  /** D116: the guest said they were coming before the day, time or place changed. */
  needsReconfirm: boolean;
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
  mapUrl: string | null;
  address: string | null;
  attendanceStatus: GuestAttendanceStatus;
  companionsCount: number;
  respondedAt: Date | null;
  needsReconfirm: boolean;
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
  /** D116: the plan's side: a bride's plan speaks to women guests. */
  persona: "GROOM" | "BRIDE" | null;
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
  /**
   * 6a: the bucket keeps the photo private, so the members' own preview
   * reads it through this short-lived signed link; `photoUrl` stays the
   * saved address (the card's identity, what a write sends back).
   */
  photoReadUrl: string | null;
  updatedAt: Date | null;
}

/** D116: a prepared send: the text, the guest's link, and what it names. */
export interface InvitationSendResponse {
  guestId: string;
  /** Settle it with what the person says happened. */
  sendId: string;
  url: string;
  phone: string | null;
  /** Before D116 the phone read it; it no longer changes on preparing. */
  invitationStatus: GuestInvitationStatus;
  message: string;
  kind: InvitationSendKind;
  events: Array<{ planEventId: string; version: number }>;
}

/** The invitation's own sentence, in the message and in the link preview. */
function invitationLine(host: string | null, of: string): string {
  return host ? `${host} ${of}` : `يسعدنا دعوتك لحضور ${of}`;
}

/** What the message and the page need beyond the guest and the plan. */
interface InvitationContext {
  events: ReadablePlanEvent[];
  invites: GuestEventInviteRow[];
  card: GuestInvitationCardRow | null;
}

/**
 * D116: one occasion a guest is invited to, the wedding among them, with
 * their answer: the one shape the text, the page and the send all read.
 */
interface GuestOccasion {
  id: string;
  isWedding: boolean;
  label: string;
  date: Date | null;
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
  placeLabel: string | null;
  address: string | null;
  mapUrl: string | null;
  version: number;
  attendanceStatus: GuestAttendanceStatus;
  companionsCount: number;
  respondedAt: Date | null;
  answeredVersion: number | null;
}

/** Where the guest stands with [occasion], given what they were told of it. */
function standingOf(
  occasion: GuestOccasion,
  told: ToldOccasion | undefined,
): OccasionStanding {
  return occasionStanding(
    { ...occasion, planEventId: occasion.id },
    { planEventId: occasion.id, version: occasion.version },
    told,
  );
}

/**
 * RA-BE-87: whether a reply changes what the guest had answered (to the
 * wedding or to one event). The owner is told of a change only: a guest who
 * opens the page again and taps the same answer sends no new notice or push.
 */
function replyChanged(
  before: { attendanceStatus: GuestAttendanceStatus; companionsCount: number },
  after: { attendanceStatus: GuestAttendanceStatus; companionsCount: number },
): boolean {
  return (
    before.attendanceStatus !== after.attendanceStatus ||
    before.companionsCount !== after.companionsCount
  );
}

export function rsvpTokenHash(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

/**
 * D116: the key the guests' stable links are derived with, itself derived
 * from the server's signing secret (as the admins' remembered devices are),
 * so no new secret is to be kept or moved. Rotating that secret gives every
 * guest a new link on their next send; a link already sent keeps opening,
 * since only its hash is looked up.
 */
function rsvpLinkKey(environment: NodeJS.ProcessEnv): Buffer {
  const secret = environment.JWT_SECRET?.trim();
  if (!secret) {
    if (environment.NODE_ENV === "production") {
      throw new ServiceUnavailableException(
        "Invitation links are temporarily unavailable",
      );
    }
    return createHash("sha256").update("aarast-local-rsvp-link-key-v1").digest();
  }
  return createHmac("sha256", secret).update("aarast-rsvp-link-key-v1", "utf8").digest();
}

/**
 * D116: the guest's one link at [version]: the same on every send, so a
 * reminder or an invitation to one more occasion opens the page the first
 * message opened. 32 bytes, base64url: the 43 characters a link carries.
 */
export function rsvpLinkToken(
  guestId: string,
  version: number,
  environment: NodeJS.ProcessEnv = process.env,
): string {
  return createHmac("sha256", rsvpLinkKey(environment))
    .update(`rsvp-link:${guestId}:${version}`, "utf8")
    .digest("base64url");
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

/** D116: one occasion as the text names it. */
export interface RsvpOccasionText {
  label: string;
  isWedding: boolean;
  date: Date | null;
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
  placeLabel: string | null;
  address: string | null;
  mapUrl: string | null;
}

export interface RsvpMessageInput {
  guestName: string;
  planTitle: string;
  url: string;
  /** The plan's party: a bride's plan speaks to women (D55). */
  persona?: string | null;
  card?: Pick<InvitationCardFields, "hostLine" | "freeText"> | null;
  /** D116: the occasions this text names, the wedding first when it is one. */
  occasions: ReadonlyArray<RsvpOccasionText>;
  /** D116: what the text is: an invitation, one more occasion, a change, a reminder. */
  kind?: InvitationSendKind;
  /**
   * A reminder to a guest already coming says the occasion and keeps the
   * link for a change of mind; it does not ask for an answer again.
   */
  confirmed?: boolean;
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

/** «العرس والغداء والسمرة». */
function joinLabels(labels: readonly string[]): string {
  return labels.join(" و");
}

function occasionLines(
  occasion: RsvpOccasionText,
  heading: boolean,
  withMap: boolean,
): string[] {
  const when = whenLine(occasion);
  const place = occasion.placeLabel?.trim() ?? "";
  const address = occasion.address?.trim() ?? "";
  return [
    ...(heading ? [`*${occasion.label}*`] : []),
    ...(when ? [`الموعد: ${when}`] : []),
    ...(place ? [`المكان: ${place}`] : []),
    ...(address ? [`العنوان: ${address}`] : []),
    ...(withMap && occasion.mapUrl ? [`الموقع على الخريطة: ${occasion.mapUrl}`] : []),
  ];
}

function composeMessage(input: RsvpMessageInput, withMaps: boolean): string {
  const kind = input.kind ?? "INVITATION";
  const name = input.guestName.trim();
  const occasions = input.occasions;
  const many = occasions.length > 1;
  const labels = joinLabels(occasions.map((occasion) => occasion.label));
  // A text of one occasion beyond the wedding names it within the wedding.
  const only = occasions.length === 1 ? occasions[0] : null;
  const of = only && !only.isWedding ? `${only.label} في ${input.planTitle}` : input.planTitle;
  const blocks = occasions
    .map((occasion) => occasionLines(occasion, many, withMaps))
    .filter((lines) => lines.length > 0);
  const details = blocks.flatMap((lines, index) => (index === 0 ? lines : ["", ...lines]));
  const mapsMoved =
    !withMaps && occasions.some((occasion) => occasion.mapUrl)
      ? ["ومواقع الخريطة في الرابط."]
      : [];
  let opening: string[];
  let ask: string;
  switch (kind) {
    case "REMINDER":
      opening = [`أهلًا ${name}`, `نذكرك ب${of}.`];
      ask = input.confirmed
        ? "ننتظرك. ولو تغيّر شي، هذا رابطك:"
        : "هذا رابطك للرد بضغطة:";
      break;
    case "ADDITION":
      opening = [
        `أهلًا ${name} 🌸`,
        `ويسعدنا حضورك أيضًا في ${labels}، ضمن ${input.planTitle}.`,
      ];
      ask = "نرجو تأكيد حضورك من الرابط:";
      break;
    case "CHANGE":
      opening = [
        `أهلًا ${name} 🌸`,
        `تغيّر موعد أو مكان ${labels} في ${input.planTitle}، وهذا الجديد.`,
      ];
      // «من جديد» only to who confirmed before the change.
      ask = input.confirmed
        ? "نرجو تأكيد حضورك من جديد من الرابط:"
        : "نرجو تأكيد حضورك من الرابط:";
      break;
    default: {
      const host = hostPhrase(input.card?.hostLine, input.persona);
      opening = [
        `أهلًا ${name} 🌸`,
        `${invitationLine(host, of)}.`,
        ...(input.card?.freeText ? [input.card.freeText] : []),
      ];
      ask = many
        ? "نرجو تأكيد حضورك لكل مناسبة من الرابط:"
        : "نرجو تأكيد حضورك من الرابط:";
    }
  }
  return [
    ...opening,
    ask,
    input.url,
    ...mapsMoved,
    ...(details.length ? ["", ...details] : []),
  ].join("\n");
}

/**
 * The WhatsApp text the plan owner sends; the link is the guest's own. One
 * source for the words (D83): the app sends what the server built, and its
 * preview is held to the same words by guest_invitation_fixtures.json.
 *
 * WhatsApp previews the first link of a text, so the guest's link comes
 * before every occasion and its map link (6b): a map link first showed the
 * hall's photos instead of the invitation. D116: each occasion the text
 * names says its day, time, place, address and map link; the link is how the
 * guest answers, never a stand-in for what the invitation says.
 */
export function buildRsvpMessage(input: RsvpMessageInput): string {
  const full = composeMessage(input, true);
  return full.length > RSVP_MESSAGE_SOFT_LIMIT ? composeMessage(input, false) : full;
}

/**
 * Personal invitation links and RSVP (V1 checklist 4.7). Whoever manages the
 * plan's guests sends each guest their own link over WhatsApp; the guest
 * answers on a public page without an account, and the guest list updates.
 * D116: the link is one and stable per guest (only its hash is stored); each
 * send is recorded with the occasions it named, and is sent only when the
 * person says so.
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

  /**
   * D116: prepares one send to one guest: the text of [options.kind] (by
   * default what the guest is due), naming every occasion they are invited
   * to or only [options.planEventId], and their stable link. Nothing is
   * marked sent: the person says it was, through [settleInvitationSend].
   */
  async createInvitationLink(
    currentUser: AuthenticatedUser,
    guestId: string,
    options: {
      reminder?: boolean;
      kind?: InvitationSendKind;
      planEventId?: string;
      channel?: GuestInvitationSendChannel;
    } = {},
  ): Promise<InvitationSendResponse> {
    const origin = rsvpPublicOrigin();
    return runSerializableTransaction(this.prisma, async (tx) => {
      const guest = await this.manageableGuest(tx, currentUser, guestId);
      const plan = await this.livePlan(tx, guest.weddingPlanId);
      const token = rsvpLinkToken(guest.id, guest.rsvpLinkVersion);
      const linkHash = rsvpTokenHash(token);
      const stored =
        guest.rsvpLinkHash === linkHash
          ? guest
          : await storeRsvpLinkHash(tx, guest.id, linkHash);
      const url = new URL(`/rsvp/${token}`, origin).toString();
      const context = await this.invitationContext(tx, plan.id, guest.id);
      const occasions = this.guestOccasions(plan, stored, context);
      const scope = options.planEventId
        ? occasions.filter((occasion) => occasion.id === options.planEventId)
        : occasions;
      if (scope.length === 0) {
        throw new ConflictException({
          statusCode: 409,
          code: "GUEST_EVENT_NOT_INVITED",
          message: "الضيف مش مدعو لهذي المناسبة.",
        });
      }
      const sends = await listGuestInvitationSends(tx, [guest.id]);
      const told = toldOccasions(
        sends
          .filter((row) => row.status === GuestInvitationSendStatus.SENT)
          .map((row) => ({
            kind: row.kind,
            sentAt: row.settledAt ?? row.createdAt,
            events: sendEvents(row),
          })),
      );
      const standings = scope.map((occasion) => ({
        planEventId: occasion.id,
        standing: standingOf(occasion, told.get(occasion.id)),
      }));
      const kind: InvitationSendKind =
        options.kind ??
        (options.reminder
          ? "REMINDER"
          : (dueSend(standings, told.size > 0) ?? "INVITATION"));
      // Asked of a guest who is not due it (sent again by hand): it names
      // what is in scope, as the first invitation did.
      const named = new Set(occasionsToName(kind, standings));
      const toName = named.size
        ? scope.filter((occasion) => named.has(occasion.id))
        : scope;
      const send = await createGuestInvitationSend(tx, {
        weddingPlanId: plan.id,
        guestId: guest.id,
        kind: kind as GuestInvitationSendKind,
        planEventId: options.planEventId ?? null,
        events: toName.map((occasion) => ({
          planEventId: occasion.id,
          version: occasion.version,
        })),
        channel: options.channel ?? GuestInvitationSendChannel.WHATSAPP,
        createdByUserId: currentUser.id,
      });
      return {
        guestId: guest.id,
        sendId: send.id,
        url,
        phone: guest.normalizedPhone,
        invitationStatus: stored.invitationStatus,
        message: buildRsvpMessage({
          guestName: guest.name,
          planTitle: plan.title,
          url,
          persona: plan.persona,
          card: context.card,
          occasions: toName,
          kind,
          confirmed: toName.every(
            (occasion) => occasion.attendanceStatus === GuestAttendanceStatus.CONFIRMED,
          ),
        }),
        kind,
        events: sendEvents(send),
      };
    });
  }

  /**
   * D116: what the person says happened to a prepared send: sent, or not.
   * Only then is the guest taken as told (and, for a client from before
   * D116, marked invited).
   */
  async settleInvitationSend(
    currentUser: AuthenticatedUser,
    sendId: string,
    outcome: { sent: boolean; channel?: GuestInvitationSendChannel },
  ) {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const send = await findGuestInvitationSend(tx, sendId);
      if (!send) throw new NotFoundException("Send not found");
      const guest = await this.manageableGuest(tx, currentUser, send.guestId);
      const settled = await settleGuestInvitationSend(
        tx,
        send.id,
        outcome.sent ? GuestInvitationSendStatus.SENT : GuestInvitationSendStatus.NOT_SENT,
        outcome.channel,
        new Date(),
      );
      if (outcome.sent && guest.invitationStatus === GuestInvitationStatus.NOT_SENT) {
        await updateGuest(tx, guest.id, { invitationStatus: GuestInvitationStatus.SENT });
      }
      return {
        id: settled.id,
        guestId: settled.guestId,
        kind: settled.kind,
        planEventId: settled.planEventId,
        status: settled.status,
        events: sendEvents(settled),
        settledAt: settled.settledAt,
      };
    });
  }

  /**
   * D116: a new link for the guest (one sent to a wrong number): the old one
   * stops opening, the last random one from before D116 with it.
   */
  async replaceInvitationLink(currentUser: AuthenticatedUser, guestId: string) {
    const origin = rsvpPublicOrigin();
    return runSerializableTransaction(this.prisma, async (tx) => {
      const guest = await this.manageableGuest(tx, currentUser, guestId);
      await this.livePlan(tx, guest.weddingPlanId);
      const version = guest.rsvpLinkVersion + 1;
      const token = rsvpLinkToken(guest.id, version);
      await replaceRsvpLink(tx, guest.id, version, rsvpTokenHash(token));
      return { guestId: guest.id, url: new URL(`/rsvp/${token}`, origin).toString() };
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
          token,
          guest,
          plan,
          await this.invitationContext(tx, plan.id, guest.id),
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  /**
   * D116: the page was drawn for the guest. The page asks this after it has
   * drawn the invitation in a browser; a link preview's crawler reads only
   * the head and never asks it, so it is not taken for the guest opening.
   */
  async markInvitationOpened(token: string): Promise<{ opened: true }> {
    const hash = this.hashOrThrow(token);
    await runSerializableTransaction(this.prisma, async (tx) => {
      const guest = await findRsvpGuestByTokenHash(tx, hash);
      if (!guest) throw this.linkNotFound();
      await this.livePlan(tx, guest.weddingPlanId);
      await markRsvpLinkOpened(tx, guest.id, new Date());
    });
    return { opened: true };
  }

  /**
   * 6a: what a link crawler reads of this link (the public site includes it
   * in the page's head). A malformed, unknown or replaced link, or an
   * archived plan, is null: the page keeps its generic head, naming nobody.
   */
  async invitationPreview(token: string): Promise<RsvpPreview | null> {
    if (!TOKEN_PATTERN.test(token)) return null;
    const hash = rsvpTokenHash(token);
    const found = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const guest = await findRsvpGuestByTokenHash(tx, hash);
        if (!guest) return null;
        const plan = await this.plans.getPlan(tx, guest.weddingPlanId);
        if (!plan || plan.status === WeddingPlanStatus.ARCHIVED) return null;
        return { plan, context: await this.invitationContext(tx, plan.id, guest.id) };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    if (!found) return null;
    const { plan, context } = found;
    const wedding = this.weddingRow(context.events);
    const when = whenLine({
      date: plan.weddingDate,
      timeSlot: wedding?.timeSlot ?? null,
      exactTime: wedding?.exactTime ?? null,
    });
    const place = wedding?.placeLabel?.trim() || this.locationLabel(plan);
    const details = [
      ...(when ? [`الموعد: ${when}`] : []),
      ...(place ? [`المكان: ${place}`] : []),
    ].join(" · ");
    const photoUrl = context.card?.photoUrl ?? null;
    const photoRoute = await this.offeredCardPhoto(token, photoUrl);
    return {
      title: invitationLine(
        hostPhrase(context.card?.hostLine, plan.persona),
        plan.title,
      ),
      description: details
        ? `${details}. نرجو تأكيد حضورك من الرابط.`
        : "نرجو تأكيد حضورك من الرابط.",
      url: new URL(`/rsvp/${token}`, rsvpPublicOrigin()).toString(),
      image:
        photoUrl && photoRoute
          ? { url: photoRoute, type: imageTypeOf(photoUrl) }
          : null,
    };
  }

  /**
   * 6a: the card photo, read by the link: a short-lived signed URL of the
   * private object. A dead link, an archived plan or a card without a
   * photo is a 404.
   */
  async cardPhotoDownloadUrl(token: string): Promise<string> {
    const hash = this.hashOrThrow(token);
    const photoUrl = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const guest = await findRsvpGuestByTokenHash(tx, hash);
        if (!guest) throw this.linkNotFound();
        const plan = await this.livePlan(tx, guest.weddingPlanId);
        return (await findGuestInvitationCard(tx, plan.id))?.photoUrl ?? null;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    // A photo that cannot be signed is no photo to this link, not a server
    // error: the page and the preview no longer name it either.
    const read = photoUrl ? await this.signedCardPhoto(photoUrl) : null;
    if (!read) {
      throw new NotFoundException({
        statusCode: 404,
        code: "RSVP_CARD_PHOTO_NOT_FOUND",
        message: "This invitation has no photo",
      });
    }
    return read;
  }

  /**
   * D83: the plan's invitation card. RA-BE-86: reading it is a read of the
   * plan, as the guest list is (D52), so an archived plan's card still opens;
   * writing it keeps the guests' write check.
   */
  async getInvitationCard(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<InvitationCardResponse> {
    const { card, events } = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        await this.permissions.assertPlanReadableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        return {
          card: await findGuestInvitationCard(tx, weddingPlanId),
          events: await this.plans.listPlanEvents(tx, weddingPlanId),
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    return this.cardResponse(weddingPlanId, card, this.weddingRow(events));
  }

  /**
   * D83: writes the card. A missing field keeps its value, null clears it.
   * The photo is the writer's own verified public upload, consumed by the
   * card; the one it replaces is released for deletion. D116: a map link or
   * an address (an app from before D116 sends them here) is the wedding
   * row's.
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
    const saved = await runSerializableTransaction(this.prisma, async (tx) => {
      await this.permissions.assertGuestManageableInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      const current = await findGuestInvitationCard(tx, weddingPlanId);
      const eventsBefore = await this.plans.listPlanEvents(tx, weddingPlanId);
      const next = mergeInvitationCard(
        current ? this.cardFields(current, this.weddingRow(eventsBefore)) : null,
        { ...input, ...(photoGiven ? { photoUrl: wantedPhoto } : {}) },
      );
      if (next.mapUrl && !isAcceptableMapUrl(next.mapUrl)) {
        throw new BadRequestException({
          statusCode: 400,
          code: "INVITATION_CARD_MAP_URL_INVALID",
          message: "رابط الخريطة لازم يكون رابط كامل يبدأ بـ https.",
        });
      }
      await this.plans.setWeddingEventPlace(tx, weddingPlanId, {
        ...(input.mapUrl !== undefined ? { mapUrl: next.mapUrl } : {}),
        ...(input.address !== undefined ? { address: next.address } : {}),
      });
      const photoChanged = photoGiven && (current?.photoUrl ?? null) !== next.photoUrl;
      if (photoChanged && current?.photoUrl) {
        await this.media.scheduleTargetDeletion(
          { type: "GUEST_INVITATION_CARD", id: current.id },
          tx,
        );
      }
      const row = await upsertGuestInvitationCard(tx, weddingPlanId, {
        hostLine: next.hostLine,
        freeText: next.freeText,
        photoUrl: next.photoUrl,
        photoKind: next.photoKind,
      });
      if (photoChanged && next.photoUrl) {
        await this.media.consumePublicMediaUrl(
          currentUser,
          next.photoUrl,
          CARD_PHOTO_PURPOSE,
          { type: "GUEST_INVITATION_CARD", id: row.id },
          tx,
        );
      }
      return { row, events: await this.plans.listPlanEvents(tx, weddingPlanId) };
    });
    return this.cardResponse(weddingPlanId, saved.row, this.weddingRow(saved.events));
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
      const events = await this.plans.listPlanEvents(tx, plan.id);
      const wedding = this.weddingRow(events);
      const respondedAt = new Date();
      const confirmed = attendance === "CONFIRMED";
      // D116: the wedding's own id answers the wedding, as no id does.
      if (planEventId && planEventId !== wedding?.id) {
        return this.respondToEvent(tx, token, guest, plan, planEventId, {
          confirmed,
          companions,
          respondedAt,
          version: events.find((event) => event.id === planEventId)?.version ?? 1,
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
        weddingAnsweredVersion: wedding?.version ?? 1,
      });
      // A guest confirming the wedding as it is now, after a change, is a
      // new answer even with the same figures.
      const reconfirmed =
        confirmed &&
        (guest.weddingAnsweredVersion ?? wedding?.version ?? 1) < (wedding?.version ?? 1);
      if (replyChanged(guest, updated) || reconfirmed) {
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
      }
      return this.publicView(
        token,
        updated,
        plan,
        await this.invitationContext(tx, plan.id, guest.id),
      );
    });
  }

  /** D83: the guest's reply to one event beyond the wedding. */
  private async respondToEvent(
    tx: Prisma.TransactionClient,
    token: string,
    guest: RsvpGuest,
    plan: WeddingPlan,
    planEventId: string,
    answer: { confirmed: boolean; companions: number; respondedAt: Date; version: number },
  ): Promise<PublicInvitation> {
    const invite = await findGuestEventInvite(tx, guest.id, planEventId);
    if (!invite) {
      // RA-BE-74: the link works; the hosts took this event out of the
      // invitation after the page opened. A 409, not the dead link's 404,
      // so the page reloads the invitation as it is now.
      throw new ConflictException({
        statusCode: 409,
        code: "RSVP_EVENT_NOT_INVITED",
        message: "هذي المناسبة ما عادت في دعوتك.",
      });
    }
    const reply = {
      attendanceStatus: answer.confirmed
        ? GuestAttendanceStatus.CONFIRMED
        : GuestAttendanceStatus.DECLINED,
      companionsCount: answer.companions,
    };
    const reconfirmed =
      answer.confirmed && (invite.answeredVersion ?? answer.version) < answer.version;
    const changed = replyChanged(invite, reply) || reconfirmed;
    await recordGuestEventAnswer(tx, guest.id, planEventId, {
      ...reply,
      respondedAt: answer.respondedAt,
      answeredVersion: answer.version,
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
    if (changed) {
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
    }
    return this.publicView(token, current, plan, context);
  }

  /**
   * A guest of the plan the reader may send to: whoever manages the plan's
   * guests, a contributor only the guests they added; locked for the write.
   */
  private async manageableGuest(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    guestId: string,
  ): Promise<RsvpGuest> {
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
    return {
      id: guest.id,
      weddingPlanId: guest.weddingPlanId,
      name: guest.name,
      normalizedPhone: guest.normalizedPhone,
      invitationStatus: guest.invitationStatus,
      attendanceStatus: guest.attendanceStatus,
      seatsCount: guest.seatsCount,
      companionsCount: guest.companionsCount,
      respondedAt: guest.respondedAt,
      weddingAnsweredVersion: guest.weddingAnsweredVersion,
      rsvpLinkHash: guest.rsvpLinkHash,
      rsvpLinkVersion: guest.rsvpLinkVersion,
      linkOpenedAt: guest.linkOpenedAt,
    };
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

  private weddingRow(events: readonly ReadablePlanEvent[]): ReadablePlanEvent | null {
    return events.find((event) => event.type === "WEDDING") ?? null;
  }

  /**
   * D116: the occasions this guest is invited to, the wedding first, the
   * others by day (an undated one last), each with their answer. A plan
   * whose wedding row is not there yet (none should be: every plan gets one)
   * reads it at the id its row would get.
   */
  private guestOccasions(
    plan: WeddingPlan,
    guest: RsvpGuest,
    context: InvitationContext,
  ): GuestOccasion[] {
    const wedding = this.weddingRow(context.events);
    const weddingOccasion: GuestOccasion = {
      id: wedding?.id ?? `wedding_${plan.id}`,
      isWedding: true,
      label: planEventLabel({ type: "WEDDING", title: wedding?.title ?? null }),
      date: plan.weddingDate,
      timeSlot: wedding?.timeSlot ?? null,
      exactTime: wedding?.exactTime ?? null,
      placeLabel: wedding?.placeLabel?.trim() || this.locationLabel(plan),
      address: wedding?.address ?? null,
      mapUrl: wedding?.mapUrl ?? null,
      version: wedding?.version ?? 1,
      attendanceStatus: guest.attendanceStatus,
      companionsCount: guest.companionsCount,
      respondedAt: guest.respondedAt,
      answeredVersion: guest.weddingAnsweredVersion,
    };
    const byEvent = new Map(context.invites.map((invite) => [invite.planEventId, invite]));
    const others = context.events
      .filter((event) => event.type !== "WEDDING" && byEvent.has(event.id))
      .map((event): GuestOccasion => {
        const invite = byEvent.get(event.id)!;
        return {
          id: event.id,
          isWedding: false,
          label: planEventLabel(event),
          date: event.date,
          timeSlot: event.timeSlot,
          exactTime: event.exactTime,
          placeLabel: event.placeLabel,
          address: event.address,
          mapUrl: event.mapUrl,
          version: event.version,
          attendanceStatus: invite.attendanceStatus,
          companionsCount: invite.companionsCount,
          respondedAt: invite.respondedAt,
          answeredVersion: invite.answeredVersion,
        };
      })
      .sort((a, b) => {
        if (!a.date) return b.date ? 1 : 0;
        if (!b.date) return -1;
        return a.date.getTime() - b.date.getTime();
      });
    return [weddingOccasion, ...others];
  }

  private needsReconfirm(occasion: GuestOccasion): boolean {
    return standingOf(occasion, undefined) === "CONFIRMED_OLD";
  }

  private cardFields(
    card: GuestInvitationCardRow,
    wedding: ReadablePlanEvent | null,
  ): InvitationCardFields {
    return {
      hostLine: card.hostLine,
      freeText: card.freeText,
      photoUrl: card.photoUrl,
      photoKind: card.photoKind as InvitationCardPhotoKind,
      mapUrl: wedding?.mapUrl ?? null,
      address: wedding?.address ?? null,
    };
  }

  private async cardResponse(
    weddingPlanId: string,
    card: GuestInvitationCardRow | null,
    wedding: ReadablePlanEvent | null,
  ): Promise<InvitationCardResponse> {
    const photoReadUrl = card?.photoUrl
      ? await this.signedCardPhoto(card.photoUrl)
      : null;
    return {
      weddingPlanId,
      ...(card
        ? this.cardFields(card, wedding)
        : {
            hostLine: null,
            freeText: null,
            photoUrl: null,
            photoKind: "PHOTO" as const,
            mapUrl: wedding?.mapUrl ?? null,
            address: wedding?.address ?? null,
          }),
      photoReadUrl,
      updatedAt: card?.updatedAt ?? null,
    };
  }

  /**
   * The owner's signed read of the card photo, or null when it cannot be
   * signed (a photo kept on an older media host, storage not configured).
   * The card is read, and a save already committed is answered, without it:
   * the preview draws no photo, which is what the owner would see anyway.
   */
  private async signedCardPhoto(photoUrl: string): Promise<string | null> {
    try {
      const read = await this.media.createStoredMediaDownloadUrl(
        photoUrl,
        CARD_PHOTO_PURPOSE,
      );
      return read.downloadUrl;
    } catch {
      return null;
    }
  }

  /**
   * The link's own photo route, offered only for a photo that can be read.
   * One that cannot be signed was named all the same: the guest's page drew
   * a broken picture and the link's preview a picture that answers with an
   * error. Signing is a local computation, no call to the storage.
   */
  private async offeredCardPhoto(
    token: string,
    photoUrl: string | null | undefined,
  ): Promise<string | null> {
    if (!photoUrl) return null;
    return (await this.signedCardPhoto(photoUrl)) ? this.cardPhotoRoute(token) : null;
  }

  /** 6a: the card photo through the guest's own link, on the public origin. */
  private cardPhotoRoute(token: string): string {
    return new URL(
      `/api/v1/public/rsvp/${token}/card-photo`,
      rsvpPublicOrigin(),
    ).toString();
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

  /**
   * The guest's page. 6a: the card photo is the link's own route, never the
   * stored address, which a private bucket would refuse anyway. D116: every
   * occasion the guest is invited to, each with its own place and whether
   * an answer given before a change asks to be confirmed again.
   */
  private async publicView(
    token: string,
    guest: RsvpGuest,
    plan: WeddingPlan,
    context: InvitationContext,
  ): Promise<PublicInvitation> {
    const photoRoute = await this.offeredCardPhoto(token, context.card?.photoUrl);
    const [wedding, ...others] = this.guestOccasions(plan, guest, context);
    const weddingRow = this.weddingRow(context.events);
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
      wedding: {
        id: wedding.id,
        timeSlot: wedding.timeSlot,
        exactTime: wedding.exactTime,
        timeLabel: planEventTimeLabel(wedding),
        placeLabel: weddingRow?.placeLabel ?? null,
        mapUrl: wedding.mapUrl,
        address: wedding.address,
        needsReconfirm: this.needsReconfirm(wedding),
      },
      card: context.card
        ? {
            ...this.cardFields(context.card, weddingRow),
            photoUrl: photoRoute,
          }
        : null,
      hostPhrase: hostPhrase(context.card?.hostLine, plan.persona),
      events: others.map((occasion) => ({
        id: occasion.id,
        label: occasion.label,
        date: occasion.date ? occasion.date.toISOString().slice(0, 10) : null,
        timeSlot: occasion.timeSlot,
        exactTime: occasion.exactTime,
        timeLabel: planEventTimeLabel(occasion),
        placeLabel: occasion.placeLabel,
        mapUrl: occasion.mapUrl,
        address: occasion.address,
        attendanceStatus: occasion.attendanceStatus,
        companionsCount: occasion.companionsCount,
        respondedAt: occasion.respondedAt,
        needsReconfirm: this.needsReconfirm(occasion),
      })),
      persona:
        plan.persona === "BRIDE" ? "BRIDE" : plan.persona === "GROOM" ? "GROOM" : null,
    };
  }
}
