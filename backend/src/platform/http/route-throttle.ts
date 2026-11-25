import type {
  ThrottlerGetTrackerFunction,
  ThrottlerOptions,
} from '@nestjs/throttler';
import type { ExecutionContext } from '@nestjs/common';
import { clientDeviceId } from './client-device';

/**
 * RA-BE-144: a mobile network puts many phones behind one address (CGNAT).
 * A route's limit stays what it was, counted per address: the address's
 * ceiling. Inside it, a phone that sends its id (`X-Aarast-Device`, the key
 * the code limits count by, RA-BE-140) has a share of its own, half of the
 * ceiling, so one phone cannot spend the address's minute for the others
 * behind it. The id is only the phone's word: rotating it never passes the
 * address's ceiling, and a request without one counts against the address
 * alone, as before.
 */
export const DEVICE_SHARE_THROTTLER = 'deviceShare';
const ROUTE_TTL_MS = 60_000;

type ThrottledRequest = Parameters<typeof clientDeviceId>[0] & { ip?: string };

const deviceShareTracker: ThrottlerGetTrackerFunction = (request) =>
  `${request.ip ?? 'unknown'}|${clientDeviceId(request as ThrottledRequest) ?? ''}`;

function routeCarriesShare(context: ExecutionContext): boolean {
  const key = `THROTTLER:LIMIT${DEVICE_SHARE_THROTTLER}`;
  return (
    Reflect.getMetadata(key, context.getHandler()) !== undefined ||
    Reflect.getMetadata(key, context.getClass()) !== undefined
  );
}

/**
 * Registered once in the app's throttler list. It acts only on a route whose
 * limit is `routeLimit(...)` and only for a request that names its phone.
 */
export const deviceShareThrottler: ThrottlerOptions = {
  name: DEVICE_SHARE_THROTTLER,
  ttl: ROUTE_TTL_MS,
  limit: 1,
  getTracker: deviceShareTracker,
  skipIf: (context) =>
    !routeCarriesShare(context) ||
    clientDeviceId(context.switchToHttp().getRequest<ThrottledRequest>()) === null,
};

/** A route's limit a minute: the address's ceiling, and the phone's share in it. */
export function routeLimit(limit: number) {
  return {
    default: { limit, ttl: ROUTE_TTL_MS },
    [DEVICE_SHARE_THROTTLER]: {
      limit: Math.max(1, Math.ceil(limit / 2)),
      ttl: ROUTE_TTL_MS,
    },
  };
}
