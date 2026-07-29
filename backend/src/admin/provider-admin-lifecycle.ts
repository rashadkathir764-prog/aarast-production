import { ConflictException } from '@nestjs/common';
import { ProviderStatus } from '@prisma/client';

export type ProviderAdminAction =
  | 'APPROVE'
  | 'REJECT'
  | 'REQUEST_CHANGES'
  | 'SUSPEND'
  | 'ACTIVATE';

const allowedStatusesByAction: Record<
  ProviderAdminAction,
  ReadonlySet<ProviderStatus>
> = {
  APPROVE: new Set([
    ProviderStatus.PENDING,
    ProviderStatus.NEEDS_CHANGES,
    ProviderStatus.REJECTED,
  ]),
  REJECT: new Set([
    ProviderStatus.PENDING,
    ProviderStatus.NEEDS_CHANGES,
  ]),
  REQUEST_CHANGES: new Set([
    ProviderStatus.PENDING,
    ProviderStatus.REJECTED,
  ]),
  SUSPEND: new Set([ProviderStatus.ACTIVE]),
  ACTIVATE: new Set([ProviderStatus.SUSPENDED]),
};

export const providerApplicationDefaultStatuses = [
  ProviderStatus.PENDING,
  ProviderStatus.NEEDS_CHANGES,
  ProviderStatus.REJECTED,
] as const;

export const providerDirectoryDefaultStatuses = [
  ProviderStatus.ACTIVE,
  ProviderStatus.SUSPENDED,
] as const;

export function assertProviderAdminAction(
  action: ProviderAdminAction,
  currentStatus: ProviderStatus,
): void {
  if (allowedStatusesByAction[action].has(currentStatus)) return;
  throw new ConflictException({
    code: 'INVALID_PROVIDER_STATUS_TRANSITION',
    message: `Provider action ${action} is not allowed from ${currentStatus}`,
    currentStatus,
    action,
  });
}

export function providerAdminActionAllowed(
  action: ProviderAdminAction,
  currentStatus: ProviderStatus,
): boolean {
  return allowedStatusesByAction[action].has(currentStatus);
}
