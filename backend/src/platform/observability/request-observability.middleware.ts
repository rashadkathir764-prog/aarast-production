import { randomUUID } from 'node:crypto';
import { Logger } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { httpRequestDuration } from './metrics';
import {
  requestRouteTemplate,
  safeClientRequestId,
} from './sanitize-request-target';

const logger = new Logger('HTTP');

/**
 * Correlates every request with an id (honoring the client-supplied
 * X-Client-Request-Id already allowed by CORS), records the duration
 * histogram, and emits one access-log line on finish. The id is echoed
 * back as X-Request-Id so mobile bug reports can be matched to logs.
 */
export function requestObservability(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const started = process.hrtime.bigint();
  const clientRequestId = safeClientRequestId(
    req.header('x-client-request-id'),
  );
  const requestId = clientRequestId ?? randomUUID();
  (req as Request & { requestId?: string }).requestId = requestId;
  res.setHeader('X-Request-Id', requestId);

  res.on('finish', () => {
    const durationSeconds =
      Number(process.hrtime.bigint() - started) / 1_000_000_000;
    const route = requestRouteTemplate(req);

    httpRequestDuration.observe(
      { method: req.method, route, status: String(res.statusCode) },
      durationSeconds,
    );

    // /health and /metrics are polled every few seconds by Docker and
    // Prometheus; logging them would drown real traffic.
    if (
      req.originalUrl === '/health' ||
      req.originalUrl === '/live' ||
      req.originalUrl === '/ready' ||
      req.originalUrl === '/metrics'
    ) {
      return;
    }

    logger.log(
      `${req.method} ${route} ${res.statusCode} ${(durationSeconds * 1000).toFixed(1)}ms reqId=${requestId}`,
    );
  });

  next();
}
