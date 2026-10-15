import { IsOptional, IsString, MaxLength } from 'class-validator';

/** A provider the back office lists before its owner has an account (V1 checklist 4.18). */
export class AdminListedProviderDto {
  @IsString()
  @MaxLength(160)
  businessName!: string;

  @IsString()
  @MaxLength(32)
  phone!: string;

  @IsString()
  @IsOptional()
  @MaxLength(32)
  whatsapp?: string | null;

  @IsString()
  cityId!: string;

  @IsString()
  categoryId!: string;

  @IsString()
  @IsOptional()
  @MaxLength(4000)
  description?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(300)
  address?: string | null;
}
