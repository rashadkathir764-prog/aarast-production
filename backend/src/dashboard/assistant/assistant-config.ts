import {
  ASSISTANT_MODEL_PRICES,
  DEFAULT_ASSISTANT_MODEL,
  type ModelPrice,
} from './assistant-pricing';

// The assistant's switches (V1 checklist 4.12), all from the environment so
// the project owner turns it on with their own key and sets its limits.

export interface AssistantConfig {
  model: string;
  price: ModelPrice;
  /** Questions per account per day. */
  dailyLimit: number;
  /** The whole service's monthly spending cap, in millionths of a dollar. */
  monthlyBudgetMicroUsd: bigint;
}

const DEFAULT_DAILY_LIMIT = 10;
const DEFAULT_MONTHLY_BUDGET_USD = 30;

function positiveNumber(raw: string | undefined, fallback: number): number {
  const value = Number(raw?.trim() || fallback);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

/** The configured model and limits; a model without a known price is not used. */
export function readAssistantConfig(env: NodeJS.ProcessEnv): AssistantConfig | null {
  const model = env.AARAST_ASSISTANT_MODEL?.trim() || DEFAULT_ASSISTANT_MODEL;
  const price = ASSISTANT_MODEL_PRICES[model];
  if (!price) return null;
  return {
    model,
    price,
    dailyLimit: Math.floor(positiveNumber(env.AARAST_ASSISTANT_DAILY_LIMIT, DEFAULT_DAILY_LIMIT)),
    monthlyBudgetMicroUsd: BigInt(
      Math.round(
        positiveNumber(env.AARAST_ASSISTANT_MONTHLY_BUDGET_USD, DEFAULT_MONTHLY_BUDGET_USD) * 1_000_000,
      ),
    ),
  };
}

/** Today's date in Yemen (the same clock as Riyadh), as `YYYY-MM-DD`. */
export function localDate(now: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Riyadh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

/** The first day of `day`'s month, as `YYYY-MM-01`. */
export function monthStart(day: string): string {
  return `${day.slice(0, 7)}-01`;
}
