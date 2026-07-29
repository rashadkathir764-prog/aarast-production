import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";

const fixtureDirectory = mkdtempSync(join(tmpdir(), "aarast-firebase-"));
const credentialPath = join(fixtureDirectory, "service-account.json");
const privateKeyMarker = "fake-private-key-material";
const credential = {
  type: "service_account",
  project_id: "aarast-project",
  private_key_id: "fake-key-id",
  private_key: [
    "-----BEGIN PRIVATE KEY-----",
    privateKeyMarker,
    "-----END PRIVATE KEY-----",
  ].join("\n"),
  client_email: "firebase-adminsdk@example.iam.gserviceaccount.com",
  token_uri: "https://oauth2.googleapis.com/token",
};

writeFileSync(credentialPath, JSON.stringify(credential), {
  encoding: "utf8",
  mode: 0o600,
});
chmodSync(credentialPath, 0o600);

after(() => {
  rmSync(fixtureDirectory, { recursive: true, force: true });
});

function runCredentialCheck(environment: NodeJS.ProcessEnv) {
  return spawnSync(
    process.execPath,
    [
      join(
        process.cwd(),
        "scripts",
        "prod",
        "assert-firebase-credentials.cjs",
      ),
    ],
    {
      cwd: process.cwd(),
      encoding: "utf8",
      env: environment,
      windowsHide: true,
    },
  );
}

test("Firebase credential gate skips cleanly while push is disabled", () => {
  const result = runCredentialCheck({
    ...process.env,
    PUSH_NOTIFICATIONS_ENABLED: "false",
  });

  assert.equal(result.status, 0);
  assert.match(result.stdout, /skipped \(push disabled\)/);
});

test("Firebase credential gate fails closed when enabled without a file", () => {
  const result = runCredentialCheck({
    ...process.env,
    PUSH_NOTIFICATIONS_ENABLED: "true",
    FIREBASE_PROJECT_ID: "aarast-project",
    GOOGLE_APPLICATION_CREDENTIALS: join(
      fixtureDirectory,
      "missing-service-account.json",
    ),
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /credential file is missing or invalid/);
});

test("Firebase credential gate accepts only the configured project without leaking secrets", () => {
  const accepted = runCredentialCheck({
    ...process.env,
    PUSH_NOTIFICATIONS_ENABLED: "true",
    FIREBASE_PROJECT_ID: "aarast-project",
    GOOGLE_APPLICATION_CREDENTIALS: credentialPath,
  });
  assert.equal(accepted.status, 0);
  assert.match(accepted.stdout, /Firebase credential check passed/);

  const rejected = runCredentialCheck({
    ...process.env,
    PUSH_NOTIFICATIONS_ENABLED: "true",
    FIREBASE_PROJECT_ID: "another-project",
    GOOGLE_APPLICATION_CREDENTIALS: credentialPath,
  });
  assert.equal(rejected.status, 1);
  assert.match(rejected.stderr, /does not match the configured Firebase project/);
  assert.doesNotMatch(
    `${accepted.stdout}${accepted.stderr}${rejected.stdout}${rejected.stderr}`,
    new RegExp(privateKeyMarker),
  );
});

test("Dokploy mounts the credential read-only and runs the gate before Backend boot", () => {
  const dockerfile = readFileSync(join(process.cwd(), "Dockerfile"), "utf8");
  const compose = readFileSync(
    join(process.cwd(), "..", "deploy", "dokploy", "docker-compose.yml"),
    "utf8",
  );
  const environmentExample = readFileSync(
    join(process.cwd(), "..", "deploy", "dokploy", ".env.example"),
    "utf8",
  );

  assert.equal(
    dockerfile.match(
      /COPY(?: --from=build)? .*assert-firebase-credentials\.cjs .*assert-firebase-credentials\.cjs/g,
    )?.length,
    2,
  );
  assert.match(
    compose,
    /PUSH_NOTIFICATIONS_ENABLED: \$\{PUSH_NOTIFICATIONS_ENABLED:-false\}/,
  );
  assert.match(
    compose,
    /AARAST_FIREBASE_CREDENTIAL_DIR:-aarast_firebase_credential.*:\/run\/aarast-firebase:ro/,
  );
  assert.match(
    compose,
    /node scripts\/prod\/assert-firebase-credentials\.cjs\s+node scripts\/prod\/assert-database-identity\.cjs/,
  );
  assert.match(environmentExample, /^PUSH_NOTIFICATIONS_ENABLED=false$/m);
  assert.match(environmentExample, /^FIREBASE_PROJECT_ID=$/m);
  assert.match(
    environmentExample,
    /^AARAST_FIREBASE_CREDENTIAL_DIR=\/var\/lib\/aarast\/firebase$/m,
  );
});
