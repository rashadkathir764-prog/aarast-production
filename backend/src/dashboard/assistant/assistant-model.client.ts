import Anthropic from '@anthropic-ai/sdk';
import { ASSISTANT_MAX_OUTPUT_TOKENS, type ModelUsage } from './assistant-pricing';

export interface AssistantModelRequest {
  model: string;
  system: string;
  userText: string;
}

export interface AssistantModelReply {
  /** The answer, or '' when the model declined. */
  text: string;
  /** The model's stop reason (`end_turn`, `max_tokens`, `refusal`, ...). */
  stopReason: string | null;
  /** The model that answered (a refusal fallback may differ from the request's). */
  model: string;
  usage: ModelUsage;
}

/**
 * Why a call never produced a reply. BUSY and UNAVAILABLE: the API refused
 * it, or the connection never opened, so nothing was billed. UNANSWERED: the
 * request may have reached the API (a timeout, a connection dropped after
 * it was sent), so it may have been billed and RA-BE-165 keeps its reserved
 * cost.
 */
export type AssistantModelFailure = 'BUSY' | 'UNANSWERED' | 'UNAVAILABLE';

/**
 * Connection failures that prove the request never left: no address, no
 * route, or a refused or unopened connection. Any other connection failure
 * may come after the request was sent.
 */
const NEVER_SENT = new Set([
  'ECONNREFUSED',
  'ENOTFOUND',
  'EAI_AGAIN',
  'ENETUNREACH',
  'EHOSTUNREACH',
  'UND_ERR_CONNECT_TIMEOUT',
]);

function connectionCode(error: unknown): string | null {
  // The SDK wraps fetch's TypeError, whose cause is the socket's error.
  let cause: unknown = (error as { cause?: unknown }).cause;
  for (let depth = 0; depth < 3 && cause; depth++) {
    const code = (cause as { code?: unknown }).code;
    if (typeof code === 'string') return code;
    cause = (cause as { cause?: unknown }).cause;
  }
  return null;
}

/** For tests only: where the API is and how long a call may wait. */
export interface ClaudeAssistantModelOptions {
  baseURL?: string;
  timeoutMs?: number;
}

export class AssistantModelError extends Error {
  constructor(readonly failure: AssistantModelFailure, readonly detail: string) {
    super(`assistant model ${failure}: ${detail}`);
  }
}

export interface AssistantModel {
  ask(request: AssistantModelRequest): Promise<AssistantModelReply>;
}

/**
 * The Claude API behind the assistant. The key is the project owner's,
 * read from ANTHROPIC_API_KEY; without it the assistant is off.
 */
export class ClaudeAssistantModel implements AssistantModel {
  private readonly client: Anthropic;

  constructor(apiKey: string, options: ClaudeAssistantModelOptions = {}) {
    // RA-BE-165: no retry inside the SDK. Each attempt may be billed, and a
    // question reserves the cost of one call; a hidden second attempt was
    // billed with nothing reserved for it. 45 s ends well before the app
    // stops waiting (100 s).
    this.client = new Anthropic({
      apiKey,
      timeout: options.timeoutMs ?? 45_000,
      maxRetries: 0,
      ...(options.baseURL ? { baseURL: options.baseURL } : {}),
    });
  }

  async ask(request: AssistantModelRequest): Promise<AssistantModelReply> {
    try {
      const response = await this.client.beta.messages.create({
        model: request.model,
        max_tokens: ASSISTANT_MAX_OUTPUT_TOKENS,
        // Advice for one person's plan, read on a phone: low effort keeps it
        // quick and cheap while thinking stays on.
        output_config: { effort: 'low' },
        // A safety decline is re-run on a suitable model instead of failing.
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        // The rules are the same for every question, so they are cached.
        system: [
          { type: 'text', text: request.system, cache_control: { type: 'ephemeral' } },
        ],
        messages: [{ role: 'user', content: request.userText }],
      });
      const text = response.content
        .flatMap((block) => (block.type === 'text' ? [block.text] : []))
        .join('\n')
        .trim();
      return {
        text,
        stopReason: response.stop_reason,
        model: response.model,
        usage: {
          inputTokens: response.usage.input_tokens,
          outputTokens: response.usage.output_tokens,
          cacheReadTokens: response.usage.cache_read_input_tokens ?? 0,
          cacheWriteTokens: response.usage.cache_creation_input_tokens ?? 0,
        },
      };
    } catch (error) {
      // Before APIConnectionError, which it extends.
      if (error instanceof Anthropic.APIConnectionTimeoutError) {
        throw new AssistantModelError('UNANSWERED', error.constructor.name);
      }
      if (error instanceof Anthropic.APIConnectionError) {
        const code = connectionCode(error);
        throw new AssistantModelError(
          code && NEVER_SENT.has(code) ? 'BUSY' : 'UNANSWERED',
          `${error.constructor.name} ${code ?? 'unknown'}`,
        );
      }
      if (error instanceof Anthropic.RateLimitError || error instanceof Anthropic.InternalServerError) {
        throw new AssistantModelError('BUSY', error.constructor.name);
      }
      if (error instanceof Anthropic.APIError) {
        throw new AssistantModelError('UNAVAILABLE', `${error.constructor.name} ${error.status ?? ''}`.trim());
      }
      throw error;
    }
  }
}
