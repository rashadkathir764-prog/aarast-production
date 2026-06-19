import { IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';

export class CreateGuestGroupDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsOptional()
  notes?: string | null;

  @IsInt()
  @Min(0)
  @IsOptional()
  sortOrder?: number;
}
