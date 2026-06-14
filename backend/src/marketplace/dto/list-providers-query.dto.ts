import { IsOptional, IsString } from 'class-validator';

export class ListProvidersQueryDto {
  @IsString()
  @IsOptional()
  cityId?: string;

  @IsString()
  @IsOptional()
  categoryId?: string;

  @IsString()
  @IsOptional()
  search?: string;

  @IsString()
  @IsOptional()
  featured?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}
