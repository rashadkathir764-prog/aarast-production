import { Inject, Logger } from '@nestjs/common';
import { AuthSessionScope } from '@prisma/client';
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
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import {
  IDENTITY_ACCESS_TOKEN_VERIFIER,
  IdentityAccessTokenVerifier,
} from '../modules/identity/public/identity-auth.port';
import { resolveJwtSessionScope } from '../modules/identity/public/access-token-scope';
import type { JwtPayload } from '../modules/identity/public/jwt-payload.interface';
import { toAuthenticatedUser } from '../modules/identity/public/safe-user';
import { getCorsOrigins } from '../platform/config/cors-origins';
import { PrismaService } from '../platform/database/prisma.service';
import {
  conversationRoom,
  sessionRoom,
  userRoom,
} from './conversation-rooms';
import { SendMessageDto } from './dto/send-message.dto';
import { ConversationsService } from './conversations.service';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';

type AuthenticatedSocket = Socket & {
  data: {
    user?: AuthenticatedUser;
    sessionId?: string;
    messageTimestamps?: number[];
  };
};

interface ConversationEvent {
  conversationId: string;
}

interface SendConversationMessageEvent extends ConversationEvent {
  body: string;
  attachments?: SendMessageDto['attachments'];
}

export { conversationRoom, sessionRoom, userRoom };

@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: getCorsOrigins(), credentials: true },
})
export class ConversationsGateway implements OnGatewayConnection, OnGatewayInit {
  private readonly logger = new Logger(ConversationsGateway.name);
  private readonly tokenExpiryTimers = new WeakMap<
    AuthenticatedSocket,
    NodeJS.Timeout
  >();

  @WebSocketServer()
  server!: Server;

  constructor(
    @Inject(IDENTITY_ACCESS_TOKEN_VERIFIER)
    private readonly jwt: IdentityAccessTokenVerifier,
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
      const [user, session] = await Promise.all([
        this.prisma.user.findUnique({
          where: { id: payload.sub },
        }),
        this.prisma.refreshToken.findFirst({
          where: {
            id: payload.sid!,
            userId: payload.sub,
            scope: AuthSessionScope.APPLICATION,
            revokedAt: null,
            expiresAt: { gt: new Date() },
          },
          select: { id: true },
        }),
      ]);
      // Mirror the HTTP JwtStrategy exactly: a disabled or phone-unverified
      // account must never hold a realtime channel either.
      if (
        !user ||
        user.status === 'DISABLED' ||
        !user.phoneVerifiedAt ||
        !session
      ) {
        throw new Error('Ineligible user');
      }
      socket.data.user = {
        ...toAuthenticatedUser(user),
        adminMfa: false,
        sessionScope: 'application',
      };
      socket.data.sessionId = payload.sid!;
      await socket.join(userRoom(user.id));
      await socket.join(sessionRoom(payload.sid!));
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
    const previousTimer = this.tokenExpiryTimers.get(socket);
    if (previousTimer) {
      clearTimeout(previousTimer);
    }
    const millisUntilExpiry = exp * 1000 - Date.now();
    const timer = setTimeout(
      () => {
        this.tokenExpiryTimers.delete(socket);
        socket.disconnect(true);
      },
      // Access tokens are currently fifteen minutes. Capping an unexpectedly
      // long signed token avoids the Node 32-bit timeout overflow without ever
      // granting an unbounded realtime session.
      Math.min(Math.max(0, millisUntilExpiry), 2_147_483_647),
    );
    // A pending expiry timer must never keep the Node process alive on its own
    // (e.g. during graceful shutdown); the socket server holds the loop open.
    timer.unref?.();
    this.tokenExpiryTimers.set(socket, timer);
    socket.on('disconnect', () => {
      if (this.tokenExpiryTimers.get(socket) !== timer) {
        return;
      }
      clearTimeout(timer);
      this.tokenExpiryTimers.delete(socket);
    });
  }

  @SubscribeMessage('conversation:join')
  async join(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() event: ConversationEvent,
  ) {
    const user = await this.liveSocketUser(socket);
    await this.conversations.authorize(user, event.conversationId);
    const room = conversationRoom(event.conversationId);
    await socket.join(room);
    try {
      // Authorization can be revoked after the first check but before the
      // room join. Rechecking after the socket is already present closes that
      // gap: a revocation before/during join is observed here, while a later
      // revocation removes the already-joined socket through socketsLeave.
      await this.conversations.authorize(user, event.conversationId);
    } catch (error) {
      await socket.leave(room);
      throw error;
    }
    return { conversationId: event.conversationId, joined: true };
  }

  @SubscribeMessage('conversation:message')
  async message(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() event: SendConversationMessageEvent,
  ) {
    const user = await this.liveSocketUser(socket);
    this.assertMessageRate(socket);
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
    const user = await this.liveSocketUser(socket);
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

  private async liveSocketUser(
    socket: AuthenticatedSocket,
  ): Promise<AuthenticatedUser> {
    const user = this.socketUser(socket);
    const sessionId = socket.data.sessionId;
    if (!sessionId) {
      socket.disconnect(true);
      throw new WsException('Session is invalid or expired');
    }
    const session = await this.prisma.refreshToken.findFirst({
      where: {
        id: sessionId,
        userId: user.id,
        scope: AuthSessionScope.APPLICATION,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { id: true },
    });
    if (!session) {
      socket.disconnect(true);
      throw new WsException('Session is invalid or expired');
    }
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
