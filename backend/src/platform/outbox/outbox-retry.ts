/**
 * RA-BE-190: a handler that failed part-way says what it finished, so the
 * retry of the same event does not repeat it. The worker merges
 * [payloadPatch] into the event's payload before it is tried again.
 */
export class OutboxRetryWithProgress extends Error {
  constructor(
    name: string,
    readonly payloadPatch: Record<string, string[]>,
  ) {
    super(name);
    this.name = name;
  }
}
