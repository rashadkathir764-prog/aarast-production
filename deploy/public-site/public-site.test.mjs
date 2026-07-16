import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(fileURLToPath(import.meta.url));
const read = (name) => readFileSync(join(root, name), "utf8");

const dockerfile = read("Dockerfile");
const dockerignore = read(".dockerignore");
const nginx = read("nginx.conf");
const inviteHtml = read("invite.html");
const inviteJs = read("invite.js");

assert.match(
  dockerfile,
  /^FROM nginx:1\.31\.3-alpine@sha256:[a-f0-9]{64}$/m,
  "The Nginx base image must be immutable.",
);
assert.doesNotMatch(dockerfile, /\bCOPY\s+\.\s+/i, "COPY . is forbidden.");
assert.match(dockerfile, /^HEALTHCHECK /m, "The image must expose a runtime health check.");

for (const asset of [
  "invite.html",
  "invite.js",
  "invite.css",
  "invite-preview.png",
]) {
  const escaped = asset.replaceAll(".", "\\.");
  assert.match(dockerfile, new RegExp(escaped), `${asset} must be copied explicitly.`);
  assert.match(dockerignore, new RegExp(`^!${escaped}$`, "m"), `${asset} must be allowlisted.`);
}

assert.match(nginx, /location \^~ \/invites\//);
assert.match(nginx, /location = \/healthz/);
assert.match(nginx, /location = \/invite\.css/);
assert.match(nginx, /location = \/invite\.js/);
assert.match(nginx, /location \/\s*\{\s*return 404;/);
assert.match(nginx, /access_log off;/);
assert.match(nginx, /Cache-Control "no-store"/);
assert.match(nginx, /X-Robots-Tag "noindex, nofollow, noarchive"/);
assert.match(nginx, /try_files \/invite\.html =404;/);
assert.match(nginx, /location ~ \/\\\.\(\?!well-known/);
assert.match(nginx, /Dockerfile\|docker-compose/);
assert.match(
  nginx,
  /location = \/\.well-known\/assetlinks\.json\s*\{\s*return 404;/,
);
assert.match(
  nginx,
  /location = \/\.well-known\/apple-app-site-association\s*\{\s*return 404;/,
);
assert.match(nginx, /invite-preview\.png[\s\S]*?max-age=86400/);
assert.doesNotMatch(nginx, /invite-preview\.png[\s\S]*?immutable/);

assert.match(inviteHtml, /<html lang="ar" dir="rtl">/);
assert.match(inviteHtml, /noindex,nofollow,noarchive/);
assert.match(inviteHtml, /property="og:image"/);
assert.match(inviteHtml, /id="open-invite"/);
assert.doesNotMatch(
  inviteHtml,
  /<script(?![^>]*\bsrc=)[^>]*>[\s\S]*<\/script>/i,
  "Inline scripts are forbidden by CSP.",
);

assert.match(inviteJs, /segments\.length === 2 && segments\[0\] === "invites"/);
assert.match(inviteJs, /\^\[A-Za-z0-9_-\]\{43\}\$/);
assert.match(inviteJs, /aarast:\/\/open\/invites\/\$\{encodeURIComponent\(token\)\}/);
for (const forbidden of [
  "localStorage",
  "sessionStorage",
  "document.cookie",
  "console.",
]) {
  assert.doesNotMatch(inviteJs, new RegExp(forbidden.replace(".", "\\.")));
}

process.stdout.write("public-site source checks: PASS\n");
