import { readFileSync, readdirSync } from 'node:fs';
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

const miniLineChart = read(join(srcRoot, 'components', 'MiniLineChart.tsx'));
addCheck(
  'Legacy chart copy does not imply bookings',
  !miniLineChart.includes('bookings') && !miniLineChart.includes('الحجوزات'),
);

const appRoutes = read(join(srcRoot, 'App.tsx'));
const sidebar = read(join(srcRoot, 'layout', 'Sidebar.tsx'));
const dashboard = read(join(srcRoot, 'pages', 'DashboardPage.tsx'));
const adminApi = read(join(srcRoot, 'api', 'admin.ts'));
const authApi = read(join(srcRoot, 'api', 'auth.ts'));
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
    sidebar.includes('/conversation-reports') &&
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
  'Admin session tokens are not persisted in browser storage',
  !authApi.includes('localStorage') &&
    !authApi.includes('sessionStorage') &&
    !apiClient.includes('localStorage') &&
    !apiClient.includes('sessionStorage') &&
    authApi.includes('/auth/admin/login/complete') &&
    apiClient.includes("credentials: 'include'"),
);

for (const check of checks) {
  console.log(`${check.passed ? 'PASS' : 'FAIL'} - ${check.name}`);
  if (!check.passed && check.detail) console.log(`  ${check.detail}`);
}

if (checks.some((check) => !check.passed)) {
  process.exitCode = 1;
}
