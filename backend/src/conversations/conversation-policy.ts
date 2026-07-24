import { BadRequestException } from '@nestjs/common';

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

interface ConversationParticipantState {
  userId: string;
  revokedAt: Date | null;
}

export function isActiveConversationParticipant(
  participants: readonly ConversationParticipantState[],
  userId: string,
): boolean {
  return participants.some(
    (participant) =>
      participant.userId === userId && participant.revokedAt === null,
  );
}

export function hasJoinedProvider(
  providerUserId: string | null,
  participants: readonly ConversationParticipantState[],
): boolean {
  return Boolean(
    providerUserId &&
      isActiveConversationParticipant(participants, providerUserId),
  );
}
