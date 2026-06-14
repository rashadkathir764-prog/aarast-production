import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateProviderServiceDto {
  @IsString()
  @IsNotEmpty()
  categoryId!: string;

  @IsString()
  @IsNotEmpty()
  title!: string;

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
}
