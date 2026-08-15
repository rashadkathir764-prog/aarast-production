import type {
  AdminRole,
  AppRole,
  OnboardingPath,
  UserRole,
  UserStatus,
  WeddingPersona,
} from '@prisma/client';

export type JwtSessionScope = 'application' | 'admin';

export interface AuthenticatedUser {
  id: string;
  name: string;
  /** Application-only identity fields used when an administrator enrolls. */
  appName?: string | null;
  phone: string | null;
  email: string | null;
  appEmail?: string | null;
  role: UserRole;
  adminRole: AdminRole | null;
  appRole: AppRole;
  status: UserStatus;
  phoneVerifiedAt: Date | null;
  lastLoginAt: Date | null;
  avatarUrl: string | null;
  appAvatarUrl?: string | null;
  locale: string;
  activeWeddingPlanId: string | null;
  onboardingPath: OnboardingPath | null;
  persona: WeddingPersona | null;
  onboardingCompletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  /** True only for a JWT minted after the admin password + OTP boundary. */
  adminMfa?: boolean;
  /** Present on HTTP and realtime identities authenticated from an access JWT. */
  sessionScope?: JwtSessionScope;
}
