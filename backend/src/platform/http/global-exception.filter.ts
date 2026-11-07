import {
  ArgumentsHost,
  Catch,
  ConflictException,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import * as Sentry from '@sentry/node';
import { requestRouteTemplate } from '../observability/sanitize-request-target';
import { DUPLICATE_VALUE } from './duplicate-value';

interface ResponseLike {
  status(code: number): ResponseLike;
  json(body: unknown): void;
}

interface RequestLike {
  baseUrl?: string;
  method?: string;
  originalUrl?: string;
  route?: { path?: unknown };
  url?: string;
}

export function safeExceptionType(exception: unknown): string {
  if (exception instanceof Error) {
    return (
      exception.constructor.name
        .replace(/[^A-Za-z0-9_.-]/g, '')
        .slice(0, 80) || 'Error'
    );
  }
  return typeof exception;
}

export function safeTelemetryException(
  status: number,
  exception: unknown,
): Error {
  return new Error(`HTTP ${status} ${safeExceptionType(exception)}`);
}

export function shouldReportHttpException(route: string, status: number): boolean {
  return (
    status >= 500 &&
    !(route === 'GET /ready' && status === HttpStatus.SERVICE_UNAVAILABLE)
  );
}

/**
 * One place where every unhandled error becomes a sane HTTP response and a
 * structured log line. Before this filter, known Prisma errors (duplicate
 * keys, numeric overflow) surfaced as raw 500s and production incidents
 * were invisible — zero Logger usage existed in the codebase.
 */
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('HTTP');

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<ResponseLike>();
    const request = ctx.getRequest<RequestLike>();
    const route = `${request.method ?? ''} ${requestRouteTemplate(request)}`;

    const mapped = this.mapException(exception);

    if (shouldReportHttpException(route, mapped.status)) {
      const exceptionType = safeExceptionType(exception);
      this.logger.error(`${route} -> ${mapped.status} type=${exceptionType}`);
      // No-op unless Sentry.init ran at bootstrap (SENTRY_DSN set).
      Sentry.captureException(
        safeTelemetryException(mapped.status, exception),
        { tags: { route, exceptionType, status: String(mapped.status) } },
      );
    } else if (mapped.status < 500) {
      this.logger.warn(
        `${route} -> ${mapped.status} type=${safeExceptionType(exception)}`,
      );
    }

    response.status(mapped.status).json(mapped.body);
  }

  private mapException(exception: unknown): {
    status: number;
    message: string;
    body: unknown;
  } {
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = exception.getResponse();
      return {
        status,
        message: exception.message,
        body: typeof body === 'string' ? { statusCode: status, message: body } : body,
      };
    }

    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      // Known data-layer failures become meaningful client errors instead
      // of opaque 500s.
      switch (exception.code) {
        case 'P2002': {
          // RA-AD-13: a taken value, said as such (not as stale data).
          const message = new ConflictException('Duplicate value for a unique field').message;
          return {
            status: HttpStatus.CONFLICT,
            message,
            body: { statusCode: HttpStatus.CONFLICT, code: DUPLICATE_VALUE, message },
          };
        }
        case 'P2025':
          return this.simple(HttpStatus.NOT_FOUND, 'Record not found');
        case 'P2003':
          return this.simple(
            HttpStatus.BAD_REQUEST,
            'Related record does not exist',
          );
        case 'P2020':
        case 'P2033':
          return this.simple(
            HttpStatus.BAD_REQUEST,
            'Numeric value out of range',
          );
        default:
          return this.simple(
            HttpStatus.INTERNAL_SERVER_ERROR,
            'Internal server error',
          );
      }
    }

    const bodyFailure = requestBodyFailure(exception);
    if (bodyFailure) return bodyFailure;

    return this.simple(
      HttpStatus.INTERNAL_SERVER_ERROR,
      'Internal server error',
    );
  }

  private simple(status: number, message: string) {
    return { status, message, body: { statusCode: status, message } };
  }

}

/**
 * A body the server could not read: too large, not JSON, or in an encoding it
 * does not take. Express's body parser raises these before any route runs;
 * they are the client's (4xx), and were answered as a 500 with no reason.
 * Each keeps its status and says it in Arabic, with a stable code.
 */
const REQUEST_BODY_FAILURES: Record<number, { code: string; message: string }> = {
  [HttpStatus.PAYLOAD_TOO_LARGE]: {
    code: 'REQUEST_TOO_LARGE',
    message: 'البيانات المرسلة أكبر من المسموح.',
  },
  [HttpStatus.BAD_REQUEST]: {
    code: 'REQUEST_BODY_INVALID',
    message: 'البيانات المرسلة ما انقرت. حدّث التطبيق وجرّب مرة ثانية.',
  },
  [HttpStatus.UNSUPPORTED_MEDIA_TYPE]: {
    code: 'REQUEST_BODY_INVALID',
    message: 'البيانات المرسلة ما انقرت. حدّث التطبيق وجرّب مرة ثانية.',
  },
};

function requestBodyFailure(
  exception: unknown,
): { status: number; message: string; body: unknown } | null {
  if (exception === null || typeof exception !== 'object') return null;
  const { type, status } = exception as { type?: unknown; status?: unknown };
  if (
    typeof type !== 'string' ||
    !/^(?:entity|request|encoding|charset|parameters|stream)\./u.test(type) ||
    typeof status !== 'number'
  ) {
    return null;
  }
  const failure = REQUEST_BODY_FAILURES[status];
  if (!failure) return null;
  return {
    status,
    message: failure.message,
    body: { statusCode: status, code: failure.code, message: failure.message },
  };
}
