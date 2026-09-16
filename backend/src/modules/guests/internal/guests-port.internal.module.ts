import { Module } from '@nestjs/common';
import { GuestsPortService } from './guests-port.service';

export const GUESTS_IMPLEMENTATION = Symbol('GUESTS_IMPLEMENTATION');

@Module({
  providers: [
    GuestsPortService,
    {
      provide: GUESTS_IMPLEMENTATION,
      useExisting: GuestsPortService,
    },
  ],
  exports: [GuestsPortService, GUESTS_IMPLEMENTATION],
})
export class GuestsPortInternalModule {}
