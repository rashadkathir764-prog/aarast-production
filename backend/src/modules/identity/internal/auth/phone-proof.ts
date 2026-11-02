import type { JwtService } from "@nestjs/jwt";

/**
 * A short-lived proof that the holder just verified a WhatsApp code for a
 * phone with no application account (`POST /auth/otp/verify`, LOGIN). It
 * stands in for a REGISTER code at `POST /auth/register/complete`, so a new
 * person who tried to sign in needs one code, not two.
 *
 * It is signed with the access-token secret but is never an access token:
 * it carries `typ` and its own audience, and no `scope`, `sid` or `sub`, so
 * `resolveJwtSessionScope` rejects it; an access token lacks the audience,
 * so it is never a phone proof.
 */
export const PHONE_PROOF_TYPE = "phone-proof";
export const PHONE_PROOF_AUDIENCE = "aarast:phone-proof";
export const PHONE_PROOF_TTL_SECONDS = 10 * 60;

interface PhoneProofPayload {
  typ: typeof PHONE_PROOF_TYPE;
  phone: string;
}

export function signPhoneProof(jwt: JwtService, normalizedPhone: string): string {
  const payload: PhoneProofPayload = { typ: PHONE_PROOF_TYPE, phone: normalizedPhone };
  return jwt.sign(payload, {
    audience: PHONE_PROOF_AUDIENCE,
    expiresIn: PHONE_PROOF_TTL_SECONDS,
    algorithm: "HS256",
  });
}

/** True only for an unexpired, untampered phone proof for exactly this phone. */
export function isPhoneProofFor(
  jwt: JwtService,
  token: string,
  normalizedPhone: string,
): boolean {
  let payload: Partial<PhoneProofPayload> & Record<string, unknown>;
  try {
    payload = jwt.verify(token, {
      audience: PHONE_PROOF_AUDIENCE,
      algorithms: ["HS256"],
    });
  } catch {
    return false;
  }
  return (
    payload.typ === PHONE_PROOF_TYPE &&
    typeof payload.phone === "string" &&
    payload.phone === normalizedPhone &&
    typeof payload.exp === "number"
  );
}
