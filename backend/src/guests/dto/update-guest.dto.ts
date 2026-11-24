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
  IsObject,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { GUEST_NAME_MAX, GUEST_NOTES_MAX } from '../../modules/guests/public/guest-text-limits';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

export class UpdateGuestDto {
  /**
   * RA-MO-344: the value this edit last read of each field it changes. A
   * field changed since is refused (409 CHANGED_ELSEWHERE); omitted, the
   * edit is taken as before.
   */
  @IsObject()
  @IsOptional()
  expected?: Record<string, unknown>;
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

  /**
   * D116: the owner records the guest's answer to events beyond the wedding
   * (one the guest gave by phone or in person), as the wedding's own answer
   * is recorded with `attendanceStatus`. Each event must be one the guest is
   * invited to.
   */
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => GuestEventReplyDto)
  @IsOptional()
  eventReplies?: GuestEventReplyDto[];
}

export class GuestEventReplyDto {
  @IsString()
  @MaxLength(64)
  planEventId!: string;

  @IsEnum(GuestAttendanceStatus)
  attendanceStatus!: GuestAttendanceStatus;

  @IsInt()
  @Min(0)
  @Max(20)
  @IsOptional()
  companionsCount?: number;
}
