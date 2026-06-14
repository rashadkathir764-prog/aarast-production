import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateProviderPackageDto {
  @IsString()
  @IsOptional()
  serviceId?: string | null;

  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  description?: string | null;

  @IsString()
  @IsOptional()
  price?: string | null;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsOptional()
  items?: unknown;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
