import { Module } from '@nestjs/common';
import {
  IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION,
  IdentityTransientDeliveryInternalModule,
} from '../internal/identity-transient-delivery.internal.module';
import { IDENTITY_TRANSIENT_DELIVERY_PORT } from './identity-transient-delivery.port';

@Module({
  imports: [IdentityTransientDeliveryInternalModule],
  providers: [
    {
      provide: IDENTITY_TRANSIENT_DELIVERY_PORT,
      useExisting: IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION,
    },
  ],
  exports: [IDENTITY_TRANSIENT_DELIVERY_PORT],
})
export class IdentityTransientDeliveryPublicModule {}
