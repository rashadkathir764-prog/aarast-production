import { IsOptional, IsString } from 'class-validator';

export class AdminReviewQueryDto {
  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  providerId?: string;

  @IsString()
  @IsOptional()
  search?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}

export class AdminReviewStatusDto {
  @IsString()
  status!: string;
}
