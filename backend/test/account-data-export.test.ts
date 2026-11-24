import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { DataExportService } from '../src/modules/identity/internal/profile/data-export.service';

// D63 (w40): the account's own data. RA-BE-161 (item 9): the assistant
// consent is a stored record of the account, so its copy holds its date.

function serviceWith(assistantConsentAt: Date | null) {
  const profile = {
    id: 'user-1',
    name: 'محمد',
    phone: '+967700000001',
    email: null,
    persona: 'GROOM',
    locale: 'ar',
    reviewFirstNameOnly: true,
    assistantConsentAt,
    createdAt: new Date('2026-10-01T00:00:00.000Z'),
    deletionRequestedAt: null,
    deletionScheduledFor: null,
  };
  const tx = {
    user: {
      findUnique: async () => profile,
      findMany: async () => [],
    },
  };
  const none = async () => [];
  const service = new DataExportService(
    {} as any,
    { listOwnedPlans: none, getPlans: none } as any,
    { listPlanMembers: none, listMemberships: none } as any,
    {} as any,
    {} as any,
    {} as any,
    { getProviderByUserId: async () => null } as any,
  );
  return (service as any).accountData(tx, 'user-1', new Date('2026-11-24T00:00:00.000Z'));
}

test('the account data holds the assistant consent date, or null', async () => {
  const agreed = await serviceWith(new Date('2026-11-20T10:00:00.000Z'));
  assert.deepEqual(agreed.account.assistantConsentAt, new Date('2026-11-20T10:00:00.000Z'));
  const never = await serviceWith(null);
  assert.ok('assistantConsentAt' in never.account);
  assert.equal(never.account.assistantConsentAt, null);
});
