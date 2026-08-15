import { Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { MediaLifecycleInternalModule } from '../modules/media/internal/media-lifecycle.internal.module';
import { MediaStorageInternalModule } from '../modules/media/internal/media-storage.internal.module';

@Module({
  imports: [MediaStorageInternalModule, MediaLifecycleInternalModule],
  controllers: [MediaController],
})
export class MediaModule {}
