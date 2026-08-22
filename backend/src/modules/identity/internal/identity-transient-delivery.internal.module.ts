import { Module } from '@nestjs/common';
import { IdentityTransientDeliveryAdapter } from './identity-transient-delivery.adapter';

export const IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION = Symbol(
  'IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION',
);

@Module({
  providers: [
    IdentityTransientDeliveryAdapter,
    {
      provide: IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION,
      useExisting: IdentityTransientDeliveryAdapter,
    },
  ],
  exports: [IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION],
})
export class IdentityTransientDeliveryInternalModule {}
