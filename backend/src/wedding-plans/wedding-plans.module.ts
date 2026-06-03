import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import { WeddingPlansController } from './wedding-plans.controller';
import { WeddingPlansService } from './wedding-plans.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [WeddingPlansController],
  providers: [WeddingPlansService],
})
export class WeddingPlansModule {}
