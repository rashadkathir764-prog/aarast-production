import { Module } from '@nestjs/common';
import { MediaController } from '../../media/media.controller';
import { MediaLifecycleInternalModule } from './internal/media-lifecycle.internal.module';
import { MediaStorageInternalModule } from './internal/media-storage.internal.module';

@Module({
  imports: [MediaStorageInternalModule, MediaLifecycleInternalModule],
  controllers: [MediaController],
})
export class MediaModule {}
