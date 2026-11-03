import {
  ArrayMaxSize,
  IsArray,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { CreateGuestDto } from './create-guest.dto';

/**
 * D83: a new guest with the plan's events they are invited to beyond the
 * wedding. `CreateGuestDto` itself is a closed R12B parity contract with the
 * local-plan import, so the events ride on this extension.
 */
export class CreateGuestWithEventsDto extends CreateGuestDto {
  /** Ids of the plan's events other than the wedding row; absent means none. */
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  @IsOptional()
  eventIds?: string[];
}
