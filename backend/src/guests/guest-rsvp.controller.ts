import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { IsIn, IsInt, IsOptional, Max, Min } from "class-validator";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { GuestRsvpService, RSVP_MAX_COMPANIONS } from "./guest-rsvp.service";

export class RsvpAnswerDto {
  @IsIn(["CONFIRMED", "DECLINED"])
  attendance!: "CONFIRMED" | "DECLINED";

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(RSVP_MAX_COMPANIONS)
  companionsCount?: number;
}

/** The plan side: a personal invitation link for one guest (V1 checklist 4.7). */
@Controller("api/v1/guests")
@UseGuards(JwtAuthGuard)
export class GuestInvitationLinksController {
  constructor(private readonly rsvp: GuestRsvpService) {}

  @Post(":id/invitation-link")
  createInvitationLink(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.rsvp.createInvitationLink(currentUser, id);
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

  @Post(":token")
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  respond(@Param("token") token: string, @Body() dto: RsvpAnswerDto) {
    return this.rsvp.respond(token, dto.attendance, dto.companionsCount);
  }
}
