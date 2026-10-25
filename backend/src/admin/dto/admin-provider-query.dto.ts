import { IsOptional, IsString } from 'class-validator';

export class AdminProviderQueryDto {
  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  cityId?: string;

  @IsString()
  @IsOptional()
  categoryId?: string;

  @IsString()
  @IsOptional()
  search?: string;

  /** `true`: only profiles sent back after changes (B-01); `false`: only the others. */
  @IsString()
  @IsOptional()
  resubmitted?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}
