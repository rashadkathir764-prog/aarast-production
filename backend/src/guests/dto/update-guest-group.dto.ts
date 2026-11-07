import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { GUEST_GROUP_NAME_MAX, GUEST_NOTES_MAX } from '../../modules/guests/public/guest-text-limits';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

export class UpdateGuestGroupDto {
  @IsString()
  @MaxCharacters(GUEST_GROUP_NAME_MAX)
  @IsOptional()
  name?: string;

  @IsString()
  @MaxCharacters(GUEST_NOTES_MAX)
  @IsOptional()
  notes?: string | null;

  @IsInt()
  @Min(0)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}
