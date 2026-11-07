import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

export class ChatAttachmentDto {
  @IsString()
  @MaxLength(512)
  attachmentRef!: string;

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
  @MaxCharacters(2000)
  body!: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ChatAttachmentDto)
  attachments?: ChatAttachmentDto[];
}
