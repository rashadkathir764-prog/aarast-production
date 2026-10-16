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
  Prisma,
  WeddingPlanStatus,
  type WeddingPlan,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
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
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../modules/planning/public/plan-read.port";
import { weddingLocationResponse } from "../modules/planning/public/wedding-location";
import {
  findRsvpGuestByTokenHash,
  recordRsvpAnswer,
  storeRsvpTokenHash,
  type RsvpGuest,
} from "../modules/guests/infrastructure/guest-rsvp.repository";
import {
  findGuestById,
  lockGuestForUpdate,
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

export interface PublicInvitation {
  guestName: string;
  planTitle: string;
  weddingDate: string | null;
  locationLabel: string | null;
  attendanceStatus: GuestAttendanceStatus;
  companionsCount: number;
  maxCompanions: number;
  respondedAt: Date | null;
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

/** The WhatsApp text the plan owner sends; the link is the guest's own. */
export function buildRsvpMessage(input: {
  guestName: string;
  planTitle: string;
  weddingDate: Date | null;
  locationLabel: string | null;
  url: string;
}): string {
  return [
    `أهلًا ${input.guestName} 🌸`,
    `يسعدنا دعوتك لحضور ${input.planTitle}.`,
    ...(input.weddingDate ? [`الموعد: ${formatDay(input.weddingDate)}`] : []),
    ...(input.locationLabel ? [`المكان: ${input.locationLabel}`] : []),
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
  ) {}

  async createInvitationLink(currentUser: AuthenticatedUser, guestId: string) {
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
        return this.publicView(guest, plan);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async respond(
    token: string,
    attendance: "CONFIRMED" | "DECLINED",
    companionsCount: number | undefined,
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
        title: confirmed ? "ضيف أكّد حضوره" : "ضيف اعتذر عن الحضور",
        body: confirmed
          ? `${guest.name} أكّد حضوره${companions > 0 ? ` ومعه ${companions}` : ""}.`
          : `${guest.name} اعتذر عن الحضور.`,
        entityType: "guest",
        entityId: guest.id,
        routeTarget: `/wedding-plans/${plan.id}/guests`,
        data: { guestId: guest.id, weddingPlanId: plan.id, attendance },
        dedupeKey: `${plan.ownerUserId}:guest-responded:${guest.id}:${respondedAt.getTime()}`,
      });
      return this.publicView(updated, plan);
    });
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

  private publicView(guest: RsvpGuest, plan: WeddingPlan): PublicInvitation {
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
    };
  }
}
