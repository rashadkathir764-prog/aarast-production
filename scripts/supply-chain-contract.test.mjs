import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const workflow = await readFile(
  new URL("../.github/workflows/ci.yml", import.meta.url),
  "utf8",
);
const productionCompose = await readFile(
  new URL("../deploy/dokploy/docker-compose.yml", import.meta.url),
  "utf8",
);
const monitoringCompose = await readFile(
  new URL("../deploy/monitoring/docker-compose.yml", import.meta.url),
  "utf8",
);

test("every GitHub Action is pinned to a full commit SHA", () => {
  const actionRefs = [...workflow.matchAll(/^\s*-\s+uses:\s+([^#\s]+)/gm)].map(
    ([, ref]) => ref,
  );

  assert.ok(actionRefs.length > 0, "no GitHub Actions were found");
  for (const ref of actionRefs) {
    assert.match(
      ref,
      /@[0-9a-f]{40}$/,
      `mutable or malformed GitHub Action reference: ${ref}`,
    );
  }
});

test("candidate images produce revision-bound SBOMs and reject severe findings", () => {
  assert.match(workflow, /sbom\/backend-\$\{GITHUB_SHA\}\.cdx\.json/);
  assert.match(workflow, /sbom\/admin-web-\$\{GITHUB_SHA\}\.cdx\.json/);
  assert.match(workflow, /--exit-code 1 --severity HIGH,CRITICAL/);
  assert.match(
    workflow,
    /aquasec\/trivy:0\.70\.0@sha256:[0-9a-f]{64}/,
    "the scanner image itself must be digest-pinned",
  );
  assert.match(workflow, /name: sbom-\$\{\{ github\.sha \}\}/);
});

test("production infrastructure images are pinned to repository digests", () => {
  const imageRefs = [
    ...productionCompose.matchAll(/^\s+image:\s+(.+)$/gm),
    ...monitoringCompose.matchAll(/^\s+image:\s+(.+)$/gm),
  ].map(([, ref]) => ref.trim());

  assert.ok(imageRefs.length > 0, "no production images were found");
  for (const ref of imageRefs) {
    if (ref.includes("${AARAST_")) {
      assert.match(
        ref,
        /IMAGE_ID/,
        `application image is not an immutable image ID: ${ref}`,
      );
      continue;
    }
    assert.match(
      ref,
      /@sha256:[0-9a-f]{64}$/,
      `infrastructure image is not digest-pinned: ${ref}`,
    );
  }
});

// RA-TS-20: CI must run what the gates run, not a subset of it.
function jobBlock(name) {
  const match = new RegExp(`^  ${name}:\\n((?:(?:    .*)?\\n)+)`, "m").exec(workflow);
  assert.ok(match, `ci.yml has no job named ${name}`);
  return match[1];
}

test("CI runs every deploy and supply-chain contract the gate lists", () => {
  const job = jobBlock("deploy-contracts");
  assert.match(job, /runs-on: ubuntu-latest/);
  assert.match(job, /node --test .*deploy\/\*\*\/\*\.test\.mjs/);
  assert.match(job, /scripts\/check-deploy-encoding\.test\.mjs/);
  assert.match(job, /scripts\/supply-chain-contract\.test\.mjs/);
});

test("CI runs the Android release guard without building or signing", () => {
  const job = jobBlock("android-release-guard");
  assert.match(job, /scripts\/test-android-release-config\.mjs/);
  assert.match(job, /GRADLE_HOME/);
  assert.doesNotMatch(job, /appbundle|assembleRelease|bundleRelease|keystore/i);
});

test("CI runs the mobile tests in UTC, Asia/Aden and America/Los_Angeles", () => {
  const job = jobBlock("mobile");
  for (const zone of ["UTC", "Asia/Aden", "America/Los_Angeles"]) {
    assert.ok(job.includes(`- ${zone}`), `mobile job lacks TZ ${zone}`);
  }
  assert.match(job, /TZ: \$\{\{ matrix\.tz \}\}/);
  assert.match(job, /flutter test --exclude-tags golden/);
});
