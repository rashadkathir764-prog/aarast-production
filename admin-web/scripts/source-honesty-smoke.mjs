import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const srcRoot = join(process.cwd(), 'src');
const checks = [];

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return walk(path);
    return /\.(tsx?|css)$/.test(entry.name) ? [path] : [];
  });
}

function read(path) {
  return readFileSync(path, 'utf8');
}

function addCheck(name, passed, detail = '') {
  checks.push({ name, passed, detail });
}

const sourceFiles = walk(srcRoot);
const mojibakePattern = /[ØÙÂâ]/;
const mojibakeHits = sourceFiles
  .map((file) => ({ file, text: read(file) }))
  .filter(({ text }) => mojibakePattern.test(text));

addCheck(
  'Arabic source text is not mojibake',
  mojibakeHits.length === 0,
  mojibakeHits.map(({ file }) => file).join(', '),
);

const statusBadge = read(join(srcRoot, 'components', 'StatusBadge.tsx'));
addCheck(
  'Provider ACTIVE status is not labeled confirmed',
  !statusBadge.includes('مؤكد') && statusBadge.includes("ACTIVE: { label: 'نشط'"),
);
addCheck(
  'Rejected status is not labeled canceled',
  statusBadge.includes("REJECTED: { label: 'مرفوض'"),
);

addCheck(
  'Unused legacy chart is removed',
  !existsSync(join(srcRoot, 'components', 'MiniLineChart.tsx')),
);

const appRoutes = read(join(srcRoot, 'App.tsx'));
const sidebar = read(join(srcRoot, 'layout', 'Sidebar.tsx'));
const navigation = read(join(srcRoot, 'layout', 'adminNavigation.ts'));
const dashboard = read(join(srcRoot, 'pages', 'DashboardPage.tsx'));
const adminApi = read(join(srcRoot, 'api', 'admin.ts'));
const authApi = read(join(srcRoot, 'api', 'auth.ts'));
const loginPage = read(join(srcRoot, 'pages', 'LoginPage.tsx'));
const apiClient = read(join(srcRoot, 'api', 'client.ts'));
const adminRuntimeSmoke = read(join(process.cwd(), 'scripts', 'admin-runtime-smoke.mjs'));
const conversationReportsPagePath = join(
  srcRoot,
  'pages',
  'ConversationReportsPage.tsx',
);

addCheck(
  'Unsupported admin pages are not routed',
  !/path="(bookings|payments|settings|audit-log)"/.test(appRoutes),
);

addCheck(
  'Unsupported admin pages are not in sidebar',
  !/\/(bookings|payments|settings|audit-log)(?:[/'"`]|$)/.test(sidebar),
);

addCheck(
  'Dashboard does not show disabled admin modules',
  !dashboard.includes('غير مفعّل') &&
    !dashboard.includes('تحتاج API') &&
    !dashboard.includes('حجوزات') &&
    !dashboard.includes('حالة دفع'),
);

addCheck(
  'Conversation report moderation is fully routed',
  appRoutes.includes('path="conversation-reports"') &&
    navigation.includes("route: '/conversation-reports'") &&
    adminApi.includes('/admin/conversation-reports') &&
    sourceFiles.includes(conversationReportsPagePath),
);

addCheck(
  'Admin runtime smoke has no hardcoded credential fallback',
  !adminRuntimeSmoke.includes('ADMIN_SMOKE_ALLOW_DEV_CREDENTIALS') &&
    !adminRuntimeSmoke.includes('Aarast@') &&
    !adminRuntimeSmoke.includes("|| '770"),
);

addCheck(
  'Admin runtime smoke uses only the canonical versioned auth API',
  adminRuntimeSmoke.includes('/api/v1/auth/admin/login') &&
    !adminRuntimeSmoke.includes('request("/auth/'),
);

addCheck(
  'Admin session tokens are not persisted in browser storage',
  !authApi.includes('localStorage') &&
    !authApi.includes('sessionStorage') &&
    !apiClient.includes('localStorage') &&
    !apiClient.includes('sessionStorage') &&
    authApi.includes('/auth/admin/login/complete') &&
    apiClient.includes("credentials: 'include'"),
);

addCheck(
  'Admin password recovery is real and keeps its challenge in memory only',
  authApi.includes('/auth/admin/password-reset/request') &&
    authApi.includes('/auth/admin/password-reset/confirm') &&
    loginPage.includes('requestAdminPasswordReset') &&
    loginPage.includes('confirmAdminPasswordReset') &&
    loginPage.includes('نسيت كلمة المرور؟') &&
    !loginPage.includes('localStorage') &&
    !loginPage.includes('sessionStorage'),
);

for (const check of checks) {
  console.log(`${check.passed ? 'PASS' : 'FAIL'} - ${check.name}`);
  if (!check.passed && check.detail) console.log(`  ${check.detail}`);
}

if (checks.some((check) => !check.passed)) {
  process.exitCode = 1;
}
