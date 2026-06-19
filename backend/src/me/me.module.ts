import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ApiV1MeController, MeController } from './me.controller';

@Module({
  imports: [AuthModule],
  controllers: [MeController, ApiV1MeController],
})
export class MeModule {}
