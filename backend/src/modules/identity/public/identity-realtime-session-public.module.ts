import { Module } from '@nestjs/common';
import {
  IDENTITY_REALTIME_SESSION_IMPLEMENTATION,
  IdentityUserInternalModule,
} from '../internal/identity-user.internal.module';
import { IDENTITY_REALTIME_SESSION_PORT } from './identity-realtime-session.port';

@Module({
  imports: [IdentityUserInternalModule],
  providers: [
    {
      provide: IDENTITY_REALTIME_SESSION_PORT,
      useExisting: IDENTITY_REALTIME_SESSION_IMPLEMENTATION,
    },
  ],
  exports: [IDENTITY_REALTIME_SESSION_PORT],
})
export class IdentityRealtimeSessionPublicModule {}
