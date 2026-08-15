import { Module } from '@nestjs/common';
import { MessagingRealtimeInternalModule } from '../internal/messaging-realtime.internal.module';
import { MESSAGING_REALTIME_IMPLEMENTATION } from '../internal/messaging-realtime.implementation-token';
import { MESSAGING_REALTIME_PORT } from './messaging-realtime.port';

@Module({
  imports: [MessagingRealtimeInternalModule],
  providers: [
    {
      provide: MESSAGING_REALTIME_PORT,
      useExisting: MESSAGING_REALTIME_IMPLEMENTATION,
    },
  ],
  exports: [MESSAGING_REALTIME_PORT],
})
export class MessagingRealtimePublicModule {}
