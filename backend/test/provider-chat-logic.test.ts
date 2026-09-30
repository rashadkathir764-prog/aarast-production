import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { readLivePrismaSchema } from './support/live-prisma-schema';
import {
  hasJoinedProvider,
  isActiveConversationParticipant,
  normalizeMessageBody,
  normalizeMessagePageSize,
} from '../src/conversations/conversation-policy';

test('message body is trimmed and must contain 1 to 2000 characters', () => {
  assert.equal(normalizeMessageBody('  مرحبا  '), 'مرحبا');
  assert.throws(() => normalizeMessageBody('   '), BadRequestException);
  assert.throws(() => normalizeMessageBody('x'.repeat(2001)), BadRequestException);
});

test('message page size stays between 1 and 50', () => {
  assert.equal(normalizeMessagePageSize(undefined), 30);
  assert.equal(normalizeMessagePageSize('1'), 1);
  assert.equal(normalizeMessagePageSize('50'), 50);
  assert.throws(() => normalizeMessagePageSize('0'), BadRequestException);
  assert.throws(() => normalizeMessagePageSize('51'), BadRequestException);
});

test('provider join and active participation never treat a revoked row as live', () => {
  const participants = [
    { userId: 'customer', revokedAt: null },
    { userId: 'provider', revokedAt: new Date() },
  ];
  assert.equal(
    isActiveConversationParticipant(participants, 'customer'),
    true,
  );
  assert.equal(
    isActiveConversationParticipant(participants, 'provider'),
    false,
  );
  assert.equal(hasJoinedProvider('provider', participants), false);
  assert.equal(
    hasJoinedProvider('provider', [
      ...participants,
      { userId: 'provider', revokedAt: null },
    ]),
    true,
  );
  assert.equal(hasJoinedProvider(null, participants), false);
});

test('conversation schema owns plan/account identity instead of one quote request', () => {
  const schema = readLivePrismaSchema();
  assert.match(schema, /enum ConversationScope\s*{\s*PLAN\s*ACCOUNT\s*}/s);
  assert.match(schema, /model Conversation\s*{[\s\S]*?scope\s+ConversationScope/);
  assert.match(schema, /weddingPlanId\s+String\?/);
  assert.match(schema, /accountRequesterUserId\s+String\?/);
  assert.match(schema, /providerId\s+String/);
  assert.match(schema, /quoteRequests\s+QuoteRequest\[\]/);
  assert.match(schema, /model QuoteRequest\s*{[\s\S]*?conversationId\s+String/);
  assert.match(schema, /model ConversationEvent\s*{/);
  assert.doesNotMatch(schema, /ConversationParticipantRole/);
  assert.doesNotMatch(schema, /model Conversation\s*{[\s\S]*?quoteRequestId\s+String\s+@unique/);
});

test('conversation routes retrieve an existing quote conversation and expose one timeline', () => {
  const controller = readFileSync(
    join(process.cwd(), 'src/conversations/conversations.controller.ts'),
    'utf8',
  );
  assert.match(controller, /@Controller\('api\/v1\/conversations'\)/);
  assert.match(controller, /@Controller\('api\/v1\/quote-requests'\)/);
  assert.match(controller, /:quoteRequestId\/conversation/);
  assert.match(controller, /:id\/quote-requests/);
  assert.match(controller, /:id\/timeline/);
  assert.match(controller, /:id\/messages/);
  assert.doesNotMatch(controller, /@Post\('quote-requests\/:quoteRequestId'\)/);
});

test('authorization uses live plan ownership and explicit canManageProviders', () => {
  const service = readFileSync(
    join(process.cwd(), 'src/conversations/conversations.service.ts'),
    'utf8',
  );
  const repository = readFileSync(
    join(process.cwd(), 'src/modules/messaging/infrastructure/conversations.repository.ts'),
    'utf8',
  );
  assert.match(service, /weddingPlan\.ownerUserId === currentUserId/);
  assert.match(service, /if \(!member\?\.canManageProviders\) return null/);
  assert.match(service, /this\.repository\.revokeParticipant\([\s\S]*new Date\(\)/);
  assert.match(repository, /revokeParticipant\([\s\S]*revokedAt: at/);
  assert.match(service, /assertActiveAccessInTransaction/);
  // The provider and membership rows are locked for share by their owners
  // (marketplace's and collaboration's ports) in the same lifecycle order.
  assert.match(service, /providers\.lockProviderRowsForShareInTransaction\(/);
  assert.match(service, /permissions\.lockMembershipsForShareInTransaction\(/);
  assert.match(service, /PROVIDER_NOT_JOINED/);
  assert.match(service, /this\.repository\.setConversationBlocked\(/);
  assert.match(repository, /customerSideBlockedAt/);
  assert.match(repository, /providerSideBlockedAt/);
  assert.doesNotMatch(
    service,
    /data:\s*\{\s*lastReadAt,\s*revokedAt:\s*null\s*\}/,
  );
  assert.doesNotMatch(service, /ConversationParticipantRole/);
});

test('chat gateway authenticates sockets and publishes activity and permission changes', () => {
  const gateway = readFileSync(
    join(process.cwd(), 'src/conversations/conversations.gateway.ts'),
    'utf8',
  );
  const publisher = readFileSync(
    join(process.cwd(), 'src/conversations/conversation-realtime.publisher.ts'),
    'utf8',
  );
  assert.match(gateway, /@WebSocketGateway/);
  assert.match(gateway, /verifyAsync/);
  assert.match(gateway, /conversation:join/);
  assert.match(gateway, /conversation:message/);
  assert.match(gateway, /conversation:read/);
  assert.match(publisher, /conversation:event/);
  assert.match(publisher, /conversation:activity-available/);
  assert.match(publisher, /conversation:permission-revoked/);
  assert.match(publisher, /socketsLeave/);
});

test('conversation reports keep an admin review surface without one-quote identity', () => {
  // Messaging lists its reports; the back office attaches the provider's
  // id and business name and the conversation's latest quote request
  // (admin-owners.ts), never a single-quote identity on the report.
  const service = readFileSync(join(process.cwd(), 'src/admin/admin.service.ts'), 'utf8');
  const owners = readFileSync(join(process.cwd(), 'src/admin/admin-owners.ts'), 'utf8');
  assert.match(service, /owners\.messaging\.listConversationReports\(/);
  assert.match(owners, /provider: \{ id: provider\.id, businessName: provider\.businessName \}/);
  assert.match(owners, /quoteRequests: latestQuoteId \? \[\{ id: latestQuoteId \}\] : \[\]/);
  assert.doesNotMatch(owners, /quoteRequestId/);
});
