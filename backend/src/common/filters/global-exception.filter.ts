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

interface ResponseLike {
  status(code: number): ResponseLike;
  json(body: unknown): void;
}

interface RequestLike {
  method?: string;
  originalUrl?: string;
  url?: string;
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
    const route = `${request.method ?? ''} ${request.originalUrl ?? request.url ?? ''}`;

    const mapped = this.mapException(exception);

    if (mapped.status >= 500) {
      this.logger.error(
        `${route} -> ${mapped.status}: ${this.describe(exception)}`,
        exception instanceof Error ? exception.stack : undefined,
      );
      // No-op unless Sentry.init ran at bootstrap (SENTRY_DSN set).
      Sentry.captureException(exception, { tags: { route } });
    } else {
      this.logger.warn(`${route} -> ${mapped.status}: ${mapped.message}`);
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
        case 'P2002':
          return this.simple(
            HttpStatus.CONFLICT,
            new ConflictException('Duplicate value for a unique field').message,
          );
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

    return this.simple(
      HttpStatus.INTERNAL_SERVER_ERROR,
      'Internal server error',
    );
  }

  private simple(status: number, message: string) {
    return { status, message, body: { statusCode: status, message } };
  }

  private describe(exception: unknown): string {
    if (exception instanceof Error) return exception.message;
    return String(exception);
  }
}
