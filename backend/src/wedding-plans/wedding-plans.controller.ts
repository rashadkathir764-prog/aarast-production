import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateWeddingPlanDto } from './dto/create-wedding-plan.dto';
import { UpdateWeddingPlanDto } from './dto/update-wedding-plan.dto';
import { WeddingPlansService } from './wedding-plans.service';

@Controller('wedding-plans')
@UseGuards(JwtAuthGuard)
export class WeddingPlansController {
  constructor(private readonly weddingPlansService: WeddingPlansService) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CreateWeddingPlanDto,
  ) {
    return this.weddingPlansService.create(currentUser, dto);
  }

  @Get()
  findAccessible(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.weddingPlansService.findAccessible(currentUser);
  }

  @Get('my')
  findMine(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.weddingPlansService.findMine(currentUser);
  }

  @Get('active')
  findActive(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.weddingPlansService.findActive(currentUser);
  }

  @Post(':id/set-active')
  setActive(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.weddingPlansService.setActive(currentUser, id);
  }

  @Get(':id')
  findOne(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.weddingPlansService.findOne(currentUser, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateWeddingPlanDto,
  ) {
    return this.weddingPlansService.update(currentUser, id, dto);
  }

  @Patch(':id/archive')
  archive(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.weddingPlansService.archive(currentUser, id);
  }
}

@Controller('api/v1/wedding-plans')
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlansController {
  constructor(private readonly weddingPlansService: WeddingPlansService) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CreateWeddingPlanDto,
  ) {
    return this.weddingPlansService.create(currentUser, dto);
  }

  @Get()
  findAccessible(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.weddingPlansService.findAccessible(currentUser);
  }

  @Get('my')
  findMine(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.weddingPlansService.findMine(currentUser);
  }

  @Get('active')
  findActive(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.weddingPlansService.findActive(currentUser);
  }

  @Post(':id/set-active')
  setActive(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.weddingPlansService.setActive(currentUser, id);
  }

  @Get(':id')
  findOne(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.weddingPlansService.findOne(currentUser, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateWeddingPlanDto,
  ) {
    return this.weddingPlansService.update(currentUser, id, dto);
  }

  @Patch(':id/archive')
  archive(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.weddingPlansService.archive(currentUser, id);
  }
}
