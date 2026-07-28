import { ForbiddenException } from '@nestjs/common';
import { Provider, ProviderStatus } from '@prisma/client';

export const PROVIDER_NOT_ACTIVE = 'PROVIDER_NOT_ACTIVE';
export const PROVIDER_PROFILE_READ_ONLY = 'PROVIDER_PROFILE_READ_ONLY';
export const PROVIDER_PORTAL_ROUTE = '/provider/dashboard';

export interface ProviderAccessCapabilities {
  canViewProviderProfile: boolean;
  canManageProviderProfile: boolean;
  canUseProviderOperations: boolean;
}

export type ProviderAccessMode = 'FULL' | 'LIMITED' | 'READ_ONLY';

export interface ProviderAccessPolicy {
  accessMode: ProviderAccessMode;
  capabilities: ProviderAccessCapabilities;
}

export function isProviderOperational(
  provider: Pick<Provider, 'status'> | null | undefined,
): boolean {
  return provider?.status === ProviderStatus.ACTIVE;
}

export function providerAccessPolicy(
  provider: Pick<Provider, 'status'>,
): ProviderAccessPolicy {
  const canUseProviderOperations = isProviderOperational(provider);
  const canManageProviderProfile =
    provider.status !== ProviderStatus.SUSPENDED &&
    provider.status !== ProviderStatus.REJECTED;

  return {
    accessMode: canUseProviderOperations
      ? 'FULL'
      : canManageProviderProfile
        ? 'LIMITED'
        : 'READ_ONLY',
    capabilities: {
      canViewProviderProfile: true,
      canManageProviderProfile,
      canUseProviderOperations,
    },
  };
}

export function assertProviderOperational(
  provider: Pick<Provider, 'status'> | null | undefined,
): void {
  if (!isProviderOperational(provider)) {
    throw new ForbiddenException({
      code: PROVIDER_NOT_ACTIVE,
      message: 'The provider account is not active',
    });
  }
}

export function assertProviderProfileWritable(
  provider: Pick<Provider, 'status'>,
): void {
  if (!providerAccessPolicy(provider).capabilities.canManageProviderProfile) {
    throw new ForbiddenException({
      code: PROVIDER_PROFILE_READ_ONLY,
      message: 'The provider profile is read-only in its current state',
    });
  }
}
