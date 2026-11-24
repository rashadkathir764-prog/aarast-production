export const ASSISTANT_REPORT_PORT = Symbol('ASSISTANT_REPORT_PORT');

/** RA-ST-04 (D95): an assistant answer its reader reports to the team. */
export interface AssistantAnswerReportInput {
  /**
   * RA-BE-166: the server's id of the reported answer, checked against its
   * text before it gets here. One answer is reported once.
   */
  answerId: string;
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

/** RA-BE-166: a reviewed report is deleted this many days after its review. */
export const ASSISTANT_RESOLVED_REPORT_KEEP_DAYS = 90;

// Identity keeps the assistant's account records (insights owns no tables):
// its usage (AssistantUsageDay) and the answers its readers report. A report
// is its reader's and leaves with their account, or 90 days after the team
// reviewed it.
export interface AssistantReportPort {
  /**
   * Keeps the report for the moderation team. False, keeping nothing, when
   * the account already holds ASSISTANT_OPEN_REPORTS_PER_ACCOUNT open ones.
   * An answer already reported is kept once and reads as reported.
   */
  recordAnswerReport(userId: string, report: AssistantAnswerReportInput): Promise<boolean>;
}
