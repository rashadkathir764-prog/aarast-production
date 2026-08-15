import { Module } from '@nestjs/common';
import {
  MEDIA_STORAGE_IMPLEMENTATION,
  MediaStorageInternalModule,
} from '../internal/media-storage.internal.module';
import { MEDIA_STORAGE_PORT } from './media-storage.port';

@Module({
  imports: [MediaStorageInternalModule],
  providers: [
    {
      provide: MEDIA_STORAGE_PORT,
      useExisting: MEDIA_STORAGE_IMPLEMENTATION,
    },
  ],
  exports: [MEDIA_STORAGE_PORT],
})
export class MediaStoragePublicModule {}
