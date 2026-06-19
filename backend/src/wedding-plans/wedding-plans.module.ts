import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1WeddingPlansController,
  WeddingPlansController,
} from './wedding-plans.controller';
import { WeddingPlansService } from './wedding-plans.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [WeddingPlansController, ApiV1WeddingPlansController],
  providers: [WeddingPlansService],
  exports: [WeddingPlansService],
})
export class WeddingPlansModule {}
