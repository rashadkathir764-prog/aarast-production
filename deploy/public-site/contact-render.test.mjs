import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync, cpSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { findPlaceholders, renderContact, validateContact } from "./render-contact.mjs";

// RA-OP-21: the support, terms and privacy pages carry the owner's contact
// details and legal entity as placeholders. None of them is in the repository;
// the image build writes them in, and the release check fails while any token
// is still on a served page.
const root = dirname(fileURLToPath(import.meta.url));
const read = (name) => readFileSync(join(root, name), "utf8");
const pages = ["support.html", "terms.html", "privacy.html"];
// Placeholders that look valid but are fixtures of this test only.
const values = {
  AARAST_LEGAL_ENTITY: "Test Entity Ltd",
  AARAST_SUPPORT_EMAIL: "help@aarast-test.invalid-fixture.org",
  AARAST_SUPPORT_WHATSAPP: "+10000000001",
  AARAST_GOVERNING_LAW: "Test Law",
};

test("the pages name the entity, the contact and the law only as tokens", () => {
  const all = pages.map(read).join("\n");
  for (const token of Object.keys(values)) assert.ok(all.includes(`{{${token}}}`), token);
  assert.ok(all.includes("{{AARAST_SUPPORT_WHATSAPP_DIGITS}}"));
  // No real address, number or entity is in the repository.
  assert.doesNotMatch(all, /mailto:[^{"]*@/);
  assert.doesNotMatch(all, /wa\.me\/\d/);
  assert.doesNotMatch(all, /\+\d{8,}/);
  for (const page of pages) {
    assert.match(read(page), /\{\{AARAST_LEGAL_ENTITY\}\}/, `${page} names who runs the service`);
  }
});

test("the support page is a way to ask for deletion and to reach the team outside the app", () => {
  const html = read("support.html");
  assert.match(html, /href="https:\/\/wa\.me\/\{\{AARAST_SUPPORT_WHATSAPP_DIGITS\}\}\?text=[^"]+"/);
  assert.match(html, /href="mailto:\{\{AARAST_SUPPORT_EMAIL\}\}\?subject=[^"]+&amp;body=[^"]+"/);
  assert.match(html, /طلب حذف الحساب بدون التطبيق/);
  assert.match(html, /رقم الجوال المسجّل/);
  assert.match(html, /30 يومًا/);
  assert.doesNotMatch(html, /<form|<script/i, "the site's CSP allows neither");
});

test("the terms name a governing law and the privacy page says where the data is kept", () => {
  assert.match(read("terms.html"), /\{\{AARAST_GOVERNING_LAW\}\}/);
  assert.match(read("privacy.html"), /فرانكفورت/);
});

test("rendering writes the values, escaped, and leaves nothing behind", () => {
  const rendered = pages.map((page) => renderContact(read(page), values));
  const support = rendered[0];
  assert.match(support, /href="https:\/\/wa\.me\/10000000001\?text=/);
  assert.match(support, /href="mailto:help@aarast-test\.invalid-fixture\.org\?subject=/);
  assert.match(support, /Test Entity Ltd/);
  for (const html of rendered) assert.deepEqual(findPlaceholders(html), []);
  assert.equal(
    renderContact("<p>{{AARAST_LEGAL_ENTITY}}</p>", { AARAST_LEGAL_ENTITY: 'A <b>&"Co' }),
    "<p>A &lt;b&gt;&amp;&quot;Co</p>",
  );
});

test("a token with no value stays, and is what the release check reports", () => {
  const partial = renderContact(read("support.html"), { AARAST_SUPPORT_EMAIL: values.AARAST_SUPPORT_EMAIL });
  assert.deepEqual(findPlaceholders(partial).sort(), [
    "AARAST_LEGAL_ENTITY",
    "AARAST_SUPPORT_WHATSAPP",
    "AARAST_SUPPORT_WHATSAPP_DIGITS",
  ]);
});

test("values that are placeholders, examples or another company's are refused", () => {
  assert.deepEqual(validateContact(values), []);
  const bad = (change) => validateContact({ ...values, ...change });
  assert.match(bad({ AARAST_SUPPORT_EMAIL: "info@aarast.app" })[0], /aarast\.app/, "RA-ST-01");
  assert.ok(bad({ AARAST_SUPPORT_EMAIL: "someone@example.com" }).length);
  assert.ok(bad({ AARAST_SUPPORT_EMAIL: "not-an-address" }).length);
  assert.ok(bad({ AARAST_SUPPORT_WHATSAPP: "+967777000111" }).length, "the documentation's old example");
  assert.ok(bad({ AARAST_SUPPORT_WHATSAPP: "+967XXXXXXXXX" }).length);
  assert.ok(bad({ AARAST_SUPPORT_WHATSAPP: "0777000111" }).length);
  assert.ok(bad({ AARAST_LEGAL_ENTITY: "<script>" }).length);
  assert.ok(bad({ AARAST_LEGAL_ENTITY: "TODO" }).length);
  assert.ok(bad({ AARAST_GOVERNING_LAW: "{{AARAST_GOVERNING_LAW}}" }).length, "a token is not a value");
});

function cli(args, env = {}) {
  const run = spawnSync(process.execPath, [join(root, "render-contact.mjs"), ...args], {
    encoding: "utf8",
    env: { PATH: process.env.PATH, ...env },
  });
  return { status: run.status, output: run.stdout + run.stderr };
}

test("the command renders the pages, and the release check fails until every value is set", () => {
  const work = mkdtempSync(join(tmpdir(), "aarast-contact-"));
  try {
    const source = join(work, "src");
    const out = join(work, "out");
    const partialOut = join(work, "partial");
    cpSync(root, source, { recursive: true });
    // Without any value: the pages are written with their tokens, and the check fails.
    const none = cli(["render", source, partialOut]);
    assert.equal(none.status, 0, none.output);
    const noneCheck = cli(["check", partialOut]);
    assert.notEqual(noneCheck.status, 0);
    assert.match(noneCheck.output, /AARAST_SUPPORT_EMAIL/);
    assert.match(noneCheck.output, /AARAST_LEGAL_ENTITY/);

    // A bad value stops the build instead of publishing it.
    const badBuild = cli(["render", source, out], { ...values, AARAST_SUPPORT_EMAIL: "info@aarast.app" });
    assert.notEqual(badBuild.status, 0);
    assert.match(badBuild.output, /aarast\.app/);

    const good = cli(["render", source, out], values);
    assert.equal(good.status, 0, good.output);
    const check = cli(["check", out]);
    assert.equal(check.status, 0, check.output);
    assert.deepEqual(readdirSync(out).sort(), [...pages].sort());
    assert.match(readFileSync(join(out, "support.html"), "utf8"), /Test Entity Ltd/);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});

test("the production image renders the pages and ships none of the tokens' sources", () => {
  const dockerfile = read("Dockerfile");
  assert.match(dockerfile, /^FROM node:22-alpine@sha256:[a-f0-9]{64} AS contact$/m);
  for (const name of Object.keys(values)) assert.match(dockerfile, new RegExp(`^ARG ${name}$`, "m"), name);
  assert.match(dockerfile, /RUN node render-contact\.mjs render \/site \/out/);
  assert.match(dockerfile, /COPY --from=contact \/out\/privacy\.html \/out\/terms\.html \/out\/support\.html \/usr\/share\/nginx\/html\//);
  assert.doesNotMatch(dockerfile, /^COPY (?!--from)[^\n]*\b(?:privacy|terms|support)\.html [^\n]*\/usr\/share\/nginx\/html\/$/m,
    "the pages come from the render stage, not straight from the source");
  assert.match(read(".dockerignore"), /^!render-contact\.mjs$/m);
  assert.doesNotMatch(dockerfile, /render-contact\.mjs[^\n]*\/usr\/share\/nginx/);
});
