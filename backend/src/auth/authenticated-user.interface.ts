import {
  AppRole,
  AdminRole,
  OnboardingPath,
  UserRole,
  UserStatus,
  WeddingPersona,
} from '@prisma/client';

export interface AuthenticatedUser {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  role: UserRole;
  adminRole: AdminRole | null;
  appRole: AppRole;
  status: UserStatus;
  phoneVerifiedAt: Date | null;
  lastLoginAt: Date | null;
  avatarUrl: string | null;
  locale: string;
  activeWeddingPlanId: string | null;
  onboardingPath: OnboardingPath | null;
  persona: WeddingPersona | null;
  onboardingCompletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  /** True only for a JWT minted after the admin password + OTP boundary. */
  adminMfa?: boolean;
}
