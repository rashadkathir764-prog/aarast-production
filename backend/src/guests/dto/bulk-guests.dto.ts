import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsNotEmpty,
  ValidateNested,
} from 'class-validator';
import { CreateGuestDto } from './create-guest.dto';

export class BulkGuestsDto {
  @IsArray()
  @ArrayMaxSize(200)
  @IsNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => CreateGuestDto)
  items!: CreateGuestDto[];
}
