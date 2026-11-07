import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test, after } from 'node:test';

// Execute the real Gradle/Kotlin release guard without loading Android plugins,
// signing material, or building an APK. No translated/mocked validation logic.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = fs.readFileSync(path.join(root, 'mobile/android/app/build.gradle.kts'), 'utf8');
const start = source.indexOf('fun decodedDartDefines()');
const end = source.indexOf('val productionApplicationId =');
assert.ok(start >= 0 && end > start, 'Release guard must be present');
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'aarast-android-release-guard-'));
after(() => fs.rmSync(scratch, { recursive: true, force: true }));
fs.writeFileSync(path.join(scratch, 'settings.gradle.kts'), 'rootProject.name = "aarast-release-guard-proof"\n');
fs.writeFileSync(path.join(scratch, 'build.gradle.kts'),
  'import java.net.URI\nimport java.util.Base64\nimport java.nio.charset.StandardCharsets\n' +
  source.slice(start, end) + '\nvalidateReleaseDartDefines(false)\n');

const version = /gradle-([\d.]+)-all/.exec(fs.readFileSync(
  path.join(root, 'mobile/android/gradle/wrapper/gradle-wrapper.properties'), 'utf8'))[1];
const cache = path.join(process.env.GRADLE_USER_HOME || path.join(os.homedir(), '.gradle'),
  'wrapper/dists', `gradle-${version}-all`);
const homes = process.env.GRADLE_HOME ? [process.env.GRADLE_HOME] :
  fs.readdirSync(cache).map(p => path.join(cache, p, `gradle-${version}`));
const gradle = homes.map(p => path.join(p, 'lib', `gradle-gradle-cli-main-${version}.jar`))
  .find(p => fs.existsSync(p));
assert.ok(gradle, 'Install the pinned Gradle distribution or set GRADLE_HOME');
const java = process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, 'bin',
  process.platform === 'win32' ? 'java.exe' : 'java') : 'java';

const defines = {
  AARAST_API_BASE_URL: 'https://aarast-api.shadowgardn.com',
  AARAST_ENVIRONMENT: 'staging',
  AARAST_STAGING_ROUTE_PROFILE: 'aarast-controlled-cutover',
  AARAST_INVITE_HOST: 'aarast.shadowgardn.com',
  AARAST_INVITE_SCHEME: 'aarast-qa',
  AARAST_FIREBASE_API_KEY: 'test-only-not-a-credential',
  AARAST_FIREBASE_PROJECT_ID: 'aarast-staging-qa',
  AARAST_FIREBASE_APP_ID: '1:842961585206:android:7f7deeb6f5f765d14a0497',
  AARAST_FIREBASE_MESSAGING_SENDER_ID: '842961585206',
};
const identity = {
  AARAST_ANDROID_APPLICATION_ID: 'com.aarast.aarast_mobile.qa',
  AARAST_ANDROID_APP_LABEL: 'Aarast Test Release',
  AARAST_ANDROID_SIGNING_PROFILE: 'qa',
};
function run(overrides = {}, env = {}) {
  const values = { ...defines, ...overrides };
  const encoded = Object.entries(values).filter(([, v]) => v !== null)
    .map(([k, v]) => Buffer.from(`${k}=${v}`).toString('base64')).join(',');
  const result = spawnSync(java, ['-jar', gradle, '--offline', '-p', scratch,
    '--console=plain', '--max-workers=2', 'help', `-Pdart-defines=${encoded}`], {
    env: { ...process.env, ...identity, ...env }, encoding: 'utf8', timeout: 180000,
    maxBuffer: 2 * 1024 * 1024,
  });
  assert.ifError(result.error);
  return { status: result.status, output: result.stdout + result.stderr };
}
test('explicit controlled cutover accepts only the deployed Aarast API/invite pair', () => {
  const result = run();
  assert.equal(result.status, 0, result.output);
});
test('isolated staging still rejects existing Aarast hosts', () => {
  assert.notEqual(run({ AARAST_STAGING_ROUTE_PROFILE: null }).status, 0);
});
test('unknown route profile cannot bypass staging host protection', () => {
  assert.notEqual(run({ AARAST_STAGING_ROUTE_PROFILE: 'unknown' }).status, 0);
});
test('cutover rejects a different API or invite host', () => {
  assert.notEqual(run({ AARAST_API_BASE_URL: 'https://other.example.org' }).status, 0);
  assert.notEqual(run({ AARAST_INVITE_HOST: 'other.example.org' }).status, 0);
});
test('cutover rejects a non-origin API URL', () => {
  assert.notEqual(run({ AARAST_API_BASE_URL: 'https://aarast-api.shadowgardn.com/other' }).status, 0);
});
test('production cannot select the staging-only cutover state', () => {
  assert.notEqual(run({ AARAST_ENVIRONMENT: 'production' }, {
    AARAST_ANDROID_APPLICATION_ID: 'com.aarast.aarast_mobile',
    AARAST_ANDROID_SIGNING_PROFILE: '',
  }).status, 0);
});
test('production release configuration is unchanged without the cutover profile', () => {
  const result = run({ AARAST_ENVIRONMENT: 'production',
    AARAST_STAGING_ROUTE_PROFILE: null, AARAST_FIREBASE_PROJECT_ID: 'aarast-d62e9' }, {
    AARAST_ANDROID_APPLICATION_ID: 'com.aarast.aarast_mobile',
    AARAST_ANDROID_SIGNING_PROFILE: '',
  });
  assert.equal(result.status, 0, result.output);
});
test('cutover cannot use old Firebase, missing Firebase, or another app identity', () => {
  assert.notEqual(run({ AARAST_FIREBASE_PROJECT_ID: 'aarast-d62e9' }).status, 0);
  assert.notEqual(run({ AARAST_FIREBASE_API_KEY: null }).status, 0);
  assert.notEqual(run({}, { AARAST_ANDROID_APPLICATION_ID: 'com.aarast.aarast_mobile' }).status, 0);
});
test('cutover still requires QA signing and forbids login bypass', () => {
  assert.notEqual(run({}, { AARAST_ANDROID_SIGNING_PROFILE: '' }).status, 0);
  assert.notEqual(run({ AARAST_DEV_BYPASS_LOGIN_GATES: 'true' }).status, 0);
});
// RA-MO-01: a production release that does not name its invite host would
// build its invite links and public pages on a guessed, old domain.
test('a production release names a public invite host', () => {
  const production = { AARAST_ENVIRONMENT: 'production',
    AARAST_STAGING_ROUTE_PROFILE: null, AARAST_FIREBASE_PROJECT_ID: 'aarast-d62e9' };
  const productionIdentity = {
    AARAST_ANDROID_APPLICATION_ID: 'com.aarast.aarast_mobile',
    AARAST_ANDROID_SIGNING_PROFILE: '',
  };
  const missing = run({ ...production, AARAST_INVITE_HOST: null }, productionIdentity);
  assert.notEqual(missing.status, 0);
  assert.match(missing.output, /Release builds require AARAST_INVITE_HOST/);
  assert.notEqual(run({ ...production, AARAST_INVITE_HOST: 'localhost' }, productionIdentity).status, 0);
  assert.notEqual(run({ ...production, AARAST_INVITE_HOST: '10.0.2.2' }, productionIdentity).status, 0);
  assert.notEqual(run({ ...production, AARAST_INVITE_HOST: 'https://x.example.org' }, productionIdentity).status, 0);
  const named = run({ ...production, AARAST_API_BASE_URL: 'https://3.121.198.183',
    AARAST_INVITE_HOST: '3-121-198-183.sslip.io' }, productionIdentity);
  assert.equal(named.status, 0, named.output);
});
test('isolated staging still accepts distinct HTTPS API/invite hosts', () => {
  const result = run({ AARAST_STAGING_ROUTE_PROFILE: 'isolated',
    AARAST_API_BASE_URL: 'https://api.test.example.org', AARAST_INVITE_HOST: 'invite.test.example.org' });
  assert.equal(result.status, 0, result.output);
});
