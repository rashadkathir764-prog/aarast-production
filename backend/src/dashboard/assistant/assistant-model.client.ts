import Anthropic from '@anthropic-ai/sdk';
import type { ModelUsage } from './assistant-pricing';

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

/** Why a call never produced a reply. */
export type AssistantModelFailure = 'BUSY' | 'UNAVAILABLE';

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

  constructor(apiKey: string) {
    // One retry within 45 s each ends before the app stops waiting (100 s).
    this.client = new Anthropic({ apiKey, timeout: 45_000, maxRetries: 1 });
  }

  async ask(request: AssistantModelRequest): Promise<AssistantModelReply> {
    try {
      const response = await this.client.beta.messages.create({
        model: request.model,
        max_tokens: 8_000,
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
      if (
        error instanceof Anthropic.RateLimitError ||
        error instanceof Anthropic.InternalServerError ||
        error instanceof Anthropic.APIConnectionError
      ) {
        throw new AssistantModelError('BUSY', error.constructor.name);
      }
      if (error instanceof Anthropic.APIError) {
        throw new AssistantModelError('UNAVAILABLE', `${error.constructor.name} ${error.status ?? ''}`.trim());
      }
      throw error;
    }
  }
}
