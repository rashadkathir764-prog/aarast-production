import { Injectable } from '@nestjs/common';
import { Server } from 'socket.io';

@Injectable()
export class ConversationRealtimePublisher {
  private server?: Server;

  attach(server: Server) {
    this.server = server;
  }

  message(conversationId: string, message: unknown) {
    this.server
      ?.to(`conversation:${conversationId}`)
      .emit('conversation:message', message);
  }

  read(conversationId: string, receipt: unknown) {
    this.server
      ?.to(`conversation:${conversationId}`)
      .emit('conversation:read', receipt);
  }
}
