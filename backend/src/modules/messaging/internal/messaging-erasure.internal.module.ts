import { Module } from '@nestjs/common';
import { MessagingErasureService } from './messaging-erasure.service';

export const MESSAGING_ERASURE_IMPLEMENTATION = Symbol('MESSAGING_ERASURE_IMPLEMENTATION');

@Module({
  providers: [
    MessagingErasureService,
    {
      provide: MESSAGING_ERASURE_IMPLEMENTATION,
      useExisting: MessagingErasureService,
    },
  ],
  exports: [MessagingErasureService, MESSAGING_ERASURE_IMPLEMENTATION],
})
export class MessagingErasureInternalModule {}
