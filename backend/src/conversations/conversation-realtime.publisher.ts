import { Injectable } from '@nestjs/common';
import { Server } from 'socket.io';
import { conversationRoom, userRoom } from './conversation-rooms';

@Injectable()
export class ConversationRealtimePublisher {
  private server?: Server;

  attach(server: Server) {
    this.server = server;
  }

  message(conversationId: string, message: unknown) {
    this.server
      ?.to(conversationRoom(conversationId))
      .emit('conversation:message', message);
  }

  read(conversationId: string, receipt: unknown) {
    this.server
      ?.to(conversationRoom(conversationId))
      .emit('conversation:read', receipt);
  }

  messageAvailable(conversationId: string, event: unknown) {
    this.server
      ?.to(conversationRoom(conversationId))
      .emit('conversation:message-available', event);
  }

  notificationAvailable(userId: string, event: unknown) {
    this.server?.to(userRoom(userId)).emit('notification:available', event);
  }

  /**
   * Force every live socket owned by this user to disconnect across all
   * replicas (the Redis adapter fans `disconnectSockets` out cluster-wide).
   * Called when the user's sessions are revoked — password reset, logout
   * everywhere, or an administrator disabling the account — so a socket
   * opened on a lost device cannot outlive the credentials that authorized it.
   */
  disconnectUser(userId: string) {
    void this.server?.to(userRoom(userId)).disconnectSockets(true);
  }
}
