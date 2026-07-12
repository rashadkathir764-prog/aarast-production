import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SharedMemberRole } from '@prisma/client';
import { rolePermissionDefaults } from '../src/sharing/plan-permissions';

test('groom and bride roles can operate the plan while retaining explicit money access', () => {
  for (const role of [SharedMemberRole.GROOM, SharedMemberRole.BRIDE]) {
    const permissions = rolePermissionDefaults(role);
    assert.equal(permissions.canEditPlan, true);
    assert.equal(permissions.canManageTasks, true);
    assert.equal(permissions.canManageGuests, true);
    assert.equal(permissions.canManageProviders, true);
    assert.equal(permissions.canManageFinancialRecords, true);
  }
});

test('family and helper roles keep financial data private by default', () => {
  for (const role of [SharedMemberRole.FAMILY, SharedMemberRole.HELPER]) {
    const permissions = rolePermissionDefaults(role);
    assert.equal(permissions.canViewBudget, false);
    assert.equal(permissions.canViewExpenses, false);
    assert.equal(permissions.canViewFinancialRecords, false);
    assert.equal(permissions.canManageFinancialRecords, false);
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
