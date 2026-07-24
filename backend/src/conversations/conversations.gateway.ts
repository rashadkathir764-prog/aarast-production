import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { resolveJwtSessionScope } from '../auth/access-token-scope';
import type { JwtPayload } from '../auth/jwt-payload.interface';
import { toAuthenticatedUser } from '../auth/safe-user';
import { getCorsOrigins } from '../common/config/cors-origins';
import { PrismaService } from '../prisma/prisma.service';
import { conversationRoom, userRoom } from './conversation-rooms';
import { SendMessageDto } from './dto/send-message.dto';
import { ConversationsService } from './conversations.service';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';

type AuthenticatedSocket = Socket & {
  data: {
    user?: AuthenticatedUser;
    messageTimestamps?: number[];
    expiryTimer?: NodeJS.Timeout;
  };
};

interface ConversationEvent {
  conversationId: string;
}

interface SendConversationMessageEvent extends ConversationEvent {
  body: string;
  attachments?: SendMessageDto['attachments'];
}

export { conversationRoom, userRoom };

@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: getCorsOrigins(), credentials: true },
})
export class ConversationsGateway implements OnGatewayConnection, OnGatewayInit {
  private readonly logger = new Logger(ConversationsGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly conversations: ConversationsService,
    private readonly realtime: ConversationRealtimePublisher,
  ) {}

  afterInit(server: Server) {
    this.realtime.attach(server);
  }

  async handleConnection(socket: AuthenticatedSocket) {
    try {
      const token = this.socketToken(socket);
      const payload = await this.jwt.verifyAsync<
        Partial<JwtPayload> & { exp?: number }
      >(token);
      if (
        !payload.sub ||
        typeof payload.exp !== 'number' ||
        !Number.isFinite(payload.exp) ||
        resolveJwtSessionScope(payload as JwtPayload) !== 'application'
      ) {
        throw new Error('Missing required token claims');
      }
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
      });
      // Mirror the HTTP JwtStrategy exactly: a disabled or phone-unverified
      // account must never hold a realtime channel either.
      if (!user || user.status === 'DISABLED' || !user.phoneVerifiedAt) {
        throw new Error('Ineligible user');
      }
      socket.data.user = {
        ...toAuthenticatedUser(user),
        adminMfa: false,
        sessionScope: 'application',
      };
      await socket.join(userRoom(user.id));
      this.scheduleTokenExpiryDisconnect(socket, payload.exp);
      socket.emit('chat:ready', { userId: user.id });
    } catch (error) {
      this.logger.warn(`Rejected chat socket ${socket.id}`);
      socket.disconnect(true);
    }
  }

  /**
   * Bind the socket's lifetime to the access token that authorized it. The
   * token was already validated as unexpired; once it lapses the client must
   * reconnect with a freshly minted token, so a revoked or aged session can no
   * longer keep an authenticated channel open indefinitely.
   */
  private scheduleTokenExpiryDisconnect(
    socket: AuthenticatedSocket,
    exp: number,
  ): void {
    const millisUntilExpiry = exp * 1000 - Date.now();
    const timer = setTimeout(
      () => socket.disconnect(true),
      // Access tokens are currently fifteen minutes. Capping an unexpectedly
      // long signed token avoids the Node 32-bit timeout overflow without ever
      // granting an unbounded realtime session.
      Math.min(Math.max(0, millisUntilExpiry), 2_147_483_647),
    );
    // A pending expiry timer must never keep the Node process alive on its own
    // (e.g. during graceful shutdown); the socket server holds the loop open.
    timer.unref?.();
    socket.data.expiryTimer = timer;
    socket.on('disconnect', () => clearTimeout(timer));
  }

  @SubscribeMessage('conversation:join')
  async join(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() event: ConversationEvent,
  ) {
    const user = this.socketUser(socket);
    await this.conversations.authorize(user, event.conversationId);
    await socket.join(conversationRoom(event.conversationId));
    return { conversationId: event.conversationId, joined: true };
  }

  @SubscribeMessage('conversation:message')
  async message(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() event: SendConversationMessageEvent,
  ) {
    this.assertMessageRate(socket);
    const user = this.socketUser(socket);
    const message = await this.conversations.send(user, event.conversationId, {
      body: event.body,
      attachments: event.attachments,
    });
    return message;
  }

  @SubscribeMessage('conversation:read')
  async read(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() event: ConversationEvent,
  ) {
    const user = this.socketUser(socket);
    const receipt = await this.conversations.markRead(user, event.conversationId);
    return receipt;
  }

  private socketToken(socket: AuthenticatedSocket) {
    const authToken = socket.handshake.auth?.token;
    const header = socket.handshake.headers.authorization;
    const raw = typeof authToken === 'string' ? authToken : header;
    if (!raw) throw new WsException('Authentication required');
    return raw.startsWith('Bearer ') ? raw.slice(7) : raw;
  }

  private socketUser(socket: AuthenticatedSocket) {
    const user = socket.data.user;
    if (!user) throw new WsException('Authentication required');
    return user;
  }

  private assertMessageRate(socket: AuthenticatedSocket) {
    const now = Date.now();
    const active = (socket.data.messageTimestamps ?? []).filter(
      (timestamp: number) => now - timestamp < 60_000,
    );
    if (active.length >= 20) {
      throw new WsException('Message rate limit exceeded');
    }
    socket.data.messageTimestamps = [...active, now];
  }
}
