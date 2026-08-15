import { IsIn, IsString } from 'class-validator';
import { mediaPurposes } from '../media-upload-policy';
import type { MediaPurpose } from '../../modules/media/public/media-storage.port';

export class VerifyMediaUploadDto {
  @IsString()
  key!: string;

  @IsIn(mediaPurposes)
  purpose!: MediaPurpose;
}
