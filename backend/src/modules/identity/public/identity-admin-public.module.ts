import { Module } from '@nestjs/common';
import {
  IDENTITY_ADMIN_IMPLEMENTATION,
  IdentityUserInternalModule,
} from '../internal/identity-user.internal.module';
import { IDENTITY_ADMIN_PORT } from './identity-admin.port';

@Module({
  imports: [IdentityUserInternalModule],
  providers: [
    {
      provide: IDENTITY_ADMIN_PORT,
      useExisting: IDENTITY_ADMIN_IMPLEMENTATION,
    },
  ],
  exports: [IDENTITY_ADMIN_PORT],
})
export class IdentityAdminPublicModule {}
