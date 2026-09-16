import { Module } from '@nestjs/common';
import {
  GUESTS_IMPLEMENTATION,
  GuestsPortInternalModule,
} from '../internal/guests-port.internal.module';
import { GUESTS_PORT } from './guests.port';

@Module({
  imports: [GuestsPortInternalModule],
  providers: [
    {
      provide: GUESTS_PORT,
      useExisting: GUESTS_IMPLEMENTATION,
    },
  ],
  exports: [GUESTS_PORT],
})
export class GuestsPublicModule {}
