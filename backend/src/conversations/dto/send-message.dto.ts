import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class ChatAttachmentDto {
  @IsUrl({ require_protocol: true })
  @MaxLength(2048)
  url!: string;

  @IsString()
  @MaxLength(100)
  contentType!: string;

  @IsInt()
  @Min(1)
  @Max(10 * 1024 * 1024)
  byteSize!: number;
}

export class SendMessageDto {
  @IsString()
  @MaxLength(2000)
  body!: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ChatAttachmentDto)
  attachments?: ChatAttachmentDto[];
}
