import assert from "node:assert/strict";
import { createHash } from "node:crypto";
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
const privacyHtml = read("privacy.html");
const supportHtml = read("support.html");
const termsHtml = read("terms.html");
const publicCss = read("public.css");
const assetLinks = JSON.parse(read("assetlinks.json"));
const rsvpHtml = read("rsvp.html");
const rsvpJs = read("rsvp.js");

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
  "privacy.html",
  "terms.html",
  "support.html",
  "public.css",
  "assetlinks.json",
  "rsvp.html",
  "rsvp.js",
  "rsvp.css",
]) {
  const escaped = asset.replaceAll(".", "\\.");
  assert.match(dockerfile, new RegExp(escaped), `${asset} must be copied explicitly.`);
  assert.match(dockerignore, new RegExp(`^!${escaped}$`, "m"), `${asset} must be allowlisted.`);
}

assert.match(nginx, /location \^~ \/invites\//);
assert.match(nginx, /location = \/healthz/);
assert.match(nginx, /location = \/invite\.css/);
assert.match(nginx, /location = \/invite\.js/);
assert.match(nginx, /location = \/privacy/);
assert.match(nginx, /location = \/support/);
assert.match(nginx, /try_files \/privacy\.html =404;/);
assert.match(nginx, /try_files \/support\.html =404;/);
assert.match(nginx, /location = \/terms/);
assert.match(nginx, /try_files \/terms\.html =404;/);
assert.match(nginx, /location = \/public\.css/);
assert.match(nginx, /add_header_inherit merge;/);
assert.match(nginx, /location \/\s*\{\s*return 404;/);
for (const header of [
  "X-Content-Type-Options",
  "X-Frame-Options",
  "Referrer-Policy",
  "Permissions-Policy",
  "Strict-Transport-Security",
  "Content-Security-Policy",
]) {
  assert.equal(
    (nginx.match(new RegExp(`add_header ${header} `, "g")) ?? []).length,
    1,
    `${header} should be declared once and inherited by every location.`,
  );
}
assert.match(nginx, /access_log off;/);
assert.match(nginx, /Cache-Control "no-store"/);
assert.match(nginx, /X-Robots-Tag "noindex, nofollow, noarchive"/);
assert.match(nginx, /try_files \/invite\.html =404;/);
assert.match(nginx, /location ~ \/\\\.\(\?!well-known/);
assert.match(nginx, /Dockerfile\|docker-compose/);
assert.match(nginx, /location = \/\.well-known\/assetlinks\.json/);
assert.match(nginx, /try_files \/assetlinks\.json =404;/);
assert.match(
  nginx,
  /location = \/\.well-known\/apple-app-site-association\s*\{\s*return 404;/,
);
assert.match(nginx, /invite-preview\.png[\s\S]*?max-age=86400/);
assert.doesNotMatch(nginx, /invite-preview\.png[\s\S]*?immutable/);
assert.equal(assetLinks[0].target.namespace, "android_app");
assert.equal(assetLinks[0].target.package_name, "com.aarast.aarast_mobile");
assert.match(
  assetLinks[0].target.sha256_cert_fingerprints[0],
  /^(?:[A-F0-9]{2}:){31}[A-F0-9]{2}$/,
);

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

for (const [name, html] of [
  ["privacy", privacyHtml],
  ["support", supportHtml],
  ["terms", termsHtml],
]) {
  assert.match(html, /<html lang="ar" dir="rtl">/, `${name} must be Arabic RTL.`);
  assert.match(html, /<link rel="stylesheet" href="\/public\.css">/);
  assert.doesNotMatch(html, /<script/i, `${name} must not execute JavaScript.`);
  assert.doesNotMatch(html, /<form/i, `${name} must not collect user data.`);
}

assert.match(privacyHtml, /href="\/support"/);
assert.match(privacyHtml, /لا نعالج مدفوعات داخل التطبيق/);
assert.match(privacyHtml, /لا نتتبع موقعك الجغرافي/);
assert.match(privacyHtml, /لا نستخدم إعلانات/);
assert.match(privacyHtml, /معرّف\s+تثبيت Firebase/);
assert.match(privacyHtml, /بعد منح إذن الإشعارات/);
assert.match(privacyHtml, /سجلات الأعطال والتشخيص/);
assert.match(privacyHtml, /تُرسل تلقائيًا إلى Sentry/);
assert.match(privacyHtml, /تقرير الدعم التشخيصي/);
assert.match(privacyHtml, /موافقة جديدة/);
assert.match(privacyHtml, /سجل مساهمات محدود/);
assert.match(privacyHtml, /إيصال حذف مجهول/);
assert.match(privacyHtml, /هوية تطبيق الأعراس وبياناتها/);
assert.match(privacyHtml, /لا يحذف حساب الإدارة/);
assert.match(privacyHtml, /تُجدول الوسائط المرفوعة\s+للحذف/);
assert.match(privacyHtml, /الأطفال/);
assert.match(privacyHtml, /دون 13 عاماً/);
// RA-ST-01: aarast.app belongs to another company (no mail on it), so no page
// may send people, or their deletion requests, there.
for (const [name, html] of [['privacy', privacyHtml], ['terms', termsHtml], ['support', supportHtml]]) {
  assert.doesNotMatch(html, /aarast\.app/, `${name} must not publish an address on aarast.app`);
}
assert.match(supportHtml, /حذف الحساب/);
// RA-ST-02: the pages say what the server does (D63): a 30-day grace that a
// sign-in cancels, then the erasure.
assert.match(privacyHtml, /30 يومًا/);
assert.match(supportHtml, /30 يومًا/);
assert.match(publicCss, /font-family:/);

// Guest RSVP (V1 checklist 4.7): a private, uncached, unindexed page whose
// script talks only to its own origin and keeps nothing on the device.
assert.match(nginx, /location \^~ \/rsvp\/[\s\S]*?no-store[\s\S]*?noindex[\s\S]*?try_files \/rsvp\.html =404;/);
assert.match(nginx, /location = \/rsvp\.js/);
assert.match(nginx, /location = \/rsvp\.css/);
assert.match(rsvpHtml, /<html lang="ar" dir="rtl">/);
assert.match(rsvpHtml, /noindex,nofollow,noarchive/);
assert.doesNotMatch(rsvpHtml, /<form/i, "RSVP answers by fetch; CSP forbids form posts.");
assert.doesNotMatch(
  rsvpHtml,
  /<script(?![^>]*\bsrc=)[^>]*>[\s\S]*<\/script>/i,
  "Inline scripts are forbidden by CSP.",
);
assert.match(rsvpJs, /segments\.length === 2 && segments\[0\] === "rsvp"/);
assert.match(rsvpJs, /\^\[A-Za-z0-9_-\]\{43\}\$/);
assert.match(rsvpJs, /`\/api\/v1\/public\/rsvp\/\$\{encodeURIComponent\(token\)\}`/);
assert.doesNotMatch(rsvpJs, /https?:\/\//, "The RSVP page calls only its own origin.");
for (const forbidden of ["localStorage", "sessionStorage", "document.cookie", "console."]) {
  assert.doesNotMatch(rsvpJs, new RegExp(forbidden.replace(".", "\\.")));
}
// D83: the card (photo, host line, free text, map or address) and the events
// beyond the wedding, each answered on its own through the same endpoint.
for (const id of ["rsvp-photo", "rsvp-free-text", "rsvp-map", "rsvp-address", "rsvp-events", "rsvp-events-list"]) {
  assert.match(rsvpHtml, new RegExp(`id="${id}"`));
}
assert.match(rsvpHtml, /rel="noopener noreferrer"/);
assert.match(rsvpJs, /body\.planEventId = options\.planEventId/);
assert.match(rsvpJs, /\/\^https:\/\.test\(value\)/, "Only HTTPS links from the server are opened or shown.");
assert.match(rsvpJs, /hostPhrase \|\| "يسعدنا حضورك"/);
// The card photo comes from the public media bucket and nowhere else.
assert.match(
  nginx,
  /img-src 'self' https:\/\/\*\.s3\.eu-central-1\.amazonaws\.com https:\/\/aarast-media\.shadowgardn\.com;/,
);

// V1 checklist 6.3: the terms say plainly that no money moves through the
// app and that providers are independent parties.
assert.match(termsHtml, /لا يستلم أموالًا ولا يحوّلها ولا يقرض/);
assert.match(termsHtml, /أطراف مستقلة/);
assert.match(termsHtml, /href="\/privacy"/);
assert.match(supportHtml, /href="\/terms"/);
// The privacy policy covers the V1 additions.
assert.match(privacyHtml, /صور الإيصالات/);
assert.match(privacyHtml, /رد الضيف على دعوتك/);
assert.match(privacyHtml, /تكلفة خاصة لا يراها الآخر/);
assert.match(privacyHtml, /قفل التطبيق برمز/);
// V1 checklist 4.12: what the assistant sends, to whom, and what it keeps.
assert.match(privacyHtml, /المساعد الذكي/);
assert.match(privacyHtml, /Claude من شركة Anthropic/);
// RA-ST-04 (D95): a reported answer is the one thing the assistant keeps.
assert.match(privacyHtml, /إذا بلّغت عن إجابة، نحفظ تلك الإجابة مع سؤالك وسبب البلاغ/);
assert.match(privacyHtml, /لا نرسل أسماء ضيوفك ولا أرقام هواتف/);
assert.match(privacyHtml, /لا نحفظ أسئلتك ولا الإجابات/);

// V1 checklist 6.4: the download page draws the QR code of its own origin
// with the vendored qrcode-generator 1.4.4 (MIT, npm integrity
// sha512-HM7yY8O2…guuw==), kept byte-for-byte as published.
const downloadHtml = read("download.html");
const downloadJs = read("download.js");
const qrLibrary = read("qrcode-generator.js").replaceAll("\r\n", "\n");
for (const asset of ["download.html", "download.js", "qrcode-generator.js"]) {
  const escaped = asset.replaceAll(".", "\\.");
  assert.match(dockerfile, new RegExp(escaped), `${asset} must be copied explicitly.`);
  assert.match(dockerignore, new RegExp(`^!${escaped}$`, "m"), `${asset} must be allowlisted.`);
}
assert.match(nginx, /location = \/download \{[\s\S]*?try_files \/download\.html =404;/);
assert.match(nginx, /location = \/download\.js/);
assert.match(nginx, /location = \/qrcode-generator\.js/);
assert.equal(
  createHash("sha256").update(qrLibrary).digest("hex"),
  "18ae399f81182bc9de916e9c77b195df20cc58d6f2d55a62b085a299f1bf1780",
  "qrcode-generator.js must stay the published 1.4.4 file.",
);
assert.match(downloadHtml, /<html lang="ar" dir="rtl">/);
assert.doesNotMatch(downloadHtml, /<form/i);
assert.doesNotMatch(
  downloadHtml,
  /<script(?![^>]*\bsrc=)[^>]*>[\s\S]*<\/script>/i,
  "Inline scripts are forbidden by CSP.",
);
assert.match(downloadHtml, /<script src="\/qrcode-generator\.js" defer><\/script>\s*<script src="\/download\.js" defer><\/script>/);
assert.match(downloadHtml, /play\.google\.com\/store\/apps\/details\?id=com\.aarast\.aarast_mobile/);
assert.match(downloadHtml, /href="\/privacy"/);
assert.match(downloadHtml, /href="\/terms"/);
assert.match(downloadJs, /window\.location\.origin \+ "\/download"/);
assert.doesNotMatch(downloadJs, /innerHTML|style=|setAttribute\("style"/, "CSP forbids inline styles.");
for (const forbidden of ["localStorage", "sessionStorage", "document.cookie", "console.", "fetch("]) {
  assert.doesNotMatch(downloadJs, new RegExp(forbidden.replace(/[.(]/g, "\\$&")));
}

process.stdout.write("public-site source checks: PASS\n");
