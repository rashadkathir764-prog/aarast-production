import assert from 'node:assert/strict';
import test from 'node:test';
import { ProviderStatus } from '@prisma/client';
import {
  assertProviderAdminAction,
  providerAdminActionAllowed,
  providerApplicationDefaultStatuses,
  providerDirectoryDefaultStatuses,
} from '../src/admin/provider-admin-lifecycle';
import { switchProviderStatusNotification } from '../src/admin/provider-status-notification';

test('provider administration pages have distinct default lifecycle scopes', () => {
  assert.deepEqual([...providerApplicationDefaultStatuses], [
    ProviderStatus.PENDING,
    ProviderStatus.NEEDS_CHANGES,
    ProviderStatus.REJECTED,
  ]);
  assert.deepEqual([...providerDirectoryDefaultStatuses], [
    ProviderStatus.ACTIVE,
    ProviderStatus.SUSPENDED,
  ]);
});

test('provider administration actions follow the lifecycle matrix', () => {
  assert.equal(
    providerAdminActionAllowed('APPROVE', ProviderStatus.PENDING),
    true,
  );
  assert.equal(
    providerAdminActionAllowed('APPROVE', ProviderStatus.SUSPENDED),
    false,
  );
  assert.equal(
    providerAdminActionAllowed('ACTIVATE', ProviderStatus.SUSPENDED),
    true,
  );
  assert.equal(
    providerAdminActionAllowed('SUSPEND', ProviderStatus.ACTIVE),
    true,
  );
  assert.equal(
    providerAdminActionAllowed('REJECT', ProviderStatus.ACTIVE),
    false,
  );
  assert.throws(
    () => assertProviderAdminAction('REQUEST_CHANGES', ProviderStatus.ACTIVE),
    (error: any) =>
      error?.getResponse?.().code === 'INVALID_PROVIDER_STATUS_TRANSITION',
  );
});

test('provider lifecycle notification preserves the administration note', () => {
  const result = switchProviderStatusNotification(
    'استديو أعرست',
    ProviderStatus.NEEDS_CHANGES,
    'أكمل صور الهوية التجارية.',
  );

  assert.equal(result.title, 'مطلوب تعديل ملف المزوّد');
  assert.equal(result.body, 'أكمل صور الهوية التجارية.');
});
