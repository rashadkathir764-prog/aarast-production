import { Module } from '@nestjs/common';
import {
  MESSAGING_ADMIN_IMPLEMENTATION,
  MessagingPortsInternalModule,
} from '../internal/messaging-ports.internal.module';
import { MESSAGING_ADMIN_PORT } from './messaging-admin.port';

@Module({
  imports: [MessagingPortsInternalModule],
  providers: [
    {
      provide: MESSAGING_ADMIN_PORT,
      useExisting: MESSAGING_ADMIN_IMPLEMENTATION,
    },
  ],
  exports: [MESSAGING_ADMIN_PORT],
})
export class MessagingAdminPublicModule {}
