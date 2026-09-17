import type { AuthenticatedUser } from './identity-session.types';

export const IDENTITY_REALTIME_SESSION_PORT = Symbol(
  'IDENTITY_REALTIME_SESSION_PORT',
);

// Whether an account may hold a realtime channel is identity's decision,
// mirroring the HTTP session strategy: an existing, non-disabled,
// phone-verified account with a live (unrevoked, unexpired) application
// session. Messaging's gateway asks this port on connection and before each
// socket message.
export interface IdentityRealtimeSessionPort {
  /** The authenticated user behind a live application session, or null when the account or the session is not eligible. */
  findRealtimeSessionUser(
    userId: string,
    sessionId: string,
  ): Promise<AuthenticatedUser | null>;
  isApplicationSessionLive(userId: string, sessionId: string): Promise<boolean>;
}
