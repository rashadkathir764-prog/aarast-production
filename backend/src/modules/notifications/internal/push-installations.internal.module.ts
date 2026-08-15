import { Module } from '@nestjs/common';
import { PushInstallationsService } from '../../../push/push-installations.service';
import { PrismaModule } from '../../../platform/database/prisma.module';

@Module({
  imports: [PrismaModule],
  providers: [PushInstallationsService],
  exports: [PushInstallationsService],
})
export class PushInstallationsInternalModule {}
