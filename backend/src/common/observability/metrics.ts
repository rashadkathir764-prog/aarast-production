import { Counter, Histogram, Registry, collectDefaultMetrics } from 'prom-client';

/**
 * Single process-wide registry. Default metrics cover event-loop lag,
 * heap, and GC — the signals that show saturation before requests fail.
 */
export const metricsRegistry = new Registry();

collectDefaultMetrics({ register: metricsRegistry });

/**
 * Uses the matched Express route pattern (e.g. /expenses/:id) as the label,
 * never the raw URL — raw URLs contain IDs and would explode cardinality.
 */
export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds, labeled by route pattern.',
  labelNames: ['method', 'route', 'status'] as const,
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [metricsRegistry],
});

/**
 * Business counters: the three signals that tell whether the product is
 * alive (people joining, people paying) independent of HTTP noise.
 */
export const otpRequestsTotal = new Counter({
  name: 'aarast_otp_requests_total',
  help: 'OTP codes issued, labeled by delivery channel.',
  labelNames: ['delivery'] as const,
  registers: [metricsRegistry],
});

export const otpVerificationsTotal = new Counter({
  name: 'aarast_otp_verifications_total',
  help: 'OTP verification attempts by outcome (success|failure).',
  labelNames: ['outcome'] as const,
  registers: [metricsRegistry],
});

export const paymentsRecordedTotal = new Counter({
  name: 'aarast_payments_recorded_total',
  help: 'Financial payment records created across all entry points.',
  registers: [metricsRegistry],
});
