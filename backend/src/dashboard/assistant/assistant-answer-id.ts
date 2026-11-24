import { createHash, createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { ServiceUnavailableException } from '@nestjs/common';

// RA-BE-166: the assistant keeps no answer, so a report carries the answer
// back from the phone. The answer's id is the server's: a fresh id and a
// signature over who asked, on which plan, what kind, what question, and the
// answer as a report carries it. A report is kept only when its id signs the
// text it brings, so the team reads what the assistant wrote, never text the
// phone made up.

/** What an answer id is signed over. */
export interface AssistantAnswerSubject {
  userId: string;
  weddingPlanId: string;
  kind: string;
  question: string | null;
  /** The answer exactly as a report carries it (see `reportedAnswerText`). */
  answer: string;
}

const ID = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.([A-Za-z0-9_-]{43})$/;

/**
 * The key, derived from the server's signing secret (as the guests' links
 * and the admins' remembered devices are), so no new secret is to be kept.
 * Rotating that secret only makes answers shown before it unreportable.
 */
function answerKey(environment: NodeJS.ProcessEnv): Buffer {
  const secret = environment.JWT_SECRET?.trim();
  if (!secret) {
    if (environment.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('The assistant is temporarily unavailable');
    }
    return createHash('sha256').update('aarast-local-assistant-answer-key-v1').digest();
  }
  return createHmac('sha256', secret).update('aarast-assistant-answer-key-v1', 'utf8').digest();
}

function signature(id: string, subject: AssistantAnswerSubject, environment: NodeJS.ProcessEnv): Buffer {
  // Each part is length-prefixed, so no two subjects sign the same bytes.
  const parts = [
    'assistant-answer-v1',
    id,
    subject.userId,
    subject.weddingPlanId,
    subject.kind,
    subject.question ?? '',
    subject.question === null ? 'no-question' : 'question',
    subject.answer,
  ];
  const hmac = createHmac('sha256', answerKey(environment));
  for (const part of parts) {
    hmac.update(`${Buffer.byteLength(part, 'utf8')}:`, 'utf8');
    hmac.update(part, 'utf8');
  }
  return hmac.digest();
}

/** A new answer's id: `<uuid>.<signature>`. */
export function issueAnswerId(
  subject: AssistantAnswerSubject,
  environment: NodeJS.ProcessEnv = process.env,
): string {
  const id = randomUUID();
  return `${id}.${signature(id, subject, environment).toString('base64url')}`;
}

/**
 * The answer's own id (the uuid) when `answerId` was issued for exactly this
 * subject, else null.
 */
export function verifiedAnswerId(
  answerId: string,
  subject: AssistantAnswerSubject,
  environment: NodeJS.ProcessEnv = process.env,
): string | null {
  const match = ID.exec(answerId);
  if (!match) return null;
  const [, id, signed] = match;
  const given = Buffer.from(signed, 'base64url');
  const expected = signature(id, subject, environment);
  return given.length === expected.length && timingSafeEqual(given, expected) ? id : null;
}
