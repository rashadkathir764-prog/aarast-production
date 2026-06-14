import { IsOptional, IsString } from 'class-validator';

export class AdminReviewActionDto {
  @IsString()
  @IsOptional()
  reason?: string;

  @IsString()
  @IsOptional()
  note?: string;
}
