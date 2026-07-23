import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ConversationToggleDto, ReportConversationDto } from './dto/conversation-action.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { ConversationsService } from './conversations.service';

@Controller('api/v1/conversations')
@UseGuards(JwtAuthGuard)
export class ConversationsController {
  constructor(private readonly conversations: ConversationsService) {}

  @Get()
  @Header('Cache-Control', 'private, no-store')
  list(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.conversations.list(currentUser, cursor, limit);
  }

  @Get(':id')
  @Header('Cache-Control', 'private, no-store')
  get(@CurrentUser() currentUser: AuthenticatedUser, @Param('id') id: string) {
    return this.conversations.get(currentUser, id);
  }

  @Get(':id/messages')
  @Header('Cache-Control', 'private, no-store')
  messages(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.conversations.messages(currentUser, id, cursor, limit);
  }

  @Get(':id/quote-requests')
  @Header('Cache-Control', 'private, no-store')
  quoteRequests(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.conversations.quoteRequests(currentUser, id);
  }

  @Get(':id/timeline')
  @Header('Cache-Control', 'private, no-store')
  timeline(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.conversations.timeline(currentUser, id, cursor, limit);
  }

  @Post(':id/messages')
  @Header('Cache-Control', 'private, no-store')
  send(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.conversations.send(currentUser, id, dto);
  }

  @Get(':id/attachments/:attachmentId/download')
  @Header('Cache-Control', 'private, no-store')
  downloadAttachment(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Param('attachmentId') attachmentId: string,
  ) {
    return this.conversations.downloadAttachment(currentUser, id, attachmentId);
  }

  @Patch(':id/read')
  markRead(@CurrentUser() currentUser: AuthenticatedUser, @Param('id') id: string) {
    return this.conversations.markRead(currentUser, id);
  }

  @Patch(':id/mute')
  mute(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: ConversationToggleDto,
  ) {
    return this.conversations.setMuted(currentUser, id, dto.enabled);
  }

  @Patch(':id/block')
  block(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: ConversationToggleDto,
  ) {
    return this.conversations.setBlocked(currentUser, id, dto.enabled);
  }

  @Post(':id/report')
  report(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: ReportConversationDto,
  ) {
    return this.conversations.report(currentUser, id, dto.reason);
  }
}

@Controller('api/v1/quote-requests')
@UseGuards(JwtAuthGuard)
export class QuoteRequestConversationsController {
  constructor(private readonly conversations: ConversationsService) {}

  @Get(':quoteRequestId/conversation')
  @Header('Cache-Control', 'private, no-store')
  getForQuote(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('quoteRequestId') quoteRequestId: string,
  ) {
    return this.conversations.getForQuote(currentUser, quoteRequestId);
  }
}
