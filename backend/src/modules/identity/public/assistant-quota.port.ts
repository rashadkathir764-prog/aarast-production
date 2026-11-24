export const ASSISTANT_QUOTA_PORT = Symbol('ASSISTANT_QUOTA_PORT');

/** What one answered question cost (V1 checklist 4.12). */
export interface AssistantQuestionCost {
  inputTokens: number;
  outputTokens: number;
  /** Millionths of a US dollar. */
  costMicroUsd: bigint;
}

/** RA-BE-165: what a question reserves, and the limits it is checked against. */
export interface AssistantReservationRequest {
  /** Questions per account per day. */
  dailyLimit: number;
  /** The first day of the month the caps count from (`YYYY-MM-01`). */
  monthStart: string;
  /** The most the call can cost, in millionths of a dollar. */
  reserveMicroUsd: bigint;
  /** The whole service's monthly cap. */
  serviceMonthlyBudgetMicroUsd: bigint;
  /** The account's own monthly cap. */
  userMonthlyBudgetMicroUsd: bigint;
}

export type AssistantReservation =
  | {
      outcome: 'RESERVED';
      /** The service's spending this month before this reservation. */
      serviceSpentBefore: bigint;
    }
  | { outcome: 'SERVICE_BUDGET_REACHED' | 'USER_BUDGET_REACHED' | 'DAILY_LIMIT_REACHED' };

// Identity owns `AssistantUsageDay`, an account quota like the OTP dispatch
// quota: the planning assistant reserves each question here before it asks
// the model, and settles its cost after. Days are local calendar dates
// (`YYYY-MM-DD`), so a day ends at the user's midnight. A day's
// `costMicroUsd` holds what its answered questions cost plus what its
// questions in flight reserved.
export interface AssistantQuotaPort {
  /**
   * RA-BE-165: one step, serialised against every other reservation: while
   * the service's month and the account's month are below their caps and the
   * day below its limit, counts one question and reserves its most cost.
   * Otherwise reserves nothing and says which limit was reached.
   */
  reserveQuestion(
    userId: string,
    day: string,
    request: AssistantReservationRequest,
  ): Promise<AssistantReservation>;
  /**
   * Gives back a reserved question that brought no answer, and refunds
   * `refundMicroUsd` of its reservation: all of it when the call was never
   * billed, none when it may have been (a timeout).
   */
  releaseQuestion(userId: string, day: string, refundMicroUsd: bigint): Promise<void>;
  /** Replaces an answered question's reservation with what it cost. */
  settleQuestion(
    userId: string,
    day: string,
    reservedMicroUsd: bigint,
    cost: AssistantQuestionCost,
  ): Promise<void>;
  /** How many questions the account asked on `day`. */
  questionsOn(userId: string, day: string): Promise<number>;
}
