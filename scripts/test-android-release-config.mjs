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
  source.slice(start, end) +
  '\nvalidateReleaseDartDefines(project.findProperty("store-bundle") == "true")\n');

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

test('release env syntax failures identify the line without exposing its contents', () => {
  for (const malformed of ['not-a-real-secret--release-log-sentinel', '=not-a-real-secret--release-log-sentinel']) {
    const fixture = fs.mkdtempSync(path.join(scratch, 'private-env-'));
    fs.mkdirSync(path.join(fixture, 'scripts'));
    fs.mkdirSync(path.join(fixture, 'mobile', 'android'), { recursive: true });
    const script = path.join(fixture, 'scripts', 'build-android-release.ps1');
    fs.copyFileSync(path.join(root, 'scripts', 'build-android-release.ps1'), script);
    fs.writeFileSync(path.join(fixture, 'mobile', 'android', '.env.release'),
      `# private release configuration\n\n${malformed}\n`);
    const shell = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
    const result = spawnSync(shell, ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script], {
      encoding: 'utf8', timeout: 30000, maxBuffer: 1024 * 1024,
    });
    assert.ifError(result.error);
    const output = result.stdout + result.stderr;
    assert.notEqual(result.status, 0, 'Malformed release configuration must stop before a build.');
    assert.match(output, /Not KEY=VALUE/, 'The real release parser must reject the malformed input.');
    assert.doesNotMatch(output, /not-a-real-secret--release-log-sentinel/,
      'A malformed private configuration line must never be echoed into logs.');
    assert.match(output, /\.env\.release at line 3/, 'The operator still needs the physical line number.');
  }
});

function run(overrides = {}, env = {}, { store = false } = {}) {
  const values = { ...defines, ...overrides };
  const encoded = Object.entries(values).filter(([, v]) => v !== null)
    .map(([k, v]) => Buffer.from(`${k}=${v}`).toString('base64')).join(',');
  const result = spawnSync(java, ['-jar', gradle, '--offline', '-p', scratch,
    '--console=plain', '--max-workers=2', 'help', `-Pdart-defines=${encoded}`,
    `-Pstore-bundle=${store}`], {
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
    AARAST_PUBLIC_ORIGIN: 'https://aarast.shadowgardn.com',
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
    AARAST_PUBLIC_ORIGIN: 'https://aarast.shadowgardn.com',
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
    AARAST_PUBLIC_ORIGIN: 'https://3-121-198-183.sslip.io',
    AARAST_INVITE_HOST: '3-121-198-183.sslip.io' }, productionIdentity);
  assert.equal(named.status, 0, named.output);
});
test('isolated staging still accepts distinct HTTPS API/invite hosts', () => {
  const result = run({ AARAST_STAGING_ROUTE_PROFILE: 'isolated',
    AARAST_API_BASE_URL: 'https://api.test.example.org', AARAST_INVITE_HOST: 'invite.test.example.org' });
  assert.equal(result.status, 0, result.output);
});

// RA-OP-30: the server writes every link on its INVITE_PUBLIC_ORIGIN (the
// Elastic IP until the domain exists), and the app only opens links on its
// AARAST_INVITE_HOST. A release whose host is not the origin's host builds an
// App Link filter that no link the server writes ever matches (the last host
// that verified was an sslip.io name, the links were on the IP).
const productionBuild = { AARAST_ENVIRONMENT: 'production', AARAST_STAGING_ROUTE_PROFILE: null,
  AARAST_FIREBASE_PROJECT_ID: 'aarast-d62e9', AARAST_PUBLIC_ORIGIN: 'https://aarast.shadowgardn.com' };
const productionApp = { AARAST_ANDROID_APPLICATION_ID: 'com.aarast.aarast_mobile',
  AARAST_ANDROID_SIGNING_PROFILE: '' };
test('RA-OP-30: a production release names the server public origin', () => {
  const missing = run({ ...productionBuild, AARAST_PUBLIC_ORIGIN: null }, productionApp);
  assert.notEqual(missing.status, 0);
  assert.match(missing.output, /Release builds require AARAST_PUBLIC_ORIGIN/);
});
test('RA-OP-30: the invite host must be the host of the public origin', () => {
  const ipOrigin = run({ ...productionBuild, AARAST_PUBLIC_ORIGIN: 'https://3.121.198.183',
    AARAST_INVITE_HOST: '3-121-198-183.sslip.io' }, productionApp);
  assert.notEqual(ipOrigin.status, 0, 'links on the IP never open an app that listens on the sslip.io name');
  assert.match(ipOrigin.output, /AARAST_INVITE_HOST must be the host of AARAST_PUBLIC_ORIGIN/);
  const sameHost = run({ ...productionBuild, AARAST_PUBLIC_ORIGIN: 'https://3.121.198.183',
    AARAST_INVITE_HOST: '3.121.198.183' }, productionApp);
  assert.equal(sameHost.status, 0, sameHost.output);
  const otherCase = run({ ...productionBuild, AARAST_PUBLIC_ORIGIN: 'https://Aarast.ShadowGardn.com' }, productionApp);
  assert.equal(otherCase.status, 0, otherCase.output);
});
test('RA-OP-30: the public origin is a bare public HTTPS origin', () => {
  for (const origin of ['http://aarast.shadowgardn.com', 'https://aarast.shadowgardn.com/invites',
    'https://aarast.shadowgardn.com:8443', 'https://user@aarast.shadowgardn.com',
    'https://aarast.shadowgardn.com?x=1', 'aarast.shadowgardn.com', 'https://localhost']) {
    assert.notEqual(run({ ...productionBuild, AARAST_PUBLIC_ORIGIN: origin }, productionApp).status, 0, origin);
  }
});

// RA-ST-09: a store bundle that was built without the support number left the
// WhatsApp support card out of the shipped app, and nothing said so. The
// number is the owner's; while it is a placeholder the store build fails.
const storeBuild = { ...productionBuild, AARAST_SENTRY_DSN: 'https://public@sentry.example.org/1',
  AARAST_SENTRY_TRACES_SAMPLE_RATE: '0.1', SENTRY_RELEASE: 'aarast-mobile@1.0.0+1-abc1234',
  AARAST_SUPPORT_WHATSAPP: '+96770000000' };
const storeEnv = { ...productionApp, SENTRY_AUTH_TOKEN: 'test-only', SENTRY_ORG: 'test-only',
  SENTRY_PROJECT: 'test-only' };
test('RA-ST-09: a store bundle needs a real AARAST_SUPPORT_WHATSAPP', () => {
  const ok = run(storeBuild, storeEnv, { store: true });
  assert.equal(ok.status, 0, ok.output);
  const missing = run({ ...storeBuild, AARAST_SUPPORT_WHATSAPP: null }, storeEnv, { store: true });
  assert.notEqual(missing.status, 0);
  assert.match(missing.output, /Store app bundles require AARAST_SUPPORT_WHATSAPP/);
  for (const placeholder of ['', '+967XXXXXXXXX', '+967777000111', '0770000000', '+967 77 000 0000', 'REPLACE_ME']) {
    assert.notEqual(run({ ...storeBuild, AARAST_SUPPORT_WHATSAPP: placeholder }, storeEnv, { store: true }).status,
      0, `"${placeholder}" is not a number the team answers`);
  }
});
test('RA-ST-09: the number is only required for a store bundle, not for a local release APK', () => {
  const apk = run({ ...storeBuild, AARAST_SUPPORT_WHATSAPP: null }, storeEnv);
  assert.equal(apk.status, 0, apk.output);
});
