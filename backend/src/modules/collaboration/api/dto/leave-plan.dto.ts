import { IsInt, IsNotEmpty, IsString, MaxLength, Min } from "class-validator";

export class LeavePlanDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  expectedMemberId!: string;

  @IsInt()
  @Min(1)
  expectedAuthorityVersion!: number;
}
