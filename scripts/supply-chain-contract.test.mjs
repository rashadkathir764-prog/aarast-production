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
