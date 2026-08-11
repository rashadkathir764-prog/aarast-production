import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CatalogBootstrapQueryDto {
  @IsString()
  @IsOptional()
  @MaxLength(128)
  version?: string;
}
