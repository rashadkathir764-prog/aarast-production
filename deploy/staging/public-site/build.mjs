import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

export function buildStagingInvite({ source, out, origin, inviteHost, packageName, fingerprint, routeProfile = 'isolated' }) {
  if (!['isolated', 'aarast-controlled-cutover'].includes(routeProfile)) {
    throw new Error('Unknown Staging route profile');
  }
  const cutover = routeProfile === 'aarast-controlled-cutover';
  if (cutover && origin !== 'https://aarast.shadowgardn.com') {
    throw new Error('Controlled cutover requires the established Aarast invite origin');
  }
  let url;
  try { url = new URL(origin); } catch { throw new Error('Invite origin must be public HTTPS'); }
  if (url.protocol !== 'https:' || url.origin !== origin ||
      (!cutover && url.hostname === 'aarast.shadowgardn.com') ||
      url.hostname.endsWith('.invalid') || url.hostname === 'localhost') {
    throw new Error('Invite origin must be a distinct public HTTPS origin');
  }
  if (url.hostname !== inviteHost) {
    throw new Error('QA Android invite host must match staging invite origin');
  }
  if (!/^com\.[A-Za-z0-9_.]+$/.test(packageName) ||
      packageName === 'com.aarast.aarast_mobile') {
    throw new Error('Staging invite requires a distinct QA application ID');
  }
  if (!/^(?:[A-Fa-f0-9]{2}:){31}[A-Fa-f0-9]{2}$/.test(fingerprint)) {
    throw new Error('QA signing SHA-256 fingerprint is required');
  }
  mkdirSync(out, { recursive: true });
  // RA-OP-27: the same files the production image serves (its Dockerfile COPY
  // line), so a guest's RSVP link, the terms and the download page open on QA.
  for (const name of [
    'invite.css', 'invite-preview.png', 'rsvp-preview.png', 'public.css',
    'rsvp.js', 'rsvp.css', 'download.js', 'qrcode-generator.js', 'delete-account.js',
  ]) {
    copyFileSync(resolve(source, name), resolve(out, name));
  }
  for (const name of ['invite.html', 'privacy.html', 'terms.html', 'support.html', 'rsvp.html', 'download.html', 'delete-account.html']) {
    const original = readFileSync(resolve(source, name), 'utf8');
    const changed = original.replaceAll('https://aarast.shadowgardn.com', origin);
    if (!cutover && changed.includes('aarast.shadowgardn.com')) throw new Error(`${name} still points to Production`);
    writeFileSync(resolve(out, name), changed);
  }
  const inviteJs = readFileSync(resolve(source, 'invite.js'), 'utf8')
    .replace('aarast://open/invites/', 'aarast-qa://open/invites/');
  if (inviteJs.includes('aarast://open/invites/') ||
      !inviteJs.includes('aarast-qa://open/invites/')) {
    throw new Error('Staging invite page must launch only the QA app');
  }
  writeFileSync(resolve(out, 'invite.js'), inviteJs);
  writeFileSync(resolve(out, 'assetlinks.json'), JSON.stringify([{
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: packageName,
      sha256_cert_fingerprints: [fingerprint.toUpperCase()],
    },
  }], null, 2));
  copyFileSync(resolve(source, 'nginx.conf'), resolve(out, 'nginx.conf'));
}

if (process.argv[1] && new URL(import.meta.url).pathname.endsWith(process.argv[1].replaceAll('\\', '/'))) {
  buildStagingInvite({
    source: resolve(process.argv[2]),
    out: resolve(process.argv[3]),
    origin: process.env.STAGING_INVITE_ORIGIN,
    inviteHost: process.env.STAGING_QA_INVITE_HOST,
    packageName: process.env.STAGING_QA_APPLICATION_ID,
    fingerprint: process.env.STAGING_QA_CERT_FINGERPRINT,
    routeProfile: process.env.STAGING_ROUTE_PROFILE,
  });
  console.log('PASS: Staging invite site has QA origin, scheme and assetlinks');
}
