import { MinLength } from 'class-validator';

/**
 * RA-BE-149 (NIST SP 800-63B): a password chosen from now on, application
 * or administrator, is 8 characters or more, any characters (and at most the
 * 72 bytes bcrypt reads, `MaxUtf8Bytes`). A password set before keeps
 * signing in until its owner changes it: the sign-in forms check no length.
 */
export const NEW_PASSWORD_MIN_LENGTH = 8;

export function NewPasswordLength(): PropertyDecorator {
  return MinLength(NEW_PASSWORD_MIN_LENGTH, {
    message: `كلمة المرور لازم تكون ${NEW_PASSWORD_MIN_LENGTH} أحرف أو أكثر`,
  });
}
