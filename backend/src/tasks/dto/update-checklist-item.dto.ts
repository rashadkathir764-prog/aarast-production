import { IsBoolean, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpdateChecklistItemDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsBoolean()
  @IsOptional()
  isDone?: boolean;

  @IsInt()
  @Min(0)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}
