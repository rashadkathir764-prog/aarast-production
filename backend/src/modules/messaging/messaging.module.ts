import { Module } from '@nestjs/common';
import {
  ConversationsController,
  QuoteRequestConversationsController,
} from '../../conversations/conversations.controller';
import { MessagingConversationsInternalModule } from './internal/messaging-conversations.internal.module';

@Module({
  imports: [MessagingConversationsInternalModule],
  controllers: [ConversationsController, QuoteRequestConversationsController],
})
export class MessagingModule {}
