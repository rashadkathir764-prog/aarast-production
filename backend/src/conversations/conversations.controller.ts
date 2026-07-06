import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  ConversationToggleDto,
  ReportConversationDto,
} from './dto/conversation-action.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { ConversationsService } from './conversations.service';

@Controller('conversations')
@UseGuards(JwtAuthGuard)
export class ConversationsController {
  constructor(private readonly conversations: ConversationsService) {}

  @Post('quote-requests/:quoteRequestId')
  ensureForQuote(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('quoteRequestId') quoteRequestId: string,
  ) {
    return this.conversations.ensureForQuote(currentUser, quoteRequestId);
  }

  @Get()
  list(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.conversations.list(currentUser);
  }

  @Get(':id/messages')
  messages(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.conversations.messages(currentUser, id, cursor, limit);
  }

  @Post(':id/messages')
  send(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.conversations.send(currentUser, id, dto);
  }

  @Patch(':id/read')
  markRead(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
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
