import { IsString, MaxLength, MinLength } from "class-validator";

export class ValidateContextDto {
  @IsString()
  @MinLength(1)
  @MaxLength(300)
  contextKey!: string;
}
