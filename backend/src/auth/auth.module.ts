import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { IdentityAuthInternalModule } from '../modules/identity/internal/identity-auth.internal.module';
import { IdentityAuthPublicModule } from '../modules/identity/public/identity-auth-public.module';

@Module({
  imports: [IdentityAuthInternalModule, IdentityAuthPublicModule],
  controllers: [AuthController],
  exports: [IdentityAuthPublicModule],
})
export class AuthModule {}
