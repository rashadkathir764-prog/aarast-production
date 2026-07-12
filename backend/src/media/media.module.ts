import { Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { MediaStorageService } from './media-storage.service';
import { MediaUploadCleanupScheduler } from './media-upload-cleanup.scheduler';
import { MediaUploadTicketService } from './media-upload-ticket.service';

@Module({
  controllers: [MediaController],
  providers: [
    MediaStorageService,
    MediaUploadTicketService,
    MediaUploadCleanupScheduler,
  ],
  exports: [MediaStorageService],
})
export class MediaModule {}
