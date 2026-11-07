import type { IncomingMessage, ServerResponse } from 'node:http';

type Next = (error?: unknown) => void;
type BodyRequest = IncomingMessage & { body?: unknown };

/**
 * RA-BE-64: one route reads a larger JSON body than the 100kb Nest gives every
 * other route: saving a plan kept on the phone into the account sends the
 * whole plan at once (up to 5000 guests, D99).
 *
 * Mounted on that route's path before Nest registers its own parsers. Nest's
 * parser is registered for every route at once, and taking Express's parser
 * here would add a direct dependency to the pinned package graph (an owner's
 * re-pin); so this reads the body itself, bounded, for this one route. Once
 * the body is read, Nest's own parser leaves the request alone.
 *
 * Only a JSON request in UTF-8, without a content encoding, that carries a
 * bearer token is read here (the route itself needs a signed-in account).
 * Any other request falls through to Nest's parser and its default limit, so
 * an anonymous caller cannot make the server read large bodies.
 *
 * A failure is raised in the body parser's own shape (`type`, `status`), so
 * the exception filter answers it as it answers the default parser's.
 */
export function largeJsonBody(limitBytes: number) {
  return function largeJsonBody(
    request: BodyRequest,
    _response: ServerResponse,
    next: Next,
  ): void {
    if (!readsHere(request)) {
      next();
      return;
    }
    const declared = Number(request.headers['content-length']);
    if (Number.isFinite(declared) && declared > limitBytes) {
      request.resume();
      next(bodyFailure(413, 'entity.too.large'));
      return;
    }

    const chunks: Buffer[] = [];
    let size = 0;
    let settled = false;
    const settle = (error?: unknown) => {
      if (settled) return;
      settled = true;
      next(error);
    };

    request.on('data', (chunk: Buffer) => {
      if (settled) return;
      size += chunk.length;
      if (size > limitBytes) {
        request.resume();
        settle(bodyFailure(413, 'entity.too.large'));
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => {
      if (settled) return;
      try {
        request.body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      } catch {
        settle(bodyFailure(400, 'entity.parse.failed'));
        return;
      }
      settle();
    });
    request.on('error', () => settle(bodyFailure(400, 'request.aborted')));
  };
}

function readsHere(request: IncomingMessage): boolean {
  const authorization = request.headers.authorization ?? '';
  if (!/^Bearer\s+\S+/iu.test(authorization)) return false;
  const encoding = (request.headers['content-encoding'] ?? 'identity').toLowerCase();
  if (encoding !== 'identity') return false;
  const contentType = (request.headers['content-type'] ?? '').toLowerCase();
  if (!/^application\/json(?:\s*;|$)/u.test(contentType)) return false;
  const charset = /charset=([^;\s]+)/u.exec(contentType)?.[1];
  return charset === undefined || charset === 'utf-8' || charset === 'utf8';
}

function bodyFailure(status: number, type: string): Error & { status: number; type: string } {
  return Object.assign(new Error(type), { status, type });
}
