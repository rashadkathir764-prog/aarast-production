import { IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * «رفض» and «إيقاف»: the reason is the provider's general review note, the
 * same note «اطلب تعديل» stops at 2000 (admin-request-changes.dto.ts).
 */
export class AdminReviewActionDto {
  @IsString()
  @IsOptional()
  @MaxLength(2000)
  reason?: string;

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  note?: string;
}
