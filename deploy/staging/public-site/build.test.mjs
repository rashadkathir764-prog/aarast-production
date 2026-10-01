import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import { buildStagingInvite } from './build.mjs';

const source = resolve('deploy/public-site');
const qa = {
  origin: 'https://invite.qa.example.com',
  inviteHost: 'invite.qa.example.com',
  packageName: 'com.aarast.aarast_mobile.qa',
  fingerprint: Array(32).fill('AB').join(':'),
};

test('staging invite artifact contains only QA identity and origin', () => {
  const out = mkdtempSync(join(tmpdir(), 'aarast-invite-'));
  try {
    buildStagingInvite({ source, out, ...qa });
    const html = readFileSync(join(out, 'invite.html'), 'utf8');
    const js = readFileSync(join(out, 'invite.js'), 'utf8');
    const links = JSON.parse(readFileSync(join(out, 'assetlinks.json'), 'utf8'));
    assert.match(html, /https:\/\/invite\.qa\.example\.com\/invites\//);
    assert.doesNotMatch(html, /aarast\.shadowgardn\.com/);
    assert.match(js, /aarast-qa:\/\/open\/invites\//);
    assert.equal(links[0].target.package_name, qa.packageName);
    assert.deepEqual(links[0].target.sha256_cert_fingerprints, [qa.fingerprint]);
  } finally { rmSync(out, { recursive: true, force: true }); }
});

test('staging invite build rejects Production host and identity', () => {
  const out = mkdtempSync(join(tmpdir(), 'aarast-invite-'));
  try {
    assert.throws(() => buildStagingInvite({ source, out, ...qa,
      origin: 'https://aarast.shadowgardn.com' }), /distinct/);
    assert.throws(() => buildStagingInvite({ source, out, ...qa,
      packageName: 'com.aarast.aarast_mobile' }), /distinct/);
    assert.throws(() => buildStagingInvite({ source, out, ...qa,
      fingerprint: 'fake' }), /fingerprint/);
    assert.throws(() => buildStagingInvite({ source, out, ...qa,
      inviteHost: 'aarast.shadowgardn.com' }), /must match/);
  } finally { rmSync(out, { recursive: true, force: true }); }
});
