import {
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
} from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class UpdateGuestDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @MaxLength(40)
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

  /** D83: replaces the guest's events beyond the wedding; absent, they stay. */
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  @IsOptional()
  eventIds?: string[];
}
