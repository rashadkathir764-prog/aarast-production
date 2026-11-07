export const ASSISTANT_REPORT_PORT = Symbol('ASSISTANT_REPORT_PORT');

/** RA-ST-04 (D95): an assistant answer its reader reports to the team. */
export interface AssistantAnswerReportInput {
  /** The assistant kind that produced the answer (`QUESTION`, `PLAN`, ...). */
  kind: string;
  /** The reader's own question, for `QUESTION` and additions. */
  question: string | null;
  answer: string;
  /** Why it is reported: a named reason or the reader's words. */
  reason: string;
}

/** An account holds at most this many reports the team has not reviewed. */
export const ASSISTANT_OPEN_REPORTS_PER_ACCOUNT = 20;

// Identity keeps the assistant's account records (insights owns no tables):
// its usage (AssistantUsageDay) and the answers its readers report. A report
// is its reader's and leaves with their account.
export interface AssistantReportPort {
  /**
   * Keeps the report for the moderation team. False, keeping nothing, when
   * the account already holds ASSISTANT_OPEN_REPORTS_PER_ACCOUNT open ones.
   */
  recordAnswerReport(userId: string, report: AssistantAnswerReportInput): Promise<boolean>;
}
