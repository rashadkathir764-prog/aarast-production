import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { ListQueryDto } from "../platform/http/list-query.dto";
import { BulkGuestsDto } from "./dto/bulk-guests.dto";
import { CreateGuestGroupDto } from "./dto/create-guest-group.dto";
import { CreateGuestWithEventsDto } from "./dto/create-guest-with-events.dto";
import { SetInvitationCardDto } from "./dto/set-invitation-card.dto";
import { UpdateGuestGroupDto } from "./dto/update-guest-group.dto";
import { UpdateGuestDto } from "./dto/update-guest.dto";
import { GuestRsvpService } from "./guest-rsvp.service";
import { GuestsService } from "./guests.service";

@Controller("api/v1/wedding-plans/:weddingPlanId/guests")
@UseGuards(JwtAuthGuard)
export class WeddingPlanGuestsController {
  constructor(
    private readonly guestsService: GuestsService,
    private readonly rsvp: GuestRsvpService,
  ) {}

  /** D83: the plan's one invitation card, for whoever manages its guests. */
  @Get("invitation-card")
  invitationCard(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.rsvp.getInvitationCard(currentUser, weddingPlanId);
  }

  @Put("invitation-card")
  setInvitationCard(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: SetInvitationCardDto,
  ) {
    return this.rsvp.setInvitationCard(currentUser, weddingPlanId, dto);
  }

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Query() query: ListQueryDto,
  ) {
    return this.guestsService.findForPlan(currentUser, weddingPlanId, query);
  }

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreateGuestWithEventsDto,
  ) {
    return this.guestsService.create(currentUser, weddingPlanId, dto);
  }

  @Post("bulk")
  bulkCreate(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: BulkGuestsDto,
  ) {
    return this.guestsService.bulkCreate(currentUser, weddingPlanId, dto);
  }

  @Get("summary")
  summary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.guestsService.summary(currentUser, weddingPlanId);
  }
}

@Controller("api/v1/wedding-plans/:weddingPlanId/guest-groups")
@UseGuards(JwtAuthGuard)
export class WeddingPlanGuestGroupsController {
  constructor(private readonly guestsService: GuestsService) {}

  @Get()
  findGroups(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.guestsService.findGroups(currentUser, weddingPlanId);
  }

  @Post()
  createGroup(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreateGuestGroupDto,
  ) {
    return this.guestsService.createGroup(currentUser, weddingPlanId, dto);
  }
}

@Controller("api/v1/guests")
@UseGuards(JwtAuthGuard)
export class GuestsController {
  constructor(private readonly guestsService: GuestsService) {}

  @Get(":id")
  findOne(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.guestsService.findOne(currentUser, id);
  }

  @Patch(":id")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateGuestDto,
  ) {
    return this.guestsService.update(currentUser, id, dto);
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.guestsService.remove(currentUser, id);
  }
}

@Controller("api/v1/guest-groups")
@UseGuards(JwtAuthGuard)
export class GuestGroupsController {
  constructor(private readonly guestsService: GuestsService) {}

  @Patch(":id")
  updateGroup(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateGuestGroupDto,
  ) {
    return this.guestsService.updateGroup(currentUser, id, dto);
  }

  @Delete(":id")
  removeGroup(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.guestsService.removeGroup(currentUser, id);
  }
}
