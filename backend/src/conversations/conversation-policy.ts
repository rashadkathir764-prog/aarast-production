import { BadRequestException, ForbiddenException } from '@nestjs/common';

export function assertConversationParticipant(
  currentUserId: string,
  requesterUserId: string,
  providerUserId: string | null,
): void {
  if (currentUserId !== requesterUserId && currentUserId !== providerUserId) {
    throw new ForbiddenException('Conversation access denied');
  }
}

export function normalizeMessageBody(value: string): string {
  const body = value.trim();
  if (body.length < 1 || body.length > 2000) {
    throw new BadRequestException('Message must contain 1 to 2000 characters');
  }
  return body;
}

export function normalizeMessagePageSize(value?: string): number {
  if (value === undefined) return 30;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 50) {
    throw new BadRequestException('limit must be between 1 and 50');
  }
  return parsed;
}

interface ConversationParticipantStateInput {
  userId: string;
  blockedAt: Date | null;
  lastReadAt: Date | null;
}

export function conversationParticipantState(
  currentUserId: string,
  participants: ConversationParticipantStateInput[],
) {
  const membership = participants.find(
    (participant) => participant.userId === currentUserId,
  );
  const counterpart = participants.find(
    (participant) => participant.userId !== currentUserId,
  );
  const blockedByMe = membership?.blockedAt != null;
  const blockedByCounterpart = counterpart?.blockedAt != null;
  return {
    blocked: blockedByMe || blockedByCounterpart,
    blockedByMe,
    blockedByCounterpart,
    counterpartLastReadAt: counterpart?.lastReadAt ?? null,
  };
}
