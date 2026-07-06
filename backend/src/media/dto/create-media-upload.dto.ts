import { IsIn, IsInt, IsString, Max, MaxLength, Min } from 'class-validator';
import { mediaPurposes } from '../media-upload-policy';

export class CreateMediaUploadDto {
  @IsIn(mediaPurposes)
  purpose!: string;

  @IsString()
  @MaxLength(255)
  fileName!: string;

  @IsString()
  @MaxLength(100)
  contentType!: string;

  @IsInt()
  @Min(1)
  @Max(10 * 1024 * 1024)
  byteSize!: number;
}
