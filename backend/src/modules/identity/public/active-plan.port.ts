import type {
  AppRole,
  OnboardingPath,
  Prisma,
  WeddingPersona,
} from '@prisma/client';
import type { SafeUser } from './safe-user';

export const ACTIVE_PLAN_PORT = Symbol('ACTIVE_PLAN_PORT');

export interface CompleteOnboardingInput {
  activeWeddingPlanId: string;
  appRole: AppRole;
  onboardingPath: OnboardingPath;
  persona: WeddingPersona | null;
  onboardingCompletedAt: Date;
}

// `User.activeWeddingPlanId` is identity-owned (design C5). Planning sets
// the pointer when a plan is created or activated and, when onboarding
// completes, the onboarding columns of the profile with it; collaboration
// clears it when a member leaves. Both run inside the caller's transaction.
export interface ActivePlanPort {
  setActivePlanPointerInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    weddingPlanId: string | null,
  ): Promise<void>;
  completeOnboardingInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    input: CompleteOnboardingInput,
  ): Promise<SafeUser>;
}
