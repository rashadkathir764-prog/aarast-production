import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { WeddingPlansModule } from './wedding-plans/wedding-plans.module';

@Module({
  imports: [PrismaModule, AuthModule, WeddingPlansModule],
  controllers: [HealthController],
})
export class AppModule {}

