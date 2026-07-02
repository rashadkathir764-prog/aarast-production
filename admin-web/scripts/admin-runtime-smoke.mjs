const baseUrl = (
  process.env.ADMIN_SMOKE_BASE_URL ||
  process.env.VITE_API_BASE_URL ||
  'http://127.0.0.1:3115'
).replace(/\/$/, '');

const allowDevCredentials = process.env.ADMIN_SMOKE_ALLOW_DEV_CREDENTIALS === 'true';
const phone = process.env.ADMIN_SMOKE_PHONE || (allowDevCredentials ? '770579680' : '');
const password = process.env.ADMIN_SMOKE_PASSWORD || (allowDevCredentials ? 'Aarast@123456' : '');

const checks = [];
let token = '';

function check(name, passed, detail = '') {
  checks.push({ name, passed, detail });
  console.log(`${passed ? 'PASS' : 'FAIL'} - ${name}${detail && !passed ? ` (${detail})` : ''}`);
}

function hasPasswordHash(value) {
  return JSON.stringify(value).includes('passwordHash');
}

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method || 'GET',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(options.auth === false || !token ? {} : { Authorization: `Bearer ${token}` }),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  const text = await response.text();
  let body = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }

  return { status: response.status, body };
}

function requireCredentials() {
  if (phone && password) return;

  console.error('Admin Runtime Smoke Report');
  console.error(`Target: ${baseUrl}`);
  console.error('Overall Result: FAIL');
  console.error(
    'Set ADMIN_SMOKE_PHONE and ADMIN_SMOKE_PASSWORD, or set ADMIN_SMOKE_ALLOW_DEV_CREDENTIALS=true for local dev credentials.',
  );
  process.exit(1);
}

async function run() {
  requireCredentials();

  console.log('Admin Runtime Smoke Report');
  console.log(`Target: ${baseUrl}`);
  console.log(`Credentials: ${allowDevCredentials ? 'local dev admin' : 'provided by env'}\n`);

  let res = await request('/health', { auth: false });
  check('backend health returns 200', res.status === 200, String(res.status));
  check('health response does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/admin/dashboard/stats', { auth: false });
  check('admin stats rejects unauthenticated access', res.status === 401, String(res.status));

  res = await request('/auth/login', {
    method: 'POST',
    auth: false,
    body: { phone, password },
  });
  check('admin login returns 200 or 201', res.status === 200 || res.status === 201, String(res.status));
  check('admin login returns ADMIN user', res.body?.user?.role === 'ADMIN');
  check('admin login returns access token', typeof res.body?.accessToken === 'string');
  check('admin login does not expose passwordHash', !hasPasswordHash(res.body));

  if (typeof res.body?.accessToken !== 'string') {
    throw new Error('Admin login did not return an access token.');
  }
  token = res.body.accessToken;

  res = await request('/auth/me');
  check('auth me returns admin user', res.status === 200 && res.body?.role === 'ADMIN', String(res.status));
  check('auth me does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/admin/dashboard/stats');
  check('admin stats returns totals', res.status === 200 && Number.isFinite(res.body?.totalUsers), String(res.status));
  check('admin stats does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/notifications');
  check('current admin notifications returns array', res.status === 200 && Array.isArray(res.body), String(res.status));
  check('current admin notifications does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/notifications/unread-count');
  check(
    'current admin unread notifications count returns number',
    res.status === 200 && Number.isFinite(res.body?.count),
    String(res.status),
  );
  check('current admin unread notifications count does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/admin/users?limit=5');
  check('admin users list returns paginated items', res.status === 200 && Array.isArray(res.body?.items), String(res.status));
  check('admin users list does not expose passwordHash', !hasPasswordHash(res.body));
  const firstUserId = res.body?.items?.[0]?.id;

  if (firstUserId) {
    res = await request(`/admin/users/${encodeURIComponent(firstUserId)}`);
    check('admin user detail returns safe user', res.status === 200 && res.body?.id === firstUserId, String(res.status));
    check('admin user detail does not expose passwordHash', !hasPasswordHash(res.body));
  } else {
    check('admin user detail skipped because users list is empty', true);
  }

  res = await request('/admin/cities');
  check('admin cities list returns array', res.status === 200 && Array.isArray(res.body), String(res.status));
  check('admin cities list does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/admin/provider-categories');
  check('admin provider categories list returns array', res.status === 200 && Array.isArray(res.body), String(res.status));
  check('admin provider categories list does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/admin/providers/applications?limit=5');
  check(
    'admin provider applications list returns paginated items',
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check('admin provider applications list does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/admin/providers?limit=5');
  check('admin providers list returns paginated items', res.status === 200 && Array.isArray(res.body?.items), String(res.status));
  check('admin providers list does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/services?limit=5');
  check('service references list returns paginated items', res.status === 200 && Array.isArray(res.body?.items), String(res.status));
  check('service references list does not expose passwordHash', !hasPasswordHash(res.body));

  res = await request('/providers?limit=5');
  check('public provider references list returns paginated items', res.status === 200 && Array.isArray(res.body?.items), String(res.status));
  check('public provider references list does not expose passwordHash', !hasPasswordHash(res.body));
  const firstPublicProviderId = res.body?.items?.[0]?.id;

  if (firstPublicProviderId) {
    res = await request(`/providers/${encodeURIComponent(firstPublicProviderId)}/reviews`);
    check('public provider reviews returns array', res.status === 200 && Array.isArray(res.body), String(res.status));
    check('public provider reviews does not expose passwordHash', !hasPasswordHash(res.body));
  } else {
    check('public provider reviews skipped because active providers list is empty', true);
  }

  const failed = checks.filter((item) => !item.passed);
  console.log(`\nOverall Result: ${failed.length ? 'FAIL' : 'PASS'}`);
  if (failed.length) process.exit(1);
}

run().catch((error) => {
  console.error('\nOverall Result: FAIL');
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
