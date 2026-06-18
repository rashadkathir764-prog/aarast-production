import { GuestSide, GuestStatus } from '@prisma/client';
import { IsEnum, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpdateGuestDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  phone?: string | null;

  @IsEnum(GuestSide)
  @IsOptional()
  side?: GuestSide;

  @IsEnum(GuestStatus)
  @IsOptional()
  status?: GuestStatus;

  @IsInt()
  @Min(1)
  @Max(20)
  @IsOptional()
  seatsCount?: number;

  @IsString()
  @IsOptional()
  notes?: string | null;
}
