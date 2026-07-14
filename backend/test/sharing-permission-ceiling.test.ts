import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SharedMemberRole } from '@prisma/client';
import { PermissionService, PlanAccessContext } from '../src/sharing/permission.service';
import { rolePermissionDefaults } from '../src/sharing/plan-permissions';
import { SharingService } from '../src/sharing/sharing.service';

const permissions = new PermissionService({} as any);
const sharing = new SharingService({} as any, permissions, {} as any);

function memberContext(
  role: SharedMemberRole,
  overrides: Record<string, boolean> = {},
): PlanAccessContext {
  return {
    plan: { id: 'plan-1', ownerUserId: 'owner-1' } as any,
    isOwner: false,
    sharedMember: {
      role,
      ...rolePermissionDefaults(role),
      ...overrides,
    } as any,
  };
}

function assertCeiling(
  inviter: PlanAccessContext,
  targetRole: SharedMemberRole,
  targetOverrides: Record<string, boolean> = {},
) {
  (sharing as any).assertPermissionCeiling(inviter, targetRole, {
    ...rolePermissionDefaults(targetRole),
    ...targetOverrides,
  });
}

test('owner may delegate every non-owner role', () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      {
        plan: { id: 'plan-1', ownerUserId: 'owner-1' } as any,
        isOwner: true,
        sharedMember: null,
      },
      SharedMemberRole.FINANCE_MANAGER,
    ),
  );
});

test('manager and helper cannot mint finance authority they do not own', () => {
  for (const role of [SharedMemberRole.MANAGER, SharedMemberRole.HELPER]) {
    assert.throws(
      () =>
        assertCeiling(
          memberContext(role, { canInviteMembers: true }),
          SharedMemberRole.FINANCE_MANAGER,
        ),
      /canViewMoney|canManageMoney/,
    );
  }
});

test('manager may delegate an editor role inside the manager ceiling', () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      memberContext(SharedMemberRole.MANAGER, { canInviteMembers: true }),
      SharedMemberRole.EDITOR,
    ),
  );
});

test('explicit finance plus invite delegation may be passed on but not enlarged', () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      memberContext(SharedMemberRole.FINANCE_MANAGER, {
        canInviteMembers: true,
      }),
      SharedMemberRole.FINANCE_MANAGER,
    ),
  );

  assert.throws(
    () =>
      assertCeiling(
        memberContext(SharedMemberRole.FINANCE_MANAGER, {
          canInviteMembers: true,
        }),
        SharedMemberRole.MANAGER,
      ),
    /canEditPlan|canManageTasks/,
  );
});

test('viewer with invite delegation can only create another viewer', () => {
  const inviter = memberContext(SharedMemberRole.VIEWER, {
    canInviteMembers: true,
  });
  assert.doesNotThrow(() => assertCeiling(inviter, SharedMemberRole.VIEWER));
  assert.throws(
    () => assertCeiling(inviter, SharedMemberRole.HELPER),
    /canManageTasks|canManageGuests|canManageProviders/,
  );
});
