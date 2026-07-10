import { IsNotEmpty, IsString, MaxLength } from "class-validator";

export class UserLookupDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  weddingPlanId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;
}
