import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class UpdateGuestGroupDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  notes?: string | null;

  @IsInt()
  @Min(0)
  @IsOptional()
  sortOrder?: number;
}
