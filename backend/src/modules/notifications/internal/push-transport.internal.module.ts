import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { FirebasePushClient } from '../../../push/firebase-push.client';
import { PushDeliveryService } from '../../../push/push-delivery.service';

export const PUSH_DELIVERY_IMPLEMENTATION = Symbol(
  'PUSH_DELIVERY_IMPLEMENTATION',
);
export const PUSH_CAPABILITY_IMPLEMENTATION = Symbol(
  'PUSH_CAPABILITY_IMPLEMENTATION',
);

@Module({
  imports: [PrismaModule],
  providers: [
    FirebasePushClient,
    PushDeliveryService,
    {
      provide: PUSH_DELIVERY_IMPLEMENTATION,
      useExisting: PushDeliveryService,
    },
    {
      provide: PUSH_CAPABILITY_IMPLEMENTATION,
      useExisting: FirebasePushClient,
    },
  ],
  exports: [
    FirebasePushClient,
    PushDeliveryService,
    PUSH_DELIVERY_IMPLEMENTATION,
    PUSH_CAPABILITY_IMPLEMENTATION,
  ],
})
export class PushTransportInternalModule {}
