import { IsBoolean, IsOptional, IsString } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';
import { SupportedCurrency } from '../../shared-kernel/money/currency';

// RA-BE-15: bounded as the service is created (create-provider-service.dto.ts).
export class UpdateProviderServiceDto {
  @IsString()
  @IsOptional()
  categoryId?: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(160)
  title?: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(2000)
  description?: string | null;

  @IsString()
  @IsOptional()
  basePrice?: string | null;

  @IsString()
  @IsOptional()
  @MaxCharacters(120)
  priceUnit?: string | null;

  @IsString()
  @IsOptional()
  @SupportedCurrency()
  currency?: string;

  @IsString()
  @IsOptional()
  cityId?: string | null;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
