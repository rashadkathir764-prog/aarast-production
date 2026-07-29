import { PushPlatform } from "@prisma/client";
import { IsEnum, IsString, Length, Matches } from "class-validator";

export class PushInstallationDto {
  @IsString()
  @Length(10, 200)
  @Matches(/^[A-Za-z0-9_-]+$/)
  fid!: string;

  @IsEnum(PushPlatform)
  platform!: PushPlatform;
}
