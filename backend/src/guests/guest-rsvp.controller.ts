import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Res,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { GuestInvitationSendChannel, GuestInvitationSendKind } from "@prisma/client";
import type { Response } from "express";
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from "class-validator";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { GuestRsvpService, RSVP_MAX_COMPANIONS } from "./guest-rsvp.service";
import { renderRsvpPreviewHead } from "./rsvp-preview";

export class RsvpAnswerDto {
  @IsIn(["CONFIRMED", "DECLINED"])
  attendance!: "CONFIRMED" | "DECLINED";

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(RSVP_MAX_COMPANIONS)
  companionsCount?: number;

  /** D83: the reply is to this event of the plan; absent, it is to the wedding. */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  planEventId?: string;
}

export class InvitationLinkDto {
  /** e08: the reminder text instead of the invitation (before D116: `kind`). */
  @IsOptional()
  @IsBoolean()
  reminder?: boolean;

  /** D116: what the text is; absent, what the guest is due. */
  @IsOptional()
  @IsIn(Object.values(GuestInvitationSendKind))
  kind?: GuestInvitationSendKind;

  /** D116: an invitation of its own for this occasion; absent, one with all of them. */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  planEventId?: string;

  /** D116: how the person will send it from their phone. */
  @IsOptional()
  @IsIn(Object.values(GuestInvitationSendChannel))
  channel?: GuestInvitationSendChannel;
}

/** D116: what the person says happened to a prepared send. */
export class SettleInvitationSendDto {
  @IsBoolean()
  sent!: boolean;

  @IsOptional()
  @IsIn(Object.values(GuestInvitationSendChannel))
  channel?: GuestInvitationSendChannel;
}

/** The plan side: a personal invitation link for one guest (V1 checklist 4.7). */
@Controller("api/v1/guests")
@UseGuards(JwtAuthGuard)
export class GuestInvitationLinksController {
  constructor(private readonly rsvp: GuestRsvpService) {}

  /** Prepares one send: the text and the guest's stable link (D116). */
  @Post(":id/invitation-link")
  createInvitationLink(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: InvitationLinkDto,
  ) {
    return this.rsvp.createInvitationLink(currentUser, id, {
      reminder: dto?.reminder === true,
      kind: dto?.kind,
      planEventId: dto?.planEventId?.trim() || undefined,
      channel: dto?.channel,
    });
  }

  /** D116: a new link for the guest; the old one stops opening. */
  @Post(":id/invitation-link/replace")
  replaceInvitationLink(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.rsvp.replaceInvitationLink(currentUser, id);
  }

  /** D116: sent, or not: only the person can say. */
  @Post("invitation-sends/:sendId/settle")
  settleInvitationSend(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("sendId") sendId: string,
    @Body() dto: SettleInvitationSendDto,
  ) {
    return this.rsvp.settleInvitationSend(currentUser, sendId, {
      sent: dto.sent,
      channel: dto.channel,
    });
  }
}

/**
 * The guest side, without an account: read the invitation and answer it.
 * The link token is the only credential, so both routes are rate-limited.
 */
@Controller("api/v1/public/rsvp")
export class PublicRsvpController {
  constructor(private readonly rsvp: GuestRsvpService) {}

  @Get(":token")
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  getInvitation(@Param("token") token: string) {
    return this.rsvp.getInvitation(token);
  }

  /**
   * D116: the page drew the invitation in a browser. A link preview's
   * crawler reads the head and never makes this request.
   */
  @Post(":token/opened")
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  opened(@Param("token") token: string) {
    return this.rsvp.markInvitationOpened(token);
  }

  @Post(":token")
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  respond(@Param("token") token: string, @Body() dto: RsvpAnswerDto) {
    return this.rsvp.respond(
      token,
      dto.attendance,
      dto.companionsCount,
      dto.planEventId?.trim() || undefined,
    );
  }

  /**
   * 6a: this link's Open Graph tags as an HTML fragment, which the public
   * site's page includes in its head (nginx SSI) so a link crawler reads the
   * invitation without running the script. A dead link is a 204: the page
   * keeps its generic tags. Never cached: the link can be replaced.
   */
  @Get(":token/preview")
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  async preview(@Param("token") token: string, @Res() response: Response) {
    const preview = await this.rsvp.invitationPreview(token);
    response.set("Cache-Control", "private, no-store");
    if (!preview) {
      response.status(204).end();
      return;
    }
    response
      .status(200)
      .type("text/html; charset=utf-8")
      .send(renderRsvpPreviewHead(preview));
  }

  /**
   * 6a: the card photo, read by the link: a redirect to a short-lived signed
   * URL of the private object. Neither the redirect nor the link it names is
   * kept by a cache, so a replaced link stops showing the photo.
   */
  @Get(":token/card-photo")
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  async cardPhoto(@Param("token") token: string, @Res() response: Response) {
    const url = await this.rsvp.cardPhotoDownloadUrl(token);
    response
      .set("Cache-Control", "private, no-store")
      .set("Referrer-Policy", "no-referrer")
      .redirect(302, url);
  }
}
