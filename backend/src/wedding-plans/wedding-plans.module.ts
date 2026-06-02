import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { WeddingPlansController } from './wedding-plans.controller';
import { WeddingPlansService } from './wedding-plans.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [WeddingPlansController],
  providers: [WeddingPlansService],
})
export class WeddingPlansModule {}