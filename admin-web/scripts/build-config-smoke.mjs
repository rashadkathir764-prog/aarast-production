import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const assetsDirectory = join(process.cwd(), 'dist', 'assets');
if (!existsSync(assetsDirectory)) {
  throw new Error('Admin build output is missing.');
}

const javascript = readdirSync(assetsDirectory)
  .filter((name) => name.endsWith('.js'))
  .map((name) => readFileSync(join(assetsDirectory, name), 'utf8'))
  .join('\n');

const productionApiOrigin = (
  process.env.VITE_API_BASE_URL || 'https://aarast-api.shadowgardn.com'
).replace(/\/$/, '');

if (javascript.includes('127.0.0.1:3115')) {
  throw new Error('Production admin build contains the loopback development API.');
}
if (!javascript.includes(productionApiOrigin)) {
  throw new Error(`Production admin build is missing API origin ${productionApiOrigin}.`);
}
if (!javascript.includes('/api/v1/auth/admin/login')) {
  throw new Error('Production admin build is missing the current MFA login route.');
}
if (
  !javascript.includes('/api/v1/auth/admin/password-reset/request') ||
  !javascript.includes('/api/v1/auth/admin/password-reset/confirm')
) {
  throw new Error('Production admin build is missing password recovery routes.');
}

console.log(`Admin build config PASS apiOrigin=${productionApiOrigin}`);
