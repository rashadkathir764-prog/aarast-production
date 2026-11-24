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
  "rsvp-preview.png",
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
// RA-MO-337: valid, and naming no app (fail-closed until a real Apple Team ID).
const appleAssociation =
  /location = \/\.well-known\/apple-app-site-association\s*\{([\s\S]*?)\n    \}/.exec(nginx)?.[1] ?? "";
assert.match(appleAssociation, /default_type application\/json;/);
assert.match(appleAssociation, /return 200 '\{"applinks":\{"details":\[\]\}\}';/);
assert.doesNotMatch(appleAssociation, /return 404/);
assert.doesNotMatch(appleAssociation, /appIDs|"apps"|paths|components/);
// RA-MO-337: the invite page offers the store to a participant with no app.
assert.match(inviteHtml, /id="get-app"/);
assert.match(inviteHtml, /href="https:\/\/play\.google\.com\/store\/apps\/details\?id=com\.aarast\.aarast_mobile"/);
// RA-OP-29: the RSVP preview's mark is a real, served file.
assert.match(nginx, /location = \/rsvp-preview\.png[\s\S]*?max-age=86400/);
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

// 6c: the invite page's preview names the host it is served on (the IP until
// the domain exists), not a domain that does not resolve. The file keeps the
// canonical origin, which the staging build rewrites; nginx swaps it per
// request for a plain host name only, and never caches the answer.
const invitesLocation = /location \^~ \/invites\/ \{([^}]*)\}/.exec(nginx)?.[1] ?? "";
assert.match(invitesLocation, /sub_filter 'https:\/\/aarast\.shadowgardn\.com' \$invite_origin;/);
assert.match(invitesLocation, /sub_filter_once off;/);
assert.match(invitesLocation, /Cache-Control "no-store"/);
assert.match(
  nginx,
  /map \$host \$invite_origin \{\s*"~\^\(\?<invite_host>\[a-z0-9\.-\]\{1,253\}\)\$" https:\/\/\$invite_host;\s*default https:\/\/aarast\.shadowgardn\.com;\s*\}/,
);
for (const tag of ["og:url", "og:image", "og:image:secure_url", "twitter:image"]) {
  assert.match(inviteHtml, new RegExp(`"${tag}"\\s+content="https://aarast\\.shadowgardn\\.com/`), tag);
}
assert.match(inviteHtml, /<link rel="canonical" href="https:\/\/aarast\.shadowgardn\.com\/invites\/">/);

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
// RA-BE-179 (Q-45, D124): every kind of data the servers clean up has its
// period on the page, and a deleted plan its 30 days.
assert.match(privacyHtml, /<h2>كم نحتفظ ببياناتك<\/h2>/);
assert.match(privacyHtml, /الدعوات التي انتهت ولم تُقبل: 90 يومًا بعد انتهائها/);
assert.match(privacyHtml, /التنبيهات المقروءة: 180 يومًا بعد قراءتها/);
assert.match(privacyHtml, /سجل تدقيق الإدارة: سنتان/);
assert.match(privacyHtml, /الرسائل التي فشل إرسالها من الخادم: 30 يومًا/);
assert.match(privacyHtml, /حذف خطة العرس[\s\S]*?30 يومًا[\s\S]*?ترجعها/);
// RA-BE-178 (D112): what a deleted account recorded in another person's
// plan stays there, without its name.
assert.match(privacyHtml, /«عضو سابق»/);
assert.match(privacyHtml, /«مزود محذوف»/);
// RA-OP-32: the backups keep deleted data up to 90 days, and a restore
// erases again what was deleted.
assert.match(privacyHtml, /النسخ الاحتياطية[\s\S]*?حتى 90 يومًا/);
assert.match(privacyHtml, /نعيد حذف كل حساب حُذف/);
assert.match(privacyHtml, /120 يومًا/);
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
// 6a: through the link's own route, which redirects to a signed read there.
assert.match(
  nginx,
  /img-src 'self' https:\/\/\*\.s3\.eu-central-1\.amazonaws\.com https:\/\/aarast-media\.shadowgardn\.com;/,
);
// 6a: a link crawler reads the invitation's own tags without the script:
// the page includes the API's preview of its token through SSI, and every
// failure of that include leaves the page's generic tags (an empty 204).
assert.match(nginx, /location \^~ \/rsvp\/ \{[^}]*\bssi on;[^}]*try_files \/rsvp\.html =404;/);
assert.equal((nginx.match(/\bssi on;/g) ?? []).length, 1, "SSI runs on the RSVP page only.");
assert.match(
  nginx,
  /map \$request_uri \$rsvp_token \{\s*"~\^\/rsvp\/\(\?<rsvp_link>\[A-Za-z0-9_-\]\{43\}\)\(\?:\\\?\.\*\)\?\$" \$rsvp_link;\s*default none;\s*\}/,
);
const preview = /location ~ "\^\/__rsvp_preview\/\(\[A-Za-z0-9_-\]\{43\}\)\$" \{([^}]*)\}/.exec(nginx)?.[1] ?? "";
assert.match(preview, /\binternal;/);
assert.match(preview, /proxy_pass http:\/\/backend:3000\/api\/v1\/public\/rsvp\/\$1\/preview;/);
assert.match(preview, /resolver 127\.0\.0\.11 /, "The API's address is looked up at request time.");
assert.match(preview, /proxy_set_header Accept-Encoding "";/, "A compressed answer would land raw in the head.");
assert.match(preview, /proxy_set_header X-Forwarded-For \$http_x_forwarded_for;/, "The API limits the guest, not the site.");
assert.match(preview, /proxy_intercept_errors on;/);
assert.match(preview, /error_page [0-9 ]*\b502\b[0-9 ]* = @rsvp_preview_none;/);
// RA-BE-175: no error body of the API (401, 403, 409, 426 included) lands
// in the page's head; every one leaves the generic tags.
const previewErrors = /error_page ([0-9 ]+) = @rsvp_preview_none;/.exec(preview)?.[1].trim().split(/\s+/) ?? [];
for (const status of ["400", "401", "403", "404", "409", "426", "429", "500", "502", "503", "504"]) {
  assert.ok(previewErrors.includes(status), `the preview include swallows ${status}`);
}
assert.match(nginx, /location = \/__rsvp_preview\/none \{\s*internal;\s*return 204;\s*\}/);
assert.match(nginx, /location @rsvp_preview_none \{\s*return 204;\s*\}/);

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
// Item 8 (RA-BE-160): the budget items' names go as written, so «no name
// at all» was not true; the page says what goes and what does not.
assert.match(privacyHtml, /لا نرسل أسماء الأشخاص ولا أرقام هواتفهم/);
assert.match(privacyHtml, /أما أسماء بنود الميزانية فتُرسل كما كتبتها أنت/);
assert.doesNotMatch(privacyHtml, /أي اسم آخر/);
// RA-BE-166: a reviewed report leaves after 90 days.
assert.match(privacyHtml, /وتُحذف مع حسابك أو بعد 90 يومًا من مراجعتها/);
assert.match(privacyHtml, /لا نحفظ أسئلتك ولا الإجابات/);
// RA-BE-160, RA-BE-161 (Q-41, D124): exactly what is sent, the consent's
// stored date, the owner's consent for a partner's money, and Anthropic's
// own retention.
assert.match(privacyHtml, /المدينة وموعد العرس، والميزانية وبنودها بمبالغها المتفق عليها والمدفوعة، والمهر بمبلغه الإجمالي/);
assert.match(privacyHtml, /لا ضيوفك ولا أهلك ولا المشاركين؛ ولا اسم الخطة ولا عناوين المهام، ولا السلف والقروض/);
assert.match(privacyHtml, /لا تُرسل أرقام مال الخطة مع سؤال الشريك إلا إذا وافق صاحب الخطة/);
assert.match(privacyHtml, /نحفظ تاريخ موافقتك فقط/);
assert.match(privacyHtml, /وتحتفظ Anthropic بما يصلها وفق سياسة خدمتها للمطورين \(API\)/);
assert.doesNotMatch(privacyHtml, /عروض الأسعار التي وصلتك،\s*ونطاقات/);

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
