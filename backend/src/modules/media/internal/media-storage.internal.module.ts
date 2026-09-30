import { Module } from '@nestjs/common';
import { MediaStorageService } from '../../../media/media-storage.service';
import { MediaUploadTicketService } from '../infrastructure/media-upload-ticket.service';
import { PrismaModule } from '../../../platform/database/prisma.module';

export const MEDIA_STORAGE_IMPLEMENTATION = Symbol(
  'MEDIA_STORAGE_IMPLEMENTATION',
);

@Module({
  imports: [PrismaModule],
  providers: [
    MediaUploadTicketService,
    MediaStorageService,
    {
      provide: MEDIA_STORAGE_IMPLEMENTATION,
      useExisting: MediaStorageService,
    },
  ],
  exports: [
    MediaUploadTicketService,
    MediaStorageService,
    MEDIA_STORAGE_IMPLEMENTATION,
  ],
})
export class MediaStorageInternalModule {}
