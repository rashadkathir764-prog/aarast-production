import { AsyncLocalStorage } from "node:async_hooks";

/**
 * RA-BE-143: whether a request committed a database transaction. The
 * idempotency interceptor reads it to tell a failure whose work rolled back
 * (safe to retry with the same key) from one after a commit (a retry could
 * write the same thing twice, so its reservation stays for reconciliation).
 */
export interface RequestCommits {
  committed: boolean;
}

const requestCommits = new AsyncLocalStorage<RequestCommits>();

/** Run `work`, and everything it awaits, recording its commits in `record`. */
export function trackRequestCommits<T>(record: RequestCommits, work: () => T): T {
  return requestCommits.run(record, work);
}

/** Called after a transaction committed; outside a tracked request it does nothing. */
export function recordRequestCommit(): void {
  const record = requestCommits.getStore();
  if (record) record.committed = true;
}
