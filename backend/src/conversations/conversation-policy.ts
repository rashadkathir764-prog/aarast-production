import { BadRequestException, HttpException, HttpStatus } from '@nestjs/common';
import { withinCharacters } from '../shared-kernel/text/text-length';

/** The phone's message field and the request form stop here (RA-BE-77). */
export const MESSAGE_MAX_CHARACTERS = 2000;
/** The report form's reason (`conversation-action.dto.ts`). */
export const REPORT_REASON_MAX_CHARACTERS = 500;

/**
 * RA-BE-81: how many messages one account sends in a minute. Each message is
 * a notice and a push to the other side, so without it one account could
 * flood a phone; the request limit counts by network address, and Yemeni
 * mobile networks put many phones behind one, so the bound is the account's.
 * Far above a person typing; the phone's queue waits out a 429 and sends.
 */
export const MESSAGES_PER_MINUTE = 30;

export function messageRateLimited(): HttpException {
  return new HttpException(
    {
      statusCode: HttpStatus.TOO_MANY_REQUESTS,
      code: 'MESSAGE_RATE_LIMITED',
      message: 'رسائل كثيرة في دقيقة وحدة. الرسالة تنرسل بعد شوي.',
      retryAfterSeconds: 60,
    },
    HttpStatus.TOO_MANY_REQUESTS,
  );
}

/**
 * RA-BE-77 (RA-BE-16): counted as the request form and the phone count it,
 * a character as the reader sees it. It was counted again in code units, so
 * a message of 2000 characters with its marks, taken by both, was refused
 * in English, and one waiting on the phone was dropped.
 */
export function normalizeMessageBody(value: string): string {
  const body = value.trim();
  if (body.length < 1 || !withinCharacters(body, MESSAGE_MAX_CHARACTERS)) {
    throw new BadRequestException({
      code: 'MESSAGE_LENGTH',
      message: `الرسالة من حرف إلى ${MESSAGE_MAX_CHARACTERS} حرف.`,
    });
  }
  return body;
}

/**
 * A report's reason: at least 3, as the form's `@MinLength(3)` reads it, and
 * at most 500 counted as read, as its `@MaxCharacters(500)`.
 */
export function normalizeReportReason(value: string): string {
  const reason = value.trim();
  if (reason.length >= 3 && withinCharacters(reason, REPORT_REASON_MAX_CHARACTERS)) {
    return reason;
  }
  throw new BadRequestException({
    code: 'REPORT_REASON_LENGTH',
    message: `سبب البلاغ من 3 إلى ${REPORT_REASON_MAX_CHARACTERS} حرف.`,
  });
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
