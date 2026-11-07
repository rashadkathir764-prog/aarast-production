import {
  ArrayMaxSize,
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { GUEST_NAME_MAX, GUEST_NOTES_MAX } from '../../modules/guests/public/guest-text-limits';
import { MaxCharacters } from '../../shared-kernel/text/text-length';
import { CreateGuestDto } from './create-guest.dto';

/**
 * D83: a new guest with the plan's events they are invited to beyond the
 * wedding. `CreateGuestDto` itself is a closed R12B parity contract with the
 * local-plan import, so the events ride on this extension.
 *
 * RA-BE-15: so do the name's and the notes' lengths. class-validator drops a
 * parent's rules on a field the child redeclares, so each redeclared field
 * restates them all (`dto-text-bounds.test.ts` checks that it does).
 */
export class CreateGuestWithEventsDto extends CreateGuestDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(GUEST_NAME_MAX)
  name!: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(GUEST_NOTES_MAX)
  notes?: string | null;

  /** Ids of the plan's events other than the wedding row; absent means none. */
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  @IsOptional()
  eventIds?: string[];
}
