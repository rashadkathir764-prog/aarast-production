import type { NextFunction, Request, Response } from 'express';

/**
 * RA-BE-01: the app sends the number of the API contract it was built for.
 * After the store, old versions stay on people's phones, and their offline
 * queue drops a write the server refuses with a 4xx: a change that broke an
 * old version would lose its writes in silence. So every deploy adds and
 * never breaks a contract, and when a break cannot be avoided, the app's
 * contract number goes up and MIN_CLIENT_CONTRACT tells older versions to
 * update (426, APP_UPDATE_REQUIRED) instead of answering them.
 */
export const CLIENT_CONTRACT_HEADER = 'x-aarast-contract';
export const APP_UPDATE_REQUIRED = 'APP_UPDATE_REQUIRED';
export const UPGRADE_REQUIRED_STATUS = 426;

/** The oldest app contract this server serves; 0 (the default) serves all. */
export function minClientContract(
  environment: NodeJS.ProcessEnv = process.env,
): number {
  const raw = environment.MIN_CLIENT_CONTRACT?.trim();
  const minimum = raw ? Number(raw) : 0;
  if (!Number.isInteger(minimum) || minimum < 0 || minimum > 1_000_000) {
    throw new Error('MIN_CLIENT_CONTRACT must be an integer from 0 to 1000000');
  }
  return minimum;
}

/**
 * Answers an app older than [minimum] with 426 before any route runs. A
 * request without the header passes: the admin panel, the web pages, the
 * health checks and the pilot builds made before the header existed.
 */
export function clientContractGate(minimum: number) {
  return (request: Request, response: Response, next: NextFunction): void => {
    if (minimum <= 0) return next();
    const raw = request.header(CLIENT_CONTRACT_HEADER);
    if (raw === undefined) return next();
    const contract = Number(raw.trim());
    if (Number.isInteger(contract) && contract >= minimum) return next();
    response.status(UPGRADE_REQUIRED_STATUS).json({
      statusCode: UPGRADE_REQUIRED_STATUS,
      code: APP_UPDATE_REQUIRED,
      message: 'نسخة التطبيق قديمة. حدّثه من المتجر عشان تكمل.',
    });
  };
}
