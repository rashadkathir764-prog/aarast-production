'use strict';

// RA-BE-42: a participant joins a plan only by accepting an invite (P5); the
// direct add answers ADD_BY_INVITE, for an account id as for a number. The
// smokes seat their participants the way the app does: the inviter invites
// the number and the invitee accepts it.
//
// The direct add stored every flag it was not given as false; an invite
// fills them from the role. So a flag left out here is sent as false, and a
// check keeps the rights it asked for.
const FLAGS = [
  'canViewMoney',
  'canEditPlan',
  'canManageTasks',
  'canManageGuests',
  'canManageProviders',
  'canInviteMembers',
  'canManageMoney',
];

/**
 * Invites `member.phone` to the plan and accepts it as `member.token`.
 * Answers like the direct add did: `status` 201 and `body` the member, or
 * the first refusal's status and body.
 */
async function inviteAndAccept(request, { planId, inviterToken, member, access }) {
  const { role = 'VIEWER', ...flags } = access ?? {};
  const body = { phone: member.phone, role };
  for (const flag of FLAGS) body[flag] = flags[flag] === true;
  if (flags.receiveNotifications !== undefined) {
    body.receiveNotifications = flags.receiveNotifications;
  }
  const invite = await request(
    'POST',
    `/api/v1/wedding-plans/${planId}/invites`,
    body,
    inviterToken,
  );
  if (invite.status !== 201 || typeof invite.body?.token !== 'string') {
    return { status: invite.status, body: invite.body, invite };
  }
  // An empty object, not null: some smokes' request helpers send null as the
  // JSON text "null", which the body parser refuses before any route.
  const accepted = await request(
    'POST',
    `/api/v1/invites/${invite.body.token}/accept`,
    {},
    member.token,
  );
  if (accepted.status !== 201) {
    return { status: accepted.status, body: accepted.body, invite, accepted };
  }
  return { status: 201, body: accepted.body?.member, invite, accepted };
}

module.exports = { inviteAndAccept };
