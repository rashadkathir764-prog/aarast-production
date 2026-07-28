import { Injectable } from '@nestjs/common';
import { Server } from 'socket.io';
import {
  conversationRoom,
  sessionRoom,
  userRoom,
} from './conversation-rooms';

export class RealtimeServerUnavailableError extends Error {
  constructor() {
    super('Realtime server is not attached');
    this.name = 'RealtimeServerUnavailableError';
  }
}

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

  event(conversationId: string, event: unknown) {
    this.server
      ?.to(conversationRoom(conversationId))
      .emit('conversation:event', event);
  }

  activityAvailable(conversationId: string, event: unknown) {
    this.server
      ?.to(conversationRoom(conversationId))
      .emit('conversation:activity-available', event);
  }

  revokeConversationAccess(userId: string, conversationIds: string[]) {
    const userSockets = this.server?.in(userRoom(userId));
    for (const conversationId of conversationIds) {
      userSockets?.emit('conversation:permission-revoked', { conversationId });
      userSockets?.socketsLeave(conversationRoom(conversationId));
    }
  }

  messageAvailable(conversationId: string, event: unknown) {
    this.server
      ?.to(conversationRoom(conversationId))
      .emit('conversation:message-available', event);
  }

  notificationAvailable(userId: string, event: unknown) {
    this.server?.to(userRoom(userId)).emit('notification:available', event);
  }

  async dispatchMessageAvailable(
    conversationId: string,
    event: unknown,
  ): Promise<void> {
    const room = conversationRoom(conversationId);
    const server = await this.serverWithAvailableAdapter(room);
    server.to(room).emit('conversation:message-available', event);
  }

  async dispatchActivityAvailable(
    conversationId: string,
    event: unknown,
    includeLifecycleEvent: boolean,
  ): Promise<void> {
    const room = conversationRoom(conversationId);
    const server = await this.serverWithAvailableAdapter(room);
    if (includeLifecycleEvent) {
      server.to(room).emit('conversation:event', event);
    }
    server.to(room).emit('conversation:activity-available', event);
  }

  async dispatchNotificationAvailable(
    userId: string,
    event: unknown,
  ): Promise<void> {
    const room = userRoom(userId);
    const server = await this.serverWithAvailableAdapter(room);
    server.to(room).emit('notification:available', event);
  }

  async dispatchConversationAccessRevoked(
    userId: string,
    conversationIds: string[],
  ): Promise<void> {
    const sockets = await this.fetchSockets(userRoom(userId));
    for (const conversationId of conversationIds) {
      await Promise.all(
        sockets.map(async (socket) => {
          socket.emit('conversation:permission-revoked', { conversationId });
          await socket.leave(conversationRoom(conversationId));
        }),
      );
    }
  }

  async dispatchUserSessionsRevoked(userId: string): Promise<void> {
    const sockets = await this.fetchSockets(userRoom(userId));
    await Promise.all(
      sockets.map(async (socket) => {
        await socket.disconnect(true);
      }),
    );
  }

  async dispatchSessionRevoked(sessionId: string): Promise<void> {
    const sockets = await this.fetchSockets(sessionRoom(sessionId));
    await Promise.all(
      sockets.map(async (socket) => {
        await socket.disconnect(true);
      }),
    );
  }

  /**
   * Force every live socket owned by this user to disconnect across all
   * replicas (the Redis adapter fans `disconnectSockets` out cluster-wide).
   * Called after password reset, logout everywhere, or an administrator
   * disabling the account, so a socket
   * opened on a lost device cannot outlive the credentials that authorized it.
   */
  disconnectUser(userId: string) {
    void this.server?.to(userRoom(userId)).disconnectSockets(true);
  }

  disconnectSession(sessionId: string) {
    void this.server?.to(sessionRoom(sessionId)).disconnectSockets(true);
  }

  private attachedServer(): Server {
    if (!this.server) {
      throw new RealtimeServerUnavailableError();
    }
    return this.server;
  }

  private async fetchSockets(room: string) {
    const sockets = await this.attachedServer().in(room).fetchSockets();
    return [...sockets].sort((left, right) => left.id.localeCompare(right.id));
  }

  private async serverWithAvailableAdapter(room: string): Promise<Server> {
    const server = this.attachedServer();
    await server.in(room).fetchSockets();
    return server;
  }
}
