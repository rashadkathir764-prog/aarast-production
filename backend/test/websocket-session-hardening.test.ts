import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ConversationsGateway } from '../src/conversations/conversations.gateway';

interface FakeSocket {
  id: string;
  handshake: { auth: { token: string }; headers: Record<string, string> };
  data: Record<string, unknown>;
  joined: string[];
  emitted: Array<{ event: string; payload: unknown }>;
  disconnected: number;
  join: (room: string) => Promise<void>;
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
    emitted: [],
    disconnected: 0,
    join: async (room: string) => {
      socket.joined.push(room);
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

function createGateway(options: { payload: unknown; user: unknown }) {
  const jwt = { verifyAsync: async () => options.payload } as any;
  const prisma = { user: { findUnique: async () => options.user } } as any;
  const conversations = {} as any;
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

test('a phone-unverified account cannot open a chat socket', async () => {
  const gateway = createGateway({
    payload: { sub: 'u1', exp: futureExp() },
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
    payload: { sub: 'u1', exp: futureExp() },
    user: eligibleUser({ status: 'DISABLED' }),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 1);
  assert.deepEqual(socket.joined, []);
});

test('an eligible account joins its user room and stays connected', async () => {
  const gateway = createGateway({
    payload: { sub: 'u1', exp: futureExp() },
    user: eligibleUser(),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 0);
  assert.ok(socket.joined.includes('user:u1'));
  assert.equal(socket.emitted[0]?.event, 'chat:ready');
});

test('the chat socket is torn down when its access token expires', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const gateway = createGateway({
    payload: { sub: 'u1', exp: Math.floor(Date.now() / 1000) + 1 },
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
    payload: { sub: 'u1' },
    user: eligibleUser(),
  });
  const socket = createSocket();

  await gateway.handleConnection(socket as any);

  assert.equal(socket.disconnected, 1);
  assert.deepEqual(socket.joined, []);
  assert.deepEqual(socket.emitted, []);
});
