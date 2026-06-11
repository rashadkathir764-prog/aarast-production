import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateProviderServiceDto {
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
