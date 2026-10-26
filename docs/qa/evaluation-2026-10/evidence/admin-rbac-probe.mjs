// Admin RBAC probe: each of the four admin roles (and a plain app user) tries
// reads and writes that need a specific permission. Expected = the role
// matrix in backend/src/modules/backoffice/domain/admin-permissions.ts.
const BASE = 'http://localhost:3215';
const PW = process.env.DEMO_PASSWORD;
const T = process.env.TARGETS ? JSON.parse(process.env.TARGETS) : {};
const post = (p, b, h = {}) => fetch(BASE + p, { method: 'POST', headers: { 'content-type': 'application/json', ...h }, body: JSON.stringify(b) });
async function adminLogin(phone, i) {
  const h = { 'x-forwarded-for': `7.7.8.${i}` };
  const a = await (await post('/api/v1/auth/admin/login', { phone, password: PW }, h)).json();
  const b = await (await post('/api/v1/auth/admin/login/complete', { challengeToken: a.challengeToken, code: a.code }, h)).json();
  if (!b.accessToken) throw new Error(phone + ' ' + JSON.stringify(b).slice(0, 150));
  return b.accessToken;
}
async function appLogin(phone) {
  const j = await (await post('/api/v1/auth/login', { phone, password: PW }, { 'x-forwarded-for': '7.7.9.9' })).json();
  return j.accessToken;
}
const roles = {
  SUPER_ADMIN: await adminLogin('+967777000401', 1),
  OPERATIONS: await adminLogin('+967777000402', 2),
  MODERATOR: await adminLogin('+967777000403', 3),
  SUPPORT: await adminLogin('+967777000404', 4),
  APP_USER_TOKEN: await appLogin('+967777000101'),
};
// [label, permission, method, path, body]
const checks = [
  ['users list', 'USERS_READ', 'GET', '/admin/users?take=20'],
  ['audit log', 'AUDIT_READ', 'GET', '/admin/audit-logs?take=20'],
  ['bookings', 'PROVIDERS_READ', 'GET', '/admin/bookings?take=20'],
  ['conversation reports', 'CONVERSATION_REPORTS_READ', 'GET', '/admin/conversation-reports'],
  ['disable user', 'USERS_WRITE', 'PATCH', `/admin/users/${T.user}/disable`, { reason: 'rbac probe' }],
  ['activate user', 'USERS_WRITE', 'PATCH', `/admin/users/${T.user}/activate`, {}],
  ['request provider changes', 'PROVIDERS_WRITE', 'PATCH', `/admin/providers/${T.provider}/request-changes`, { note: 'rbac probe' }],
  ['hide review', 'REVIEWS_WRITE', 'PATCH', `/admin/reviews/${T.review}/status`, { status: 'HIDDEN' }],
  ['edit city', 'CATALOG_WRITE', 'PATCH', `/admin/cities/${T.city}`, {}],
];
const allowed = {
  SUPER_ADMIN: 'ALL',
  OPERATIONS: ['USERS_READ', 'USERS_WRITE', 'PROVIDERS_READ', 'PROVIDERS_WRITE', 'CATALOG_WRITE', 'REVIEWS_READ'],
  MODERATOR: ['PROVIDERS_READ', 'REVIEWS_READ', 'REVIEWS_WRITE', 'CONVERSATION_REPORTS_READ', 'CONVERSATION_REPORTS_WRITE'],
  SUPPORT: ['USERS_READ', 'PROVIDERS_READ'],
  APP_USER_TOKEN: [],
};
const rows = [];
let violations = 0;
for (const [label, perm, m, path, body] of checks) {
  const row = { check: label, needs: perm };
  for (const [role, tok] of Object.entries(roles)) {
    const r = await fetch(BASE + path, { method: m, headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
    const may = allowed[role] === 'ALL' || allowed[role].includes(perm);
    const denied = r.status === 401 || r.status === 403;
    const ok = may ? !denied : denied;
    if (!ok) violations++;
    row[role] = `${r.status}${ok ? '' : ' ✗'}`;
  }
  rows.push(row);
}
console.table(rows);
console.log(`violations (allowed role denied, or denied role let through): ${violations}`);
