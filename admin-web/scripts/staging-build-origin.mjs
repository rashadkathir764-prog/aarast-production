export function requireBuildApiOrigin(target, value) {
  const origin = value?.trim().replace(/\/$/, '') || '';
  if (target !== 'staging') return origin || 'https://aarast-api.shadowgardn.com';
  if (!origin) throw new Error('Staging Admin build requires explicit VITE_API_BASE_URL.');
  let parsed;
  try { parsed = new URL(origin); } catch {
    throw new Error('Staging Admin API origin must be public HTTPS.');
  }
  if (parsed.protocol !== 'https:' || parsed.origin !== origin ||
      parsed.username || parsed.password ||
      parsed.hostname === 'aarast-api.shadowgardn.com' ||
      parsed.hostname === 'aarast.shadowgardn.com' ||
      parsed.hostname.endsWith('.localhost') || parsed.hostname === 'localhost') {
    throw new Error('Staging Admin API origin must be distinct public HTTPS.');
  }
  return parsed.origin;
}
