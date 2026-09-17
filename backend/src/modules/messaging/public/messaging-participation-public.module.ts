import { Module } from '@nestjs/common';
import {
  MESSAGING_PARTICIPATION_IMPLEMENTATION,
  MessagingPortsInternalModule,
} from '../internal/messaging-ports.internal.module';
import { MESSAGING_PARTICIPATION_PORT } from './messaging-participation.port';

@Module({
  imports: [MessagingPortsInternalModule],
  providers: [
    {
      provide: MESSAGING_PARTICIPATION_PORT,
      useExisting: MESSAGING_PARTICIPATION_IMPLEMENTATION,
    },
  ],
  exports: [MESSAGING_PARTICIPATION_PORT],
})
export class MessagingParticipationPublicModule {}
