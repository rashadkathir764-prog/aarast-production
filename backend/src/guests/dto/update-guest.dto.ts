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
import { GUEST_NAME_MAX, GUEST_NOTES_MAX } from '../../modules/guests/public/guest-text-limits';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

export class UpdateGuestDto {
  /**
   * RA-BE-15: as the phone's field (guest_form_sheet.dart) and its contacts
   * import; a new guest's name is held to the same in GuestsService, its
   * request being byte-pinned by the R12B parity proof.
   */
  @IsString()
  @MaxCharacters(GUEST_NAME_MAX)
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
  @MaxCharacters(GUEST_NOTES_MAX)
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
