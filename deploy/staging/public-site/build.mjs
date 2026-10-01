import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

export function buildStagingInvite({ source, out, origin, inviteHost, packageName, fingerprint }) {
  let url;
  try { url = new URL(origin); } catch { throw new Error('Invite origin must be public HTTPS'); }
  if (url.protocol !== 'https:' || url.origin !== origin ||
      url.hostname === 'aarast.shadowgardn.com' ||
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
  for (const name of ['invite.css', 'invite-preview.png', 'public.css']) {
    copyFileSync(resolve(source, name), resolve(out, name));
  }
  for (const name of ['invite.html', 'privacy.html', 'support.html']) {
    const original = readFileSync(resolve(source, name), 'utf8');
    const changed = original.replaceAll('https://aarast.shadowgardn.com', origin);
    if (changed.includes('aarast.shadowgardn.com')) throw new Error(`${name} still points to Production`);
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
  });
  console.log('PASS: Staging invite site has QA origin, scheme and assetlinks');
}
