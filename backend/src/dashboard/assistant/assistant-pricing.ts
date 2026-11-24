// What the assistant's model costs (V1 checklist 4.12), in US dollars per
// million tokens, so the monthly spending cap can be enforced. Only these
// models may be configured; a refusal fallback answered by another model is
// priced by the model that answered when known, else by the configured one.

export interface ModelPrice {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
}

export const ASSISTANT_MODEL_PRICES: Readonly<Record<string, ModelPrice>> = {
  'claude-opus-5-5': { input: 4, output: 20, cacheRead: 0.2, cacheWrite: 5 },
  'claude-sonnet-5-5': { input: 2, output: 10, cacheRead: 0.2, cacheWrite: 2.5 },
  'claude-haiku-5-5': { input: 0.1, output: 0.5, cacheRead: 0.01, cacheWrite: 0.125 },
};

export const DEFAULT_ASSISTANT_MODEL = 'claude-opus-5-5';

export interface ModelUsage {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
}

/** The cost of one call in millionths of a dollar, rounded up. */
export function costMicroUsd(price: ModelPrice, usage: ModelUsage): bigint {
  // Dollars per million tokens equal micro-dollars per token.
  const micro =
    usage.inputTokens * price.input +
    usage.outputTokens * price.output +
    usage.cacheReadTokens * price.cacheRead +
    usage.cacheWriteTokens * price.cacheWrite;
  return BigInt(Math.ceil(micro));
}

/** The most a call may write (its thinking included): the request's `max_tokens`. */
export const ASSISTANT_MAX_OUTPUT_TOKENS = 8_000;

/** Each rate at the dearest model known, so a fallback never costs more than reserved. */
const DEAREST: ModelPrice = Object.values(ASSISTANT_MODEL_PRICES).reduce(
  (most, price) => ({
    input: Math.max(most.input, price.input),
    output: Math.max(most.output, price.output),
    cacheRead: Math.max(most.cacheRead, price.cacheRead),
    cacheWrite: Math.max(most.cacheWrite, price.cacheWrite),
  }),
  { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
);

/**
 * RA-BE-165: what is reserved against the caps before a call, in millionths
 * of a dollar: the most the call can cost. No token is shorter than one byte,
 * so the request's UTF-8 bytes bound its input tokens, priced at the dearer
 * of a plain and a cache-writing input; the output is every token the call
 * may write. The answer then settles the reservation at its real cost.
 */
export function reservationMicroUsd(system: string, userText: string): bigint {
  const inputBound = Buffer.byteLength(system, 'utf8') + Buffer.byteLength(userText, 'utf8');
  return BigInt(
    Math.ceil(
      inputBound * Math.max(DEAREST.input, DEAREST.cacheWrite) +
        ASSISTANT_MAX_OUTPUT_TOKENS * DEAREST.output,
    ),
  );
}
