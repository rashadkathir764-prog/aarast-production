import { Module } from '@nestjs/common';
import {
  PUSH_CAPABILITY_IMPLEMENTATION,
  PushTransportInternalModule,
} from '../internal/push-transport.internal.module';
import { PUSH_CAPABILITY_PORT } from './push-capability.port';

@Module({
  imports: [PushTransportInternalModule],
  providers: [
    {
      provide: PUSH_CAPABILITY_PORT,
      useExisting: PUSH_CAPABILITY_IMPLEMENTATION,
    },
  ],
  exports: [PUSH_CAPABILITY_PORT],
})
export class PushCapabilityPublicModule {}
