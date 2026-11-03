import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsNotEmpty,
  ValidateNested,
} from 'class-validator';
import { CreateGuestWithEventsDto } from './create-guest-with-events.dto';

export class BulkGuestsDto {
  @IsArray()
  @ArrayMaxSize(200)
  @IsNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => CreateGuestWithEventsDto)
  items!: CreateGuestWithEventsDto[];
}
