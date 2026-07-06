import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateMediaUploadDto } from './dto/create-media-upload.dto';
import { MediaStorageService } from './media-storage.service';

@Controller('media/uploads')
@UseGuards(JwtAuthGuard)
export class MediaController {
  constructor(private readonly mediaStorage: MediaStorageService) {}

  @Post('presign')
  presign(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CreateMediaUploadDto,
  ) {
    return this.mediaStorage.createUpload(currentUser, dto);
  }
}
