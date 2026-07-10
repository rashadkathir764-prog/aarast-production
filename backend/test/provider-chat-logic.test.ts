import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import {
  assertConversationParticipant,
  conversationParticipantState,
  normalizeMessageBody,
  normalizeMessagePageSize,
} from '../src/conversations/conversation-policy';

test('quote conversation is limited to the requester and provider owner', () => {
  assert.doesNotThrow(() =>
    assertConversationParticipant('user-1', 'user-1', 'provider-user-1'),
  );
  assert.doesNotThrow(() =>
    assertConversationParticipant(
      'provider-user-1',
      'user-1',
      'provider-user-1',
    ),
  );
  assert.throws(
    () =>
      assertConversationParticipant('stranger', 'user-1', 'provider-user-1'),
    ForbiddenException,
  );
});

test('message body is trimmed and must contain 1 to 2000 characters', () => {
  assert.equal(normalizeMessageBody('  مرحبا  '), 'مرحبا');
  assert.throws(() => normalizeMessageBody('   '), BadRequestException);
  assert.throws(
    () => normalizeMessageBody('x'.repeat(2001)),
    BadRequestException,
  );
});

test('message page size stays between 1 and 50', () => {
  assert.equal(normalizeMessagePageSize(undefined), 30);
  assert.equal(normalizeMessagePageSize('1'), 1);
  assert.equal(normalizeMessagePageSize('50'), 50);
  assert.throws(() => normalizeMessagePageSize('0'), BadRequestException);
  assert.throws(() => normalizeMessagePageSize('51'), BadRequestException);
});

test('conversation state distinguishes who blocked and counterpart read time', () => {
  const counterpartReadAt = new Date('2026-07-07T12:00:00.000Z');
  const state = conversationParticipantState('user-1', [
    {
      userId: 'user-1',
      blockedAt: null,
      lastReadAt: new Date('2026-07-07T11:00:00.000Z'),
    },
    {
      userId: 'provider-user-1',
      blockedAt: new Date('2026-07-07T11:30:00.000Z'),
      lastReadAt: counterpartReadAt,
    },
  ]);

  assert.deepEqual(state, {
    blocked: true,
    blockedByMe: false,
    blockedByCounterpart: true,
    counterpartLastReadAt: counterpartReadAt,
  });
});

test('provider chat schema and authenticated routes stay wired', () => {
  const schema = readFileSync(
    join(process.cwd(), 'prisma/schema.prisma'),
    'utf8',
  );
  const appModule = readFileSync(
    join(process.cwd(), 'src/app.module.ts'),
    'utf8',
  );
  const authModule = readFileSync(
    join(process.cwd(), 'src/auth/auth.module.ts'),
    'utf8',
  );
  const controller = readFileSync(
    join(process.cwd(), 'src/conversations/conversations.controller.ts'),
    'utf8',
  );

  for (const model of [
    'model Conversation ',
    'model ConversationParticipant ',
    'model ChatMessage ',
    'model ChatAttachment ',
    'model ConversationReport ',
  ]) {
    assert.match(schema, new RegExp(model));
  }
  assert.match(appModule, /ConversationsModule/);
  assert.match(authModule, /exports:\s*\[[^\]]*JwtModule[^\]]*\]/);
  assert.match(controller, /@Controller\('conversations'\)/);
  assert.match(controller, /@UseGuards\(JwtAuthGuard\)/);
  assert.match(controller, /quote-requests\/:quoteRequestId/);
  assert.match(controller, /:id\/messages/);
  assert.match(controller, /:id\/read/);
  assert.match(controller, /:id\/report/);
  assert.doesNotMatch(controller, /payment|deposit|booking/i);
});

test('chat gateway authenticates sockets and emits scoped conversation events', () => {
  const gateway = readFileSync(
    join(process.cwd(), 'src/conversations/conversations.gateway.ts'),
    'utf8',
  );
  assert.match(gateway, /@WebSocketGateway/);
  assert.match(gateway, /getCorsOrigins/);
  assert.match(gateway, /origin:\s*getCorsOrigins\(\)/);
  assert.doesNotMatch(gateway, /origin:\s*true/);
  assert.match(gateway, /verifyAsync/);
  assert.match(gateway, /conversation:join/);
  assert.match(gateway, /conversation:message/);
  assert.match(gateway, /conversation:read/);
  assert.match(gateway, /chat:ready/);
  assert.match(gateway, /conversationRoom/);
  assert.doesNotMatch(gateway, /socket\.join\(conversationId\)/);
  const service = readFileSync(
    join(process.cwd(), 'src/conversations/conversations.service.ts'),
    'utf8',
  );
  assert.match(service, /realtime\.message/);
  assert.match(service, /realtime\.read/);
  assert.match(
    service,
    /routeTarget:\s*`\/conversations\/\$\{conversationId\}`/,
  );
  assert.match(service, /const nextCursor = hasMore/);
  assert.match(service, /nextCursor,/);
  assert.match(service, /page\[page\.length - 1\]\?\.id/);
});

test('conversation reports have an admin review surface', () => {
  const controller = readFileSync(
    join(process.cwd(), 'src/admin/admin.controller.ts'),
    'utf8',
  );
  const service = readFileSync(
    join(process.cwd(), 'src/admin/admin.service.ts'),
    'utf8',
  );
  assert.match(controller, /conversation-reports/);
  assert.match(controller, /conversation-reports\/:id\/status/);
  assert.match(service, /conversationReport\.findMany/);
  assert.match(service, /conversationReport\.update/);
});
