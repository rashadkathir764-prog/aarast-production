import { Module } from '@nestjs/common';
import { MessagingRealtimePublicModule } from '../modules/messaging/public/messaging-realtime-public.module';
import { MESSAGING_REALTIME_PORT } from '../modules/messaging/public/messaging-realtime.port';
import { PushDeliveryPublicModule } from '../modules/notifications/public/push-delivery-public.module';
import { PUSH_DELIVERY_PORT } from '../modules/notifications/public/push-delivery.port';
import { OutboxCoreModule } from '../platform/outbox/outbox-core.module';
import { OutboxDispatcher } from '../platform/outbox/outbox.dispatcher';
import {
  OUTBOX_PUSH_SINK,
  OUTBOX_REALTIME_SINK,
} from '../platform/outbox/outbox.ports';
import { OutboxWorker } from '../platform/outbox/outbox.worker';

@Module({
  imports: [
    OutboxCoreModule,
    MessagingRealtimePublicModule,
    PushDeliveryPublicModule,
  ],
  providers: [
    {
      provide: OUTBOX_REALTIME_SINK,
      useExisting: MESSAGING_REALTIME_PORT,
    },
    {
      provide: OUTBOX_PUSH_SINK,
      useExisting: PUSH_DELIVERY_PORT,
    },
    OutboxDispatcher,
    OutboxWorker,
  ],
})
export class ApplicationOutboxRuntimeModule {}
