#!/usr/bin/env node
'use strict';

const { readFileSync, statSync } = require('node:fs');

function fail(message) {
  process.stderr.write(`Firebase credential check failed: ${message}\n`);
  process.exit(1);
}

const pushSetting = process.env.PUSH_NOTIFICATIONS_ENABLED?.trim().toLowerCase();
if (pushSetting && !['true', 'false'].includes(pushSetting)) {
  fail('PUSH_NOTIFICATIONS_ENABLED must be true or false');
}

if (pushSetting !== 'true') {
  process.stdout.write('Firebase credential check skipped (push disabled).\n');
  process.exit(0);
}

const expectedProjectId = process.env.FIREBASE_PROJECT_ID?.trim();
const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
if (!expectedProjectId || !credentialPath) {
  fail('required push configuration is incomplete');
}

let credentialFile;
try {
  const credentialStat = statSync(credentialPath);
  if (!credentialStat.isFile()) {
    fail('credential path is not a regular file');
  }
  if (process.platform !== 'win32' && (credentialStat.mode & 0o077) !== 0) {
    fail('credential file permissions are too broad');
  }
  credentialFile = JSON.parse(readFileSync(credentialPath, 'utf8'));
} catch {
  fail('credential file is missing or invalid');
}

if (
  credentialFile?.type !== 'service_account' ||
  credentialFile?.project_id !== expectedProjectId ||
  typeof credentialFile?.client_email !== 'string' ||
  !credentialFile.client_email.endsWith('.iam.gserviceaccount.com') ||
  typeof credentialFile?.private_key !== 'string' ||
  !credentialFile.private_key.includes('-----BEGIN PRIVATE KEY-----') ||
  !credentialFile.private_key.includes('-----END PRIVATE KEY-----')
) {
  fail('credential file does not match the configured Firebase project');
}

process.stdout.write('Firebase credential check passed.\n');
