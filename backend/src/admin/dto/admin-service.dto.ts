import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class AdminServiceQueryDto {
  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  providerId?: string;

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
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}

export class AdminServiceDto {
  @IsString()
  @IsOptional()
  providerId?: string;

  @IsString()
  @IsOptional()
  categoryId?: string;

  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  description?: string | null;

  @IsString()
  @IsOptional()
  basePrice?: string | null;

  @IsString()
  @IsOptional()
  priceUnit?: string | null;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsString()
  @IsOptional()
  cityId?: string | null;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
