import { Module } from '@nestjs/common';
import {
  PUSH_DELIVERY_IMPLEMENTATION,
  PushTransportInternalModule,
} from '../internal/push-transport.internal.module';
import { PUSH_DELIVERY_PORT } from './push-delivery.port';

@Module({
  imports: [PushTransportInternalModule],
  providers: [
    {
      provide: PUSH_DELIVERY_PORT,
      useExisting: PUSH_DELIVERY_IMPLEMENTATION,
    },
  ],
  exports: [PUSH_DELIVERY_PORT],
})
export class PushDeliveryPublicModule {}
