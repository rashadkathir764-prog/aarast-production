export const ASSISTANT_QUOTA_PORT = Symbol('ASSISTANT_QUOTA_PORT');

/** What one answered question cost (V1 checklist 4.12). */
export interface AssistantQuestionCost {
  inputTokens: number;
  outputTokens: number;
  /** Millionths of a US dollar. */
  costMicroUsd: bigint;
}

// Identity owns `AssistantUsageDay`, an account quota like the OTP dispatch
// quota: the planning assistant counts each question here before it asks
// the model, and records the cost after. Days are local calendar dates
// (`YYYY-MM-DD`), so a day ends at the user's midnight.
export interface AssistantQuotaPort {
  /**
   * Counts one question for the account on `day`. Returns false, counting
   * nothing, when the day already holds `dailyLimit` questions.
   */
  reserveQuestion(userId: string, day: string, dailyLimit: number): Promise<boolean>;
  /** Gives back a reserved question that never reached the model. */
  releaseQuestion(userId: string, day: string): Promise<void>;
  /** Adds what an answered question cost to the account's day. */
  recordQuestionCost(userId: string, day: string, cost: AssistantQuestionCost): Promise<void>;
  /** How many questions the account asked on `day`. */
  questionsOn(userId: string, day: string): Promise<number>;
  /** The cost of every account's questions on or after `since`, in millionths of a dollar. */
  spentSince(since: string): Promise<bigint>;
}
