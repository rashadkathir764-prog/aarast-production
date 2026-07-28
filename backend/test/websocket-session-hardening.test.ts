import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NotFoundException } from '@nestjs/common';
import { ConversationRealtimePublisher } from '../src/conversations/conversation-realtime.publisher';
import { ConversationsGateway } from '../src/conversations/conversations.gateway';

interface FakeSocket {
  id: string;
  handshake: { auth: { token: string }; headers: Record<string, string> };
  data: Record<string, unknown>;
  joined: string[];
  left: string[];
  emitted: Array<{ event: string; payload: unknown }>;
  disconnected: number;
  join: (room: string) => Promise<void>;
  leave: (room: string) => Promise<void>;
  emit: (event: string, payload: unknown) => void;
  disconnect: () => void;
  on: (event: string, cb: () => void) => void;
}

function createSocket(): FakeSocket {
  const socket: FakeSocket = {
    id: 'sock-1',
    handshake: { auth: { token: 'jwt-token' }, headers: {} },
    data: {},
    joined: [],
    left: [],
    emitted: [],
    disconnected: 0,
    join: async (room: string) => {
      socket.joined.push(room);
    },
    leave: async (room: string) => {
      socket.left.push(room);
    },
    emit: (event: string, payload: unknown) => {
      socket.emitted.push({ event, payload });
    },
    disconnect: () => {
      socket.disconnected += 1;
    },
    on: () => undefined,
  };
  return socket;
}

function createGateway(options: {
  payload: unknown;
  user: unknown;
  session?: unknown | (() => unknown);
  conversations?: unknown;
}) {
  const jwt = { verifyAsync: async () => options.payload } as any;
  const prisma = {
    user: { findUnique: async () => options.user },
    refreshToken: {
      findFirst: async () => {
        const session =
          typeof options.session === 'function'
            ? options.session()
            : options.session;
        return session === undefined ? { id: 'app-session' } : session;
      },
    },
  } as any;
  const conversations = (options.conversations ?? {}) as any;
  const realtime = { attach: () => undefined } as any;
  return new ConversationsGateway(jwt, prisma, conversations, realtime);
}

function eligibleUser(overrides: Record<string, unknown> = {}) {
  return {
    id: 'u1',
    name: 'User',
    phone: '+967700000000',
    email: null,
    appName: null,
    appEmail: null,
    appAvatarUrl: null,
    avatarUrl: null,
    role: 'USER',
    adminRole: null,
    appRole: 'WEDDING_USER',
    status: 'ACTIVE',
    phoneVerifiedAt: new Date(),
    lastLoginAt: null,
    locale: 'ar',
    activeWeddingPlanId: null,
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

const futureExp = () => Math.floor(Date.now() / 1000) + 900;
const applicationPayload = (overrides: Record<string, unknown> = {}) => ({
  sub: 'u1',
  scope: 'application',
  sid: 'app-session',
  exp: futureExp(),
  ...overrides,
});

test('permission revocation removes every user socket from the conversation room', () => {
  const calls = {
    userRoom: '',
    events: [] as Array<{ event: string; payload: unknown }>,
    leftRooms: [] as string[],
  };
  const publisher = new ConversationRealtimePublisher();
  publisher.attach({
    in: (room: string) => {
      calls.userRoom = room;
      return {
        emit: (event: string, payload: unknown) => {
          calls.events.push({ event, payload });
        },
        socketsLeave: (conversationRoom: string) => {
          calls.leftRooms.push(conversationRoom);
        },
      };
    },
  } as never);

  publisher.revokeConversationAccess('user-1', ['conversation-1']);

  assert.equal(calls.userRoom, 'user:user-1');
  assert.deepEqual(calls.events, [
    {
      event: 'conversation:permission-revoked',
      payload: { conversationId: 'conversation-1' },
    },
  ]);
  assert.deepEqual(calls.leftRooms, ['conversation:conversation-1']);
});

test('revoking one application session disconnects only its realtime room', () => {
  const disconnectedRooms: string[] = [];
  const publisher = new ConversationRealtimePublisher();
  publisher.attach({
    to: (room: string) => ({
      disconnectSockets: () => {
        disconnectedRooms.push(room);
      },
    }),
  } as never);

  publisher.disconnectSession('application-session-1');

  assert.deepEqual(disconnectedRooms, ['session:application-session-1']);
});

test('a phone-unverified account cannot open a chat socket', async () => {
  const gateway = createGateway({
    payload: applicationPayload(),
    user: eligibleUser({ phoneVerifiedAt: null }),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 1);
  assert.deepEqual(socket.joined, []);
  assert.deepEqual(socket.emitted, []);
});

test('a disabled account cannot open a chat socket', async () => {
  const gateway = createGateway({
    payload: applicationPayload(),
    user: eligibleUser({ status: 'DISABLED' }),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 1);
  assert.deepEqual(socket.joined, []);
});

test('an eligible account joins its user room and stays connected', async () => {
  const gateway = createGateway({
    payload: applicationPayload(),
    user: eligibleUser(),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 0);
  assert.ok(socket.joined.includes('user:u1'));
  assert.ok(socket.joined.includes('session:app-session'));
  assert.equal(socket.emitted[0]?.event, 'chat:ready');
});

test('the chat socket is torn down when its access token expires', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const gateway = createGateway({
    payload: {
      ...applicationPayload(),
      exp: Math.floor(Date.now() / 1000) + 1,
    },
    user: eligibleUser(),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);
  assert.equal(socket.disconnected, 0, 'stays connected before expiry');

  t.mock.timers.tick(1000);
  assert.equal(socket.disconnected, 1, 'disconnects the moment the token lapses');
});

test('a token without an expiry cannot open a chat socket', async () => {
  const gateway = createGateway({
    payload: applicationPayload({ exp: undefined }),
    user: eligibleUser(),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 1);
  assert.deepEqual(socket.joined, []);
  assert.deepEqual(socket.emitted, []);
});

test('a revoked application session cannot open a chat socket', async () => {
  const gateway = createGateway({
    payload: applicationPayload(),
    user: eligibleUser(),
    session: null,
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 1);
  assert.deepEqual(socket.joined, []);
  assert.deepEqual(socket.emitted, []);
});

test('every chat event revalidates the live application session', async () => {
  const cases = [
    {
      name: 'join',
      invoke: (gateway: ConversationsGateway, socket: FakeSocket) =>
        gateway.join(socket as any, { conversationId: 'conversation-1' }),
    },
    {
      name: 'message',
      invoke: (gateway: ConversationsGateway, socket: FakeSocket) =>
        gateway.message(socket as any, {
          conversationId: 'conversation-1',
          body: 'message',
        }),
    },
    {
      name: 'read',
      invoke: (gateway: ConversationsGateway, socket: FakeSocket) =>
        gateway.read(socket as any, { conversationId: 'conversation-1' }),
    },
  ];

  for (const eventCase of cases) {
    let sessionActive = true;
    let protectedCalls = 0;
    const gateway = createGateway({
      payload: applicationPayload(),
      user: eligibleUser(),
      session: () => (sessionActive ? { id: 'app-session' } : null),
      conversations: {
        authorize: async () => {
          protectedCalls += 1;
          return {};
        },
        send: async () => {
          protectedCalls += 1;
          return {};
        },
        markRead: async () => {
          protectedCalls += 1;
          return {};
        },
      },
    });
    const socket = createSocket();
    await gateway.handleConnection(socket as any);
    assert.equal(socket.disconnected, 0, `${eventCase.name}: connected`);

    sessionActive = false;
    await assert.rejects(() => eventCase.invoke(gateway, socket));

    assert.equal(
      socket.disconnected,
      1,
      `${eventCase.name}: revoked socket is disconnected`,
    );
    assert.equal(
      protectedCalls,
      0,
      `${eventCase.name}: revoked session cannot reach conversation logic`,
    );
  }
});

test('an admin-scoped token cannot open the application chat socket', async () => {
  const gateway = createGateway({
    payload: {
      sub: 'u1',
      scope: 'admin',
      amr: 'admin_mfa',
      sid: 'admin-session',
      exp: futureExp(),
    },
    user: eligibleUser({ role: 'ADMIN', adminRole: 'SUPER_ADMIN' }),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 1);
  assert.deepEqual(socket.joined, []);
  assert.deepEqual(socket.emitted, []);
});

test('a realm-less legacy token cannot open the application chat socket', async () => {
  const gateway = createGateway({
    payload: { sub: 'u1', exp: futureExp() },
    user: eligibleUser(),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 1);
  assert.deepEqual(socket.joined, []);
  assert.deepEqual(socket.emitted, []);
});

test('conversation join rechecks access after joining and leaves when revocation wins the gap', async () => {
  let authorizationCalls = 0;
  const gateway = new ConversationsGateway(
    {} as any,
    {
      refreshToken: {
        findFirst: async () => ({ id: 'app-session' }),
      },
    } as any,
    {
      authorize: async () => {
        authorizationCalls += 1;
        if (authorizationCalls === 2) {
          throw new NotFoundException('Conversation not found');
        }
        return { conversationId: 'conversation-1' };
      },
    } as any,
    { attach: () => undefined } as any,
  );
  const socket = createSocket();
  socket.data.user = eligibleUser();
  socket.data.sessionId = 'app-session';

  await assert.rejects(
    gateway.join(socket as any, { conversationId: 'conversation-1' }),
    NotFoundException,
  );

  assert.equal(authorizationCalls, 2);
  assert.deepEqual(socket.joined, ['conversation:conversation-1']);
  assert.deepEqual(socket.left, ['conversation:conversation-1']);
});
