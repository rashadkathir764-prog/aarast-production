import { Module } from '@nestjs/common';
import {
  IdentityUserInternalModule,
  PROVIDER_ACCOUNT_IMPLEMENTATION,
} from '../internal/identity-user.internal.module';
import { PROVIDER_ACCOUNT_PORT } from './provider-account.port';

@Module({
  imports: [IdentityUserInternalModule],
  providers: [
    {
      provide: PROVIDER_ACCOUNT_PORT,
      useExisting: PROVIDER_ACCOUNT_IMPLEMENTATION,
    },
  ],
  exports: [PROVIDER_ACCOUNT_PORT],
})
export class ProviderAccountPublicModule {}
