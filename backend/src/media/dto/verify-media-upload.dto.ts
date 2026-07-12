import { IsIn, IsString } from 'class-validator';
import { mediaPurposes, MediaPurpose } from '../media-upload-policy';

export class VerifyMediaUploadDto {
  @IsString()
  key!: string;

  @IsIn(mediaPurposes)
  purpose!: MediaPurpose;
}
