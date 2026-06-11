import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateProviderPackageDto {
  @IsString()
  @IsOptional()
  serviceId?: string | null;

  @IsString()
  @IsNotEmpty()
  title!: string;

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
}
