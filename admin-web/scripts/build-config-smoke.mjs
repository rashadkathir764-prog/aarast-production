import {
  existsSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { join } from 'node:path';

const assetsDirectory = join(process.cwd(), 'dist', 'assets');
if (!existsSync(assetsDirectory)) {
  throw new Error('Admin build output is missing.');
}

const javascript = readdirSync(assetsDirectory)
  .filter((name) => name.endsWith('.js'))
  .map((name) => readFileSync(join(assetsDirectory, name), 'utf8'))
  .join('\n');

const productionApiOrigin = requirePublicHttpsOrigin(
  process.env.VITE_API_BASE_URL || 'https://aarast-api.shadowgardn.com',
);

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

writeFileSync(
  join(process.cwd(), 'dist', 'aarast-build-config.json'),
  `${JSON.stringify({ apiOrigin: productionApiOrigin })}\n`,
  'utf8',
);

console.log(`Admin build config PASS apiOrigin=${productionApiOrigin}`);

function requirePublicHttpsOrigin(value) {
  const trimmed = value.trim().replace(/\/$/, '');
  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new Error('VITE_API_BASE_URL must be a public HTTPS origin.');
  }
  if (
    parsed.protocol !== 'https:' ||
    parsed.origin !== trimmed ||
    parsed.username ||
    parsed.password ||
    isPrivateHost(parsed.hostname)
  ) {
    throw new Error('VITE_API_BASE_URL must be a public HTTPS origin.');
  }
  return parsed.origin;
}

function isPrivateHost(hostname) {
  const normalized = hostname.toLowerCase().replace(/^\[|\]$/g, '');
  if (
    normalized === 'localhost' ||
    normalized.endsWith('.localhost') ||
    normalized.endsWith('.local') ||
    normalized === '::1' ||
    normalized === '0.0.0.0'
  ) {
    return true;
  }
  const octets = normalized.split('.').map(Number);
  if (
    octets.length === 4 &&
    octets.every((octet) => Number.isInteger(octet) && octet >= 0 && octet <= 255)
  ) {
    return (
      octets[0] === 10 ||
      octets[0] === 127 ||
      (octets[0] === 169 && octets[1] === 254) ||
      (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] === 192 && octets[1] === 168)
    );
  }
  return normalized.startsWith('fc') || normalized.startsWith('fd');
}
