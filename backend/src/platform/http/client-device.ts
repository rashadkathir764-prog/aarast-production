import type { Request } from 'express';

/**
 * RA-BE-140, RA-BE-144, RA-BE-148: the random id a phone sends for itself.
 * The phone's own word: the limits count by it so that people behind one
 * shared address are not closed out together, and it never proves anything.
 * Anything but one plain id counts as none.
 */
export const CLIENT_DEVICE_HEADER = 'x-aarast-device';
const CLIENT_DEVICE_ID = /^[A-Za-z0-9-]{16,64}$/u;

export function clientDeviceId(request: Pick<Request, 'headers'>): string | null {
  const value = request.headers[CLIENT_DEVICE_HEADER];
  return typeof value === 'string' && CLIENT_DEVICE_ID.test(value) ? value : null;
}

/** Who asks, as the limits count it: the address and the phone's own id. */
export function clientRateContext(request: Pick<Request, 'headers' | 'ip'>): {
  ip: string | undefined;
  device: string | null;
} {
  return { ip: request.ip, device: clientDeviceId(request) };
}
