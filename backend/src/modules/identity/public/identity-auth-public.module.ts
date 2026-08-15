import { Module } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  IDENTITY_AUTH_IMPLEMENTATION,
  IdentityAuthInternalModule,
} from '../internal/identity-auth.internal.module';
import {
  IDENTITY_ACCESS_TOKEN_VERIFIER,
  IDENTITY_AUTH_PORT,
} from './identity-auth.port';

@Module({
  imports: [IdentityAuthInternalModule],
  providers: [
    { provide: IDENTITY_AUTH_PORT, useExisting: IDENTITY_AUTH_IMPLEMENTATION },
    { provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService },
  ],
  exports: [IDENTITY_AUTH_PORT, IDENTITY_ACCESS_TOKEN_VERIFIER],
})
export class IdentityAuthPublicModule {}
