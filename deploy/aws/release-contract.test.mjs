import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { test } from 'node:test';

// RA-OP-25: a release is the image CI built and scanned, loaded on the host
// and checked against the content digest CI recorded; the host builds nothing.
// None of this needs Docker: the shell is syntax-checked, the loader runs
// against a fake `docker`, and the rest are checks on what the files say.
const root = resolve(import.meta.dirname, '../..');
const read = (path) => readFileSync(join(root, path), 'utf8');
const sha = 'a'.repeat(40);
const names = ['aarast-backend', 'aarast-admin-web', 'aarast-public-site', 'aarast-openwa-link'];
const idOf = (name) => `sha256:${Buffer.from(name).toString('hex').padEnd(64, '0').slice(0, 64)}`;
// The host has python3. A Windows checkout's python3 can be the Store's
// placeholder, so there the fake bin answers python3 with the real python.
const pythonShim = (bin) => {
  if (process.platform !== 'win32') return;
  // Windows python ends its lines with CRLF; the host's python3 does not.
  writeFileSync(join(bin, 'python3'), '#!/bin/bash\npython "$@" | tr -d \'\\r\'\nexit "${PIPESTATUS[0]}"\n');
  chmodSync(join(bin, 'python3'), 0o755);
};

test('every host script is valid bash', () => {
  for (const script of ['deploy', 'rollback', 'restore', 'restore-drill', 'release-lib', 'prepare-env']) {
    const run = spawnSync('bash', ['-n', join(root, `deploy/aws/host/${script}.sh`)], { encoding: 'utf8' });
    assert.equal(run.status, 0, `${script}.sh: ${run.stderr}`);
  }
});

test('deploy.sh builds nothing on the host: it loads what CI built', () => {
  const deploy = read('deploy/aws/host/deploy.sh');
  assert.doesNotMatch(deploy, /docker build /, 'the live host must not build images (RA-OP-25)');
  assert.match(deploy, /release_load_images /);
  assert.match(deploy, /aws s3 cp --recursive "s3:\/\/\$ops_bucket\/releases\/\$release\/images"/);
  // The images are loaded and verified before anything is started or backed up.
  assert.ok(deploy.indexOf('release_load_images') < deploy.indexOf('dc up -d'));
  assert.ok(deploy.indexOf('release_load_images') < deploy.indexOf('release_backup_before'));
});

/** Runs release_load_images with a fake docker that knows [ids] (tag to image id). */
function load({ ids, manifest, files = names.map((n) => `${n}.tar`) }) {
  const dir = mkdtempSync(join(tmpdir(), 'aarast-load-'));
  try {
    mkdirSync(join(dir, 'bin'));
    pythonShim(join(dir, 'bin'));
    mkdirSync(join(dir, 'images'));
    writeFileSync(join(dir, 'images', 'release-images.json'), JSON.stringify(manifest));
    for (const file of files) writeFileSync(join(dir, 'images', file), 'tar');
    writeFileSync(join(dir, 'ids.json'), JSON.stringify(ids));
    writeFileSync(join(dir, 'bin', 'docker'), `#!/bin/bash
echo "docker $*" >>"${dir}/calls"
case "$1 $2" in
  "load -i") exit 0 ;;
  "image inspect")
    ref=\${@: -1}
    python3 -c 'import json,sys; ids=json.load(open(sys.argv[1])); print(ids[sys.argv[2]])' "${dir}/ids.json" "$ref" ;;
  "image rm") exit 0 ;;
esac
`);
    chmodSync(join(dir, 'bin', 'docker'), 0o755);
    const run = spawnSync('bash', ['-c', `. "${join(root, 'deploy/aws/host/release-lib.sh')}"; release_load_images "${join(dir, 'images')}" ${sha}`], {
      encoding: 'utf8', env: { ...process.env, PATH: `${join(dir, 'bin')}:${process.env.PATH}` },
    });
    let calls = '';
    try { calls = readFileSync(join(dir, 'calls'), 'utf8'); } catch { /* none */ }
    return { status: run.status, output: run.stdout + run.stderr, calls };
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
const manifest = (change = {}) => ({
  release: sha,
  images: names.map((name) => ({ name, file: `${name}.tar`, id: idOf(name) })),
  ...change,
});
const good = () => Object.fromEntries(names.map((name) => [`${name}:${sha}`, idOf(name)]));

test('RA-OP-25: the images load when each is the one CI recorded', () => {
  const run = load({ ids: good(), manifest: manifest() });
  assert.equal(run.status, 0, run.output);
  for (const name of names) assert.match(run.calls, new RegExp(`docker load -i .*${name}\\.tar`));
});

test('RA-OP-25: an image that is not the one CI recorded is removed and the release stops', () => {
  const ids = { ...good(), [`aarast-backend:${sha}`]: `sha256:${'f'.repeat(64)}` };
  const run = load({ ids, manifest: manifest() });
  assert.notEqual(run.status, 0);
  assert.match(run.output, /aarast-backend.*is not the image CI built/);
  assert.match(run.calls, new RegExp(`docker image rm aarast-backend:${sha}`));
});

test('RA-OP-25: a manifest of another release, a missing image or a missing file stops it', () => {
  const stops = (run, reason) => {
    assert.notEqual(run.status, 0);
    assert.match(run.output, reason);
  };
  stops(load({ ids: good(), manifest: manifest({ release: 'b'.repeat(40) }) }), /manifest is for release b+, not a+/);
  const short = manifest();
  short.images.pop();
  stops(load({ ids: good(), manifest: short }), /aarast-openwa-link is missing from the manifest/);
  stops(load({ ids: good(), manifest: manifest(), files: ['aarast-backend.tar'] }), /file of aarast-admin-web is missing/);
  const pathy = manifest();
  pathy.images[0].file = '../../etc/passwd';
  stops(load({ ids: good(), manifest: pathy }), /file of aarast-backend is not a file name/);
  const undigested = manifest();
  undigested.images[1].id = 'latest';
  stops(load({ ids: good(), manifest: undigested }), /aarast-admin-web has no content digest/);
});

test('the release workflow builds the four images once, gates and records their digests', () => {
  const workflow = read('.github/workflows/release-images.yml');
  assert.match(workflow, /^on:\s*\n\s+workflow_dispatch:/m, 'run by the owner, never on a push (a red main is a fix)');
  assert.match(workflow, /github\.ref == 'refs\/heads\/main'/);
  assert.match(workflow, /--workflow ci\.yml --commit "\$GITHUB_SHA" --status success/, 'only a commit CI passed');
  for (const name of names) assert.match(workflow, new RegExp(`docker build[^\\n]*${name}:\\$\\{GITHUB_SHA\\}`));
  assert.match(workflow, /VITE_API_BASE_URL="\$AARAST_AWS_API_BASE_URL"/);
  assert.match(workflow, /AARAST_AWS_API_BASE_URL: \$\{\{ vars\.AARAST_AWS_API_BASE_URL \}\}/);
  assert.doesNotMatch(workflow, /run:[^\n]*\$\{\{ vars\./, 'repository variables reach the shell as environment, not as text');
  assert.match(workflow, /case "\$AARAST_AWS_API_BASE_URL" in https:\/\/\*\)/, 'no admin image with an empty API address');
  assert.match(workflow, /--severity HIGH,CRITICAL/);
  assert.match(workflow, /render-contact\.mjs check/, 'the contact placeholders fail the release (RA-OP-21)');
  assert.match(workflow, /docker save/);
  assert.match(workflow, /\.Id/);
  assert.match(workflow, /name: release-images-\$\{\{ github\.sha \}\}/);
  assert.match(workflow, /--build-arg AARAST_SUPPORT_EMAIL="\$AARAST_SUPPORT_EMAIL"/);
  assert.match(workflow, /AARAST_SUPPORT_EMAIL: \$\{\{ vars\.AARAST_SUPPORT_EMAIL \}\}/);
  assert.doesNotMatch(workflow, /secrets\./, 'no secret reaches the image builds');
  assert.doesNotMatch(workflow, /uses: [^@\n]+@(?![0-9a-f]{40}\b)/, 'actions are pinned by commit');
});

test('release.ps1 ships the CI run it is given and never the source to build from', () => {
  const release = read('deploy/aws/release.ps1');
  assert.match(release, /\[Parameter\(Mandatory\)\]\[string\]\$Run/);
  assert.match(release, /gh run view \$Run/);
  assert.match(release, /Release images/);
  assert.match(release, /gh run download \$Run/);
  assert.doesNotMatch(release, /archive[^\n]*\bbackend\b/, 'the host receives deploy/ only');
  assert.match(release, /archive[^\n]* deploy\s*$/m);
  assert.match(release, /releases\/\$sha\/images/);
  assert.doesNotMatch(release, /building on the host/);
  const live = read('deploy/aws/go-live.ps1');
  assert.match(live, /\[string\]\$Run/);
  assert.match(live, /release\.ps1'\) -Run \$Run/);
});

/**
 * Runs release_push_env against a fake `aws` that prints [key] (or fails
 * when it is null) and a fake `chown`, on a temporary env file and
 * Firebase folder; [env] adds to the shell's environment.
 */
function pushEnv({ key, envFile = 'AWS_REGION=eu-central-1\n', env = {} }) {
  const dir = mkdtempSync(join(tmpdir(), 'aarast-push-'));
  try {
    mkdirSync(join(dir, 'bin'));
    pythonShim(join(dir, 'bin'));
    writeFileSync(join(dir, '.env'), envFile);
    if (key !== null) writeFileSync(join(dir, 'key.json'), JSON.stringify(key));
    writeFileSync(join(dir, 'bin', 'aws'), key === null
      ? '#!/bin/bash\necho "ParameterNotFound" >&2\nexit 254\n'
      : `#!/bin/bash\ncat "${join(dir, 'key.json').replace(/\\/g, '/')}"\n`);
    writeFileSync(join(dir, 'bin', 'chown'), '#!/bin/bash\nexit 0\n');
    chmodSync(join(dir, 'bin', 'aws'), 0o755);
    chmodSync(join(dir, 'bin', 'chown'), 0o755);
    const lib = join(root, 'deploy/aws/host/release-lib.sh');
    const run = spawnSync('bash', ['-c', `set -euo pipefail
. "${lib}"
env_file="${join(dir, '.env').replace(/\\/g, '/')}"
firebase_dir="${join(dir, 'firebase').replace(/\\/g, '/')}"
release_push_env
echo "PUSH=$PUSH_NOTIFICATIONS_ENABLED PROJECT=\${FIREBASE_PROJECT_ID:-}"`], {
      encoding: 'utf8',
      env: { ...process.env, ...env, PATH: `${join(dir, 'bin')}${process.platform === 'win32' ? ';' : ':'}${process.env.PATH}` },
    });
    return { status: run.status, output: run.stdout + run.stderr };
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

test('a release with no FCM key in SSM stops instead of starting with push silently off', () => {
  const run = pushEnv({ key: null });
  assert.notEqual(run.status, 0, run.output);
  assert.match(run.output, /FAIL: no FCM key could be read from SSM \/aarast\/firebase-service-account/);
  assert.match(run.output, /AARAST_ALLOW_PUSH_DISABLED=1/);
  assert.doesNotMatch(run.output, /PUSH=/, 'nothing after the refusal runs');
});

test('starting without push takes an explicit opt-out, from the environment or the host env file', () => {
  for (const run of [
    pushEnv({ key: null, env: { AARAST_ALLOW_PUSH_DISABLED: '1' } }),
    pushEnv({ key: null, envFile: 'AWS_REGION=eu-central-1\nAARAST_ALLOW_PUSH_DISABLED=1\n' }),
  ]) {
    assert.equal(run.status, 0, run.output);
    assert.match(run.output, /push notifications disabled on purpose/);
    assert.match(run.output, /PUSH=false/);
  }
  // Anything but 1 is no opt-out.
  assert.notEqual(pushEnv({ key: null, env: { AARAST_ALLOW_PUSH_DISABLED: 'yes' } }).status, 0);
});

test('a key in SSM turns push on for its project, and a key of another project than the expected one stops', () => {
  const key = { type: 'service_account', project_id: 'aarast-prod' };
  const on = pushEnv({ key });
  assert.equal(on.status, 0, on.output);
  assert.match(on.output, /PUSH=true PROJECT=aarast-prod/);
  const pinned = pushEnv({ key, envFile: 'AWS_REGION=eu-central-1\nFIREBASE_EXPECTED_PROJECT_ID=aarast-prod\n' });
  assert.equal(pinned.status, 0, pinned.output);
  const other = pushEnv({ key: { ...key, project_id: 'aarast-staging-qa' }, envFile: 'AWS_REGION=eu-central-1\nFIREBASE_EXPECTED_PROJECT_ID=aarast-prod\n' });
  assert.notEqual(other.status, 0, other.output);
  assert.match(other.output, /FCM key in SSM is for Firebase project aarast-staging-qa, not aarast-prod/);
  // The secret itself is never printed.
  assert.doesNotMatch(on.output + other.output, /service_account/);
});

test('the backend gets the expected Firebase project from the host env file', () => {
  const compose = read('deploy/aws/compose.yml');
  assert.match(compose, /FIREBASE_EXPECTED_PROJECT_ID: \$\{FIREBASE_EXPECTED_PROJECT_ID:-\}/);
});

test('the AWS PowerShell scripts parse', () => {
  const probe = spawnSync('pwsh', ['-NoProfile', '-Command', '$PSVersionTable.PSVersion.Major'], { encoding: 'utf8' });
  if (probe.error) return; // no pwsh on this machine
  for (const script of ['release', 'go-live', 'rollback', 'restore']) {
    const run = spawnSync('pwsh', ['-NoProfile', '-Command',
      `$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile('${join(root, `deploy/aws/${script}.ps1`)}',[ref]$null,[ref]$e);if($e){$e|%{$_.Message};exit 1}`],
    { encoding: 'utf8' });
    assert.equal(run.status, 0, `${script}.ps1: ${run.stdout}${run.stderr}`);
  }
});
