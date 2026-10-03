export function requireBuildApiOrigin(target, value, routeProfile = 'isolated') {
  const origin = value?.trim().replace(/\/$/, '') || '';
  if (target !== 'staging') return origin || 'https://aarast-api.shadowgardn.com';
  if (!['isolated', 'aarast-controlled-cutover'].includes(routeProfile)) {
    throw new Error('Unknown Staging route profile');
  }
  const cutover = routeProfile === 'aarast-controlled-cutover';
  if (cutover && origin !== 'https://aarast-api.shadowgardn.com') {
    throw new Error('Controlled cutover requires the established Aarast API origin');
  }
  if (!origin) throw new Error('Staging Admin build requires explicit VITE_API_BASE_URL.');
  let parsed;
  try { parsed = new URL(origin); } catch {
    throw new Error('Staging Admin API origin must be public HTTPS.');
  }
  if (parsed.protocol !== 'https:' || parsed.origin !== origin ||
      parsed.username || parsed.password ||
      (!cutover && parsed.hostname === 'aarast-api.shadowgardn.com') ||
      parsed.hostname === 'aarast.shadowgardn.com' ||
      parsed.hostname.endsWith('.localhost') || parsed.hostname === 'localhost') {
    throw new Error('Staging Admin API origin must be distinct public HTTPS.');
  }
  return parsed.origin;
}
