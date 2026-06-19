import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1GuestGroupsController,
  ApiV1GuestsController,
  ApiV1WeddingPlanGuestGroupsController,
  ApiV1WeddingPlanGuestsController,
  GuestGroupsController,
  GuestsController,
  WeddingPlanGuestGroupsController,
  WeddingPlanGuestsController,
} from './guests.controller';
import { GuestsService } from './guests.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [
    WeddingPlanGuestsController,
    WeddingPlanGuestGroupsController,
    GuestsController,
    GuestGroupsController,
    ApiV1WeddingPlanGuestsController,
    ApiV1WeddingPlanGuestGroupsController,
    ApiV1GuestsController,
    ApiV1GuestGroupsController,
  ],
  providers: [GuestsService],
})
export class GuestsModule {}
