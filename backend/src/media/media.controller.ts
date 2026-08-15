import { Body, Controller, Header, Post, UseGuards } from "@nestjs/common";
import { Throttle } from '@nestjs/throttler';
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { CreateMediaUploadDto } from "./dto/create-media-upload.dto";
import { VerifyMediaUploadDto } from "./dto/verify-media-upload.dto";
import { MediaStorageService } from "./media-storage.service";

@Controller("api/v1/media/uploads")
@UseGuards(JwtAuthGuard)
export class MediaController {
  constructor(private readonly mediaStorage: MediaStorageService) {}

  @Post("presign")
  @Header("Cache-Control", "private, no-store")
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  presign(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CreateMediaUploadDto,
  ) {
    return this.mediaStorage.createUpload(currentUser, dto);
  }

  @Post("verify")
  @Header("Cache-Control", "private, no-store")
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  verify(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: VerifyMediaUploadDto,
  ) {
    return this.mediaStorage.verifyUpload(currentUser, dto.key, dto.purpose);
  }
}
