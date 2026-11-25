import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { IdentityTransientDeliveryAdapter } from './identity-transient-delivery.adapter';

export const IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION = Symbol(
  'IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION',
);

@Module({
  // RA-BE-34: the messages' daily budget is counted in the database.
  imports: [PrismaModule],
  providers: [
    IdentityTransientDeliveryAdapter,
    {
      provide: IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION,
      useExisting: IdentityTransientDeliveryAdapter,
    },
  ],
  // RA-BE-141: the adapter itself serves identity's own phone-change notice.
  exports: [IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION, IdentityTransientDeliveryAdapter],
})
export class IdentityTransientDeliveryInternalModule {}
