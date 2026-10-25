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

test('a refused profile leaves REJECTED only by its provider reopening it (B-02)', () => {
  for (const action of ['APPROVE', 'REQUEST_CHANGES', 'REJECT'] as const) {
    assert.equal(
      providerAdminActionAllowed(action, ProviderStatus.REJECTED),
      false,
      `${action} from REJECTED`,
    );
  }
});

test('the review team can rewrite its notes while the provider is fixing (B-01)', () => {
  assert.equal(
    providerAdminActionAllowed('REQUEST_CHANGES', ProviderStatus.NEEDS_CHANGES),
    true,
  );
  assert.equal(
    providerAdminActionAllowed('APPROVE', ProviderStatus.NEEDS_CHANGES),
    true,
  );
});

test('a refusal without a reason tells the provider to fix and apply again (B-02)', () => {
  const result = switchProviderStatusNotification(
    'استديو اعّرست',
    ProviderStatus.REJECTED,
    null,
  );
  assert.equal(result.body, 'صلّح ملف استديو اعّرست وقدّم من جديد من حسابك.');
});

test('provider lifecycle notification preserves the administration note', () => {
  const result = switchProviderStatusNotification(
    'استديو اعّرست',
    ProviderStatus.NEEDS_CHANGES,
    'أكمل صور الهوية التجارية.',
  );

  assert.equal(result.title, 'مطلوب تعديل ملف المزوّد');
  assert.equal(result.body, 'أكمل صور الهوية التجارية.');
});
