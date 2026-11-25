import { createHmac, hkdfSync, timingSafeEqual } from 'node:crypto';
import {
  JwtSecretRequestType,
  type JwtModuleOptions,
} from '@nestjs/jwt';
import { getJwtSecret } from './jwt-secret';
import { PHONE_PROOF_AUDIENCE } from './phone-proof';

/**
 * RA-BE-149: the server's tokens are signed with a key derived from
 * JWT_SECRET for their purpose (HKDF-SHA-256), never with the secret itself,
 * so the secret is one input from which each use takes its own key (the
 * guests' links, the admins' remembered devices and the assistant's answers
 * derive theirs the same way) and a token of one purpose cannot pass as
 * another.
 */
export type JwtPurpose = 'access' | 'phone-proof';

export function jwtSigningKey(
  purpose: JwtPurpose,
  environment: NodeJS.ProcessEnv = process.env,
): Buffer {
  return Buffer.from(
    hkdfSync('sha256', getJwtSecret(environment), '', `aarast-jwt-${purpose}-v1`, 32),
  );
}

/**
 * When this process started. Until RA-BE-149 the secret itself signed every
 * token, so a session open across the deploy still holds one. Such a token
 * is taken while it lives, and only if it was issued before this process
 * started (in a whole second before it): nothing here signs with the secret
 * any more, so after one access-token lifetime (JWT_ACCESS_EXPIRES_IN, 15
 * minutes; a phone proof lives 10) no token of the old key is left to take,
 * and the sessions themselves never depended on it (their refresh tokens are
 * random values the database holds). Remove this branch, and the
 * `legacyIssuedBeforeMs` parameters, once a release with it has been
 * deployed.
 */
const PROCESS_STARTED_AT_MS = Date.now();

function base64urlJson(segment: string): Record<string, unknown> | null {
  const parsed: unknown = JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
  return parsed !== null && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : null;
}

/** The token's claims if [key] made its HS256 signature, else null. */
function claimsSignedBy(token: string, key: string | Buffer): Record<string, unknown> | null {
  const parts = token.split('.');
  if (parts.length !== 3 || !/^[A-Za-z0-9_-]+$/.test(parts[2])) return null;
  const expected = createHmac('sha256', key).update(`${parts[0]}.${parts[1]}`).digest();
  const actual = Buffer.from(parts[2], 'base64url');
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) return null;
  try {
    return base64urlJson(parts[1]);
  } catch (error) {
    if (error instanceof SyntaxError) return null;
    throw error;
  }
}

/**
 * The key a token of [purpose] is verified with: the purpose's key, or the
 * secret itself for a token it signed before this process started. Any other
 * token gets the purpose's key, and its verification fails as it should.
 */
export function jwtVerificationKey(
  token: string,
  purpose: JwtPurpose,
  environment: NodeJS.ProcessEnv = process.env,
  legacyIssuedBeforeMs: number = PROCESS_STARTED_AT_MS,
): string | Buffer {
  const key = jwtSigningKey(purpose, environment);
  if (claimsSignedBy(token, key)) return key;
  const secret = getJwtSecret(environment);
  const legacyClaims = claimsSignedBy(token, secret);
  const issuedAt = legacyClaims?.iat;
  if (
    typeof issuedAt === 'number' &&
    Number.isInteger(issuedAt) &&
    issuedAt < Math.floor(legacyIssuedBeforeMs / 1000)
  ) {
    return secret;
  }
  return key;
}

function purposeOf(options: { audience?: unknown } | undefined): JwtPurpose {
  return options?.audience === PHONE_PROOF_AUDIENCE ? 'phone-proof' : 'access';
}

/** The identity JwtModule: each sign and verify takes its purpose's key. */
export function identityJwtModuleOptions(
  environment: NodeJS.ProcessEnv = process.env,
  legacyIssuedBeforeMs: number = PROCESS_STARTED_AT_MS,
): JwtModuleOptions {
  // Fail at boot, not at the first sign-in, on a missing or weak secret.
  getJwtSecret(environment);
  return {
    secretOrKeyProvider: (requestType, tokenOrPayload, options) =>
      requestType === JwtSecretRequestType.SIGN
        ? jwtSigningKey(purposeOf(options as { audience?: unknown }), environment)
        : jwtVerificationKey(
            String(tokenOrPayload),
            purposeOf(options as { audience?: unknown }),
            environment,
            legacyIssuedBeforeMs,
          ),
    signOptions: {
      expiresIn: (environment.JWT_ACCESS_EXPIRES_IN || '15m') as '15m',
    },
  };
}
