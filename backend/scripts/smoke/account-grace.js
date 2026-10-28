'use strict';

// D63: an account is deleted in two steps. The app asks for it
// (`POST /api/v1/users/me/deletion`), and the hourly purge erases it once its
// 30 days are over. The HTTP smokes ask through the API, then, when they
// check what the erasure removes, run the purge on their isolated database.

/** w05: the word the account types to confirm. */
const ACCOUNT_DELETION_CONFIRM_WORD = 'حذف';

/** Asks for the account's deletion; `request` is the smoke's own HTTP helper. */
function requestAccountDeletion(request, token) {
  return request(
    'POST',
    '/api/v1/users/me/deletion',
    { confirmWord: ACCOUNT_DELETION_CONFIRM_WORD },
    token,
  );
}

/** The request was taken: the account waits out its 30 days. */
function isPendingDeletion(response) {
  return response.status === 200 && response.body?.status === 'PENDING';
}

/** Lets every pending account's 30 days pass and runs the purge; returns what it did. */
async function purgePendingAccounts() {
  require('ts-node/register');
  const { purgePendingAccounts: purge } = require('./account-purge.ts');
  return purge();
}

/**
 * A fixture account leaves the way a real one does: it asks, then the purge
 * erases it. True when both steps went through.
 */
async function eraseFixtureAccount(request, token) {
  const asked = await requestAccountDeletion(request, token);
  if (!isPendingDeletion(asked)) return false;
  const purge = await purgePendingAccounts();
  return purge.erased >= 1 && purge.failures.length === 0;
}

module.exports = {
  ACCOUNT_DELETION_CONFIRM_WORD,
  eraseFixtureAccount,
  isPendingDeletion,
  purgePendingAccounts,
  requestAccountDeletion,
};
