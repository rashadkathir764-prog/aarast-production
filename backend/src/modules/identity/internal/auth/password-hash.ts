import * as bcryptjs from 'bcryptjs';

/**
 * RA-BE-149 (D124): the bcrypt cost of every password hash the server
 * writes, about 300 ms with bcryptjs; the password sign-in is throttled. A
 * hash stored at a lower cost is written again at this one after a sign-in
 * that proves it.
 */
export const PASSWORD_HASH_COST = 12;

/**
 * A WhatsApp code's hash stays at 10: the code lives five minutes and its
 * attempts are counted, so a stolen hash gives no time to search for it.
 */
export const OTP_CODE_HASH_COST = 10;

export function hashPassword(password: string): Promise<string> {
  return bcryptjs.hash(password, PASSWORD_HASH_COST);
}

export function hashOtpCode(code: string): Promise<string> {
  return bcryptjs.hash(code, OTP_CODE_HASH_COST);
}

/** Whether a stored password hash was written at a lower cost than today's. */
export function passwordHashNeedsUpgrade(hash: string): boolean {
  return bcryptjs.getRounds(hash) < PASSWORD_HASH_COST;
}
