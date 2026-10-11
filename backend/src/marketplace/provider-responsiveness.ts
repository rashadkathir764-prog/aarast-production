// How quickly a provider answers quote requests, shown to customers as
// "usually replies within …". Built from the provider's own history only;
// with too few requests it says nothing rather than something misleading.

export const RESPONSIVENESS_WINDOW_DAYS = 180;
/** An unanswered request younger than this is not yet counted as ignored. */
export const RESPONSIVENESS_GRACE_HOURS = 48;
export const RESPONSIVENESS_MIN_REQUESTS = 3;

export interface ProviderResponseSample {
  /** Requests that count: answered ones, and unanswered ones past the grace period. */
  requests: number;
  answered: number;
  /** Median minutes from the request to the provider's first offer; null when none was answered. */
  medianMinutes: number | null;
}

export interface ProviderResponsiveness {
  sampleSize: number;
  answeredPercent: number;
  /** Rounded up to whole hours, at least 1; null when no request was answered. */
  typicalResponseHours: number | null;
}

export function responsivenessWindow(now: Date): { since: Date; settledBefore: Date } {
  return {
    since: new Date(now.getTime() - RESPONSIVENESS_WINDOW_DAYS * 86_400_000),
    settledBefore: new Date(now.getTime() - RESPONSIVENESS_GRACE_HOURS * 3_600_000),
  };
}

export function summarizeResponsiveness(
  sample: ProviderResponseSample,
): ProviderResponsiveness | null {
  if (sample.requests < RESPONSIVENESS_MIN_REQUESTS) return null;
  return {
    sampleSize: sample.requests,
    answeredPercent: Math.round((sample.answered / sample.requests) * 100),
    typicalResponseHours:
      sample.medianMinutes === null
        ? null
        : Math.max(1, Math.ceil(sample.medianMinutes / 60)),
  };
}
