import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: what a provider writes is read by every customer, so it has a
// bound: the back office's own (admin-service.dto.ts), above the phone's
// fields (the description stops at 280 there).
export class CreateProviderServiceDto {
  @IsString()
  @IsNotEmpty()
  categoryId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
  title!: string;

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
  @MaxLength(8)
  currency?: string;

  @IsString()
  @IsOptional()
  cityId?: string | null;
}
