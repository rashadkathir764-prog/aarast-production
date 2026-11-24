import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
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

// RA-OP-27: the staging site is the production site with the QA origin, so
// every file the production image serves (its Dockerfile's COPY line) is in the
// staging artifact too. A guest's RSVP link, the terms and the download page
// were 404 on staging while every test was green.
test('RA-OP-27: staging serves every page and asset the production image does', () => {
  const dockerfile = readFileSync(join(source, 'Dockerfile'), 'utf8');
  const copy = /^COPY ((?:[\w.-]+ )+)\/usr\/share\/nginx\/html\/$/m.exec(dockerfile);
  assert.ok(copy, 'the production Dockerfile has one COPY of the site files');
  const served = copy[1].trim().split(/\s+/);
  const out = mkdtempSync(join(tmpdir(), 'aarast-invite-'));
  try {
    buildStagingInvite({ source, out, ...qa });
    for (const name of served) {
      assert.ok(existsSync(join(out, name)), `${name} is served by production but missing from staging`);
    }
    for (const page of ['rsvp.html', 'terms.html', 'download.html']) {
      assert.doesNotMatch(readFileSync(join(out, page), 'utf8'), /aarast\.shadowgardn\.com/, page);
    }
    assert.match(readFileSync(join(out, 'terms.html'), 'utf8'), /https:\/\/invite\.qa\.example\.com\/terms/);
  } finally { rmSync(out, { recursive: true, force: true }); }
});
