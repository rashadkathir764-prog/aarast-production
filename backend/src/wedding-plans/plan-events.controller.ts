import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { PlanEventTimeSlot, PlanEventType } from "@prisma/client";
import { IsIn, IsOptional, IsString, Matches } from "class-validator";
import { MaxCharacters } from "../shared-kernel/text/text-length";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import {
  PLAN_EVENT_NOTE_MAX,
  PLAN_EVENT_PERSON_MAX,
  PLAN_EVENT_PLACE_MAX,
  PLAN_EVENT_TITLE_MAX,
} from "../modules/planning/domain/plan-event-rules";
import { PlanEventsService } from "./plan-events.service";

/**
 * b13's fields; an absent field keeps its value, `null` clears it. RA-BE-78
 * (RA-BE-16): the text counts as the phone's fields count it (the same 60 and
 * 120 in `plan_event_sheet.dart`), so a name with its marks is never refused
 * after the phone took it.
 */
export class PlanEventFieldsDto {
  @IsOptional()
  @IsString()
  @MaxCharacters(PLAN_EVENT_TITLE_MAX)
  title?: string | null;

  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date?: string | null;

  @IsOptional()
  @IsIn(Object.values(PlanEventTimeSlot))
  timeSlot?: PlanEventTimeSlot | null;

  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  exactTime?: string | null;

  @IsOptional()
  @IsString()
  @MaxCharacters(PLAN_EVENT_PLACE_MAX)
  placeLabel?: string | null;

  @IsOptional()
  @IsString()
  @MaxCharacters(PLAN_EVENT_PERSON_MAX)
  responsibleName?: string | null;

  @IsOptional()
  @IsString()
  @MaxCharacters(PLAN_EVENT_NOTE_MAX)
  note?: string | null;
}

export class CreatePlanEventDto extends PlanEventFieldsDto {
  @IsIn(Object.values(PlanEventType))
  type!: PlanEventType;
}

/** D65: the wedding's events (b12, b13), the source of b04 and b05. */
@Controller("api/v1/wedding-plans/:weddingPlanId/events")
@UseGuards(JwtAuthGuard)
export class WeddingPlanEventsController {
  constructor(private readonly events: PlanEventsService) {}

  @Get()
  list(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.events.list(currentUser, weddingPlanId);
  }

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreatePlanEventDto,
  ) {
    return this.events.create(currentUser, weddingPlanId, dto);
  }

  @Patch(":eventId")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Param("eventId") eventId: string,
    @Body() dto: PlanEventFieldsDto,
  ) {
    return this.events.update(currentUser, weddingPlanId, eventId, dto);
  }

  @Delete(":eventId")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Param("eventId") eventId: string,
  ) {
    return this.events.remove(currentUser, weddingPlanId, eventId);
  }
}
