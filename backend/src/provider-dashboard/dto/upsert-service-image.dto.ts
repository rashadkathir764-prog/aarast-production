import { IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';

export class CreateServiceImageDto {
  @IsString()
  @IsNotEmpty()
  imageUrl!: string;

  @IsString()
  @IsOptional()
  altText?: string | null;

  @IsInt()
  @Min(0)
  @IsOptional()
  sortOrder?: number;
}

export class UpdateServiceImageDto {
  @IsString()
  @IsOptional()
  imageUrl?: string;

  @IsString()
  @IsOptional()
  altText?: string | null;

  @IsInt()
  @Min(0)
  @IsOptional()
  sortOrder?: number;
}
