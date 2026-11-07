import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

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

  // RA-AD-16: the name as a provider's (admin-listed-provider.dto.ts), the
  // description as an application's (apply-provider.dto.ts).
  @IsString()
  @IsOptional()
  @MaxLength(160)
  title?: string;

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  description?: string | null;

  /** Its digits and decimals are the money rule's (shared-kernel/money). */
  @IsString()
  @IsOptional()
  basePrice?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(120)
  priceUnit?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(8)
  currency?: string;

  @IsString()
  @IsOptional()
  cityId?: string | null;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
