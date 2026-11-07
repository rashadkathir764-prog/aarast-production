import { IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';
import { GUEST_GROUP_NAME_MAX, GUEST_NOTES_MAX } from '../../modules/guests/public/guest-text-limits';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

export class CreateGuestGroupDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(GUEST_GROUP_NAME_MAX)
  name!: string;

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
