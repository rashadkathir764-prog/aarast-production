import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';

/** The fields a review note can point at (B-01); the whole profile is `note`. */
export const ADMIN_REVIEW_NOTE_FIELDS = [
  'BUSINESS_NAME',
  'CATEGORY',
  'CITY',
  'DESCRIPTION',
  'SERVICE',
] as const;

export class AdminFieldNoteDto {
  @IsIn(ADMIN_REVIEW_NOTE_FIELDS)
  field!: (typeof ADMIN_REVIEW_NOTE_FIELDS)[number];

  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  note!: string;
}

/** «اطلب تعديل»: a note about the whole profile, one per field to fix, or both. */
export class AdminRequestChangesDto {
  @IsString()
  @IsOptional()
  @MaxLength(2000)
  note?: string;

  @IsArray()
  @IsOptional()
  @ArrayMaxSize(ADMIN_REVIEW_NOTE_FIELDS.length)
  @ValidateNested({ each: true })
  @Type(() => AdminFieldNoteDto)
  fieldNotes?: AdminFieldNoteDto[];
}
