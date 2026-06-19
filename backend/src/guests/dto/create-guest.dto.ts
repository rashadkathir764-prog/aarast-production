import {
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
} from '@prisma/client';
import { IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';

export class CreateGuestDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsOptional()
  phone?: string | null;

  @IsString()
  @IsOptional()
  groupId?: string | null;

  @IsEnum(GuestSide)
  @IsOptional()
  side?: GuestSide;

  @IsEnum(GuestStatus)
  @IsOptional()
  status?: GuestStatus;

  @IsEnum(GuestInvitationStatus)
  @IsOptional()
  invitationStatus?: GuestInvitationStatus;

  @IsEnum(GuestAttendanceStatus)
  @IsOptional()
  attendanceStatus?: GuestAttendanceStatus;

  @IsInt()
  @Min(1)
  @Max(20)
  @IsOptional()
  seatsCount?: number;

  @IsInt()
  @Min(0)
  @Max(20)
  @IsOptional()
  companionsCount?: number;

  @IsString()
  @IsOptional()
  notes?: string | null;
}
