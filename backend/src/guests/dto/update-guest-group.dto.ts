import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpdateGuestGroupDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  notes?: string | null;

  @IsInt()
  @Min(0)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}
