import { Module } from '@nestjs/common';
import {
  ConversationsController,
  QuoteRequestConversationsController,
} from '../../conversations/conversations.controller';
import { MessagingConversationsInternalModule } from './internal/messaging-conversations.internal.module';
import { MessagingErasurePublicModule } from './public/messaging-erasure-public.module';

@Module({
  imports: [MessagingErasurePublicModule, MessagingConversationsInternalModule],
  controllers: [ConversationsController, QuoteRequestConversationsController],
})
export class MessagingModule {}
