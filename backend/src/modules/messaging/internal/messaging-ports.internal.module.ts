import { Module } from '@nestjs/common';
import { ProviderReadPublicModule } from '../../marketplace/public/provider-read-public.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';
import { MessagingErasureService } from './messaging-erasure.service';
import { MessagingParticipationService } from './messaging-participation.service';

export const MESSAGING_ERASURE_IMPLEMENTATION = Symbol('MESSAGING_ERASURE_IMPLEMENTATION');
export const MESSAGING_PARTICIPATION_IMPLEMENTATION = Symbol('MESSAGING_PARTICIPATION_IMPLEMENTATION');

@Module({
  imports: [ProviderReadPublicModule, PlanReadPublicModule],
  providers: [
    MessagingErasureService,
    MessagingParticipationService,
    {
      provide: MESSAGING_ERASURE_IMPLEMENTATION,
      useExisting: MessagingErasureService,
    },
    {
      provide: MESSAGING_PARTICIPATION_IMPLEMENTATION,
      useExisting: MessagingParticipationService,
    },
  ],
  exports: [
    MessagingErasureService,
    MessagingParticipationService,
    MESSAGING_ERASURE_IMPLEMENTATION,
    MESSAGING_PARTICIPATION_IMPLEMENTATION,
  ],
})
export class MessagingPortsInternalModule {}
