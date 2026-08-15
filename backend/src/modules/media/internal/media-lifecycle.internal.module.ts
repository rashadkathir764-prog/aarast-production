import { Module } from '@nestjs/common';
import { MediaUploadCleanupScheduler } from '../../../media/media-upload-cleanup.scheduler';
import { MediaStorageInternalModule } from './media-storage.internal.module';

@Module({
  imports: [MediaStorageInternalModule],
  providers: [MediaUploadCleanupScheduler],
})
export class MediaLifecycleInternalModule {}
