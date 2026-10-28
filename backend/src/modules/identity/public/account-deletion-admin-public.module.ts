import { Module } from '@nestjs/common';
import {
  ACCOUNT_DELETION_ADMIN_IMPLEMENTATION,
  IdentityProfileInternalModule,
} from '../internal/identity-profile.internal.module';
import { ACCOUNT_DELETION_ADMIN_PORT } from './account-deletion-admin.port';

/** D63: n06 «طلبات البيانات» reads the pending deletions and downloads, and restores a deletion. */
@Module({
  imports: [IdentityProfileInternalModule],
  providers: [
    {
      provide: ACCOUNT_DELETION_ADMIN_PORT,
      useExisting: ACCOUNT_DELETION_ADMIN_IMPLEMENTATION,
    },
  ],
  exports: [ACCOUNT_DELETION_ADMIN_PORT],
})
export class AccountDeletionAdminPublicModule {}
