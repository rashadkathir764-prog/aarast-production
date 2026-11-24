import { AsyncLocalStorage } from 'node:async_hooks';

/**
 * RA-AD-23: a small map of what an admin action changed on its target (a
 * status, whether a provider is verified, whether a report is closed), as
 * the audit log keeps it before and after. Values are codes, never text a
 * person typed, and never money or contact details.
 */
export type AdminAuditState = Record<string, string | number | boolean | null>;

export interface AdminAuditChange {
  before: AdminAuditState | null;
  after: AdminAuditState | null;
}

const auditedRequest = new AsyncLocalStorage<AdminAuditChange>();

/**
 * Runs an audited admin request: what its mutation records with
 * `recordAdminAuditChange` lands in `change`, which the audit interceptor
 * writes on the action's SUCCEEDED row.
 */
export function runAuditedAdminRequest<T>(change: AdminAuditChange, run: () => T): T {
  return auditedRequest.run(change, run);
}

/**
 * Records what the current admin action changed. A mutation that runs
 * outside an audited request (a test, a script) has no audit row to carry
 * it, so there is nothing to record into. A retried transaction records
 * again: the last attempt, the one that committed, is what stays.
 */
export function recordAdminAuditChange(before: AdminAuditState, after: AdminAuditState): void {
  const change = auditedRequest.getStore();
  if (!change) return;
  change.before = before;
  change.after = after;
}
