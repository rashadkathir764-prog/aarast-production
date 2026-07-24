import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SharedMemberRole } from '@prisma/client';
import { rolePermissionDefaults } from '../src/sharing/plan-permissions';
import { PermissionService } from '../src/sharing/permission.service';

test('groom and bride roles can operate the plan while retaining explicit money access', () => {
  for (const role of [SharedMemberRole.GROOM, SharedMemberRole.BRIDE]) {
    const permissions = rolePermissionDefaults(role);
    assert.equal(permissions.canEditPlan, true);
    assert.equal(permissions.canManageTasks, true);
    assert.equal(permissions.canManageGuests, true);
    assert.equal(permissions.canManageProviders, true);
    assert.equal(permissions.canViewMoney, true);
    assert.equal(permissions.canManageMoney, true);
  }
});

test('family and helper roles keep financial data private by default', () => {
  for (const role of [SharedMemberRole.FAMILY, SharedMemberRole.HELPER]) {
    const permissions = rolePermissionDefaults(role);
    assert.equal(permissions.canViewMoney, false);
    assert.equal(permissions.canManageMoney, false);
    assert.equal(permissions.canManageTasks, true);
    assert.equal(permissions.canManageGuests, true);
  }
});

test('viewer role is read-only and owner retains every permission', () => {
  const viewer = rolePermissionDefaults(SharedMemberRole.VIEWER);
  assert.equal(viewer.canEditPlan, false);
  assert.equal(viewer.canManageTasks, false);
  assert.equal(viewer.canManageGuests, false);
  assert.equal(viewer.canManageProviders, false);
  assert.equal(viewer.canInviteMembers, false);

  const owner = rolePermissionDefaults(SharedMemberRole.OWNER);
  assert.ok(Object.values(owner).every(Boolean));
});

test('stored provider permission overrides role defaults everywhere', () => {
  const service = new PermissionService({} as any);
  const context = (
    role: SharedMemberRole,
    canManageProviders: boolean,
  ) => ({
    plan: { ownerUserId: 'owner-1' },
    isOwner: false,
    sharedMember: {
      role,
      canManageProviders,
    },
  }) as any;

  assert.equal(
    service.canManageProviders(
      context(SharedMemberRole.HELPER, false),
    ),
    false,
  );
  assert.equal(
    service.canManageProviders(
      context(SharedMemberRole.GROOM, false),
    ),
    false,
  );
  assert.equal(
    service.canManageProviders(
      context(SharedMemberRole.VIEWER, true),
    ),
    true,
  );
});
