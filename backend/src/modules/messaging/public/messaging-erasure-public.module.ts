import { Module } from '@nestjs/common';
import {
  MESSAGING_ERASURE_IMPLEMENTATION,
  MessagingErasureInternalModule,
} from '../internal/messaging-erasure.internal.module';
import { MESSAGING_ERASURE_PORT } from './messaging-erasure.port';

@Module({
  imports: [MessagingErasureInternalModule],
  providers: [
    {
      provide: MESSAGING_ERASURE_PORT,
      useExisting: MESSAGING_ERASURE_IMPLEMENTATION,
    },
  ],
  exports: [MESSAGING_ERASURE_PORT],
})
export class MessagingErasurePublicModule {}
