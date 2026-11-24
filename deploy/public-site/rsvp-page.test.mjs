import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

// The guest's RSVP page as it behaves: rsvp.js run against the ids of
// rsvp.html and a scripted server, with no browser.

const root = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(root, "rsvp.html"), "utf8");
const script = readFileSync(join(root, "rsvp.js"), "utf8");
const css = readFileSync(join(root, "rsvp.css"), "utf8");
const token = "A".repeat(43);
const endpoint = `/api/v1/public/rsvp/${token}`;

class FakeElement {
  constructor(tagName, hidden = false) {
    this.tagName = tagName;
    this.hidden = hidden;
    this.textContent = "";
    this.className = "";
    this.disabled = false;
    this.children = [];
    this.attributes = {};
    this.listeners = [];
    this.otherListeners = {};
    this.scrolledWith = null;
  }
  setAttribute(name, value) {
    this.attributes[name] = String(value);
  }
  removeAttribute(name) {
    delete this.attributes[name];
  }
  addEventListener(type, listener) {
    if (type === "click") this.listeners.push(listener);
    else (this.otherListeners[type] ??= []).push(listener);
  }
  click() {
    for (const listener of this.listeners) listener();
  }
  /** What the browser does when the element's own load fails or ends. */
  dispatch(type) {
    for (const listener of this.otherListeners[type] ?? []) listener();
  }
  scrollIntoView(options) {
    this.scrolledWith = options;
  }
  append(...nodes) {
    this.children.push(...nodes);
  }
  replaceChildren(...nodes) {
    this.children = nodes;
  }
  /** The first element below this one whose text is [text]. */
  find(text) {
    for (const child of this.children) {
      if (child.textContent === text) return child;
      const found = child.find(text);
      if (found) return found;
    }
    return null;
  }
  /** Every element below this one that [accept] takes. */
  findAll(accept) {
    const found = [];
    for (const child of this.children) {
      if (accept(child)) found.push(child);
      found.push(...child.findAll(accept));
    }
    return found;
  }
}

const hasClass = (element, name) => element.className.split(" ").includes(name);

/**
 * Opens the page with [replies] as the server's answers to the page's reads
 * and replies, in order ("network" for a request that never arrives). The
 * opened beacon is answered apart, by [opened], and kept in `beacons`.
 */
async function openPage(
  replies,
  { search = "", path = `/rsvp/${token}`, opened = () => [200, { opened: true }] } = {},
) {
  const elements = new Map(
    [...html.matchAll(/<(\w+) id="([^"]+)"([^>]*)>/g)].map(([, tag, id, rest]) => [
      id,
      new FakeElement(tag, /\shidden\b/.test(rest)),
    ]),
  );
  const requests = [];
  const beacons = [];
  const answerTo = (reply) => {
    if (reply === "network") throw new TypeError("Failed to fetch");
    const [status, body] = reply;
    return { status, ok: status >= 200 && status < 300, json: async () => body };
  };
  const context = vm.createContext({
    window: { location: { pathname: path, search } },
    document: {
      getElementById: (id) => elements.get(id) ?? null,
      createElement: (tag) => new FakeElement(tag),
    },
    fetch: async (url, options = {}) => {
      const line = `${options.method ?? "GET"} ${url}`;
      if (url.endsWith("/opened")) {
        beacons.push(line);
        return answerTo(opened());
      }
      requests.push(line);
      return answerTo(replies.shift());
    },
  });
  vm.runInContext(script, context);
  await settle();
  return { element: (id) => elements.get(id), requests, beacons };
}

async function settle() {
  for (let turn = 0; turn < 20; turn += 1) await new Promise((resolve) => setImmediate(resolve));
}

const wedding = {
  id: "event-wedding",
  timeSlot: null,
  exactTime: null,
  timeLabel: null,
  placeLabel: null,
  mapUrl: null,
  address: null,
  needsReconfirm: false,
};

function invitation(events) {
  return {
    guestName: "عمي صالح",
    planTitle: "عرس أحمد",
    weddingDate: "2027-02-18",
    locationLabel: "صنعاء",
    attendanceStatus: "PENDING",
    companionsCount: 0,
    maxCompanions: 20,
    respondedAt: null,
    wedding: { ...wedding },
    card: null,
    hostPhrase: null,
    events,
    persona: null,
  };
}

const lunch = {
  id: "event-lunch",
  label: "الغداء",
  date: "2027-02-18",
  timeLabel: "الظهر",
  placeLabel: null,
  mapUrl: null,
  address: null,
  attendanceStatus: "PENDING",
  companionsCount: 0,
  needsReconfirm: false,
};

const samra = { ...lunch, id: "event-samra", label: "السمرة", timeLabel: "بعد العشاء" };

test("RA-BE-74: a reply to an event taken out of the invitation reloads it and says so", async () => {
  const page = await openPage([
    [200, invitation([lunch])],
    [409, { statusCode: 409, code: "RSVP_EVENT_NOT_INVITED", message: "هذي المناسبة ما عادت في دعوتك." }],
    [200, invitation([])],
    [200, { ...invitation([]), attendanceStatus: "CONFIRMED" }],
  ]);
  assert.equal(page.element("rsvp-events").hidden, false);

  page.element("rsvp-events-list").find("حاضر").click();
  await settle();

  assert.deepEqual(page.requests, [`GET ${endpoint}`, `POST ${endpoint}`, `GET ${endpoint}`]);
  // The invitation stays, as it is now, with a line that says why.
  assert.equal(page.element("rsvp-title").textContent, "عرس أحمد");
  assert.equal(page.element("rsvp-answer").hidden, false);
  assert.equal(page.element("rsvp-events").hidden, true);
  assert.equal(page.element("rsvp-notice").hidden, false);
  assert.equal(page.element("rsvp-notice").textContent, "تغيّرت دعوتك قبل ما يوصل ردك، وهذي هي الحين.");

  // The next reply that lands clears the line.
  page.element("rsvp-yes").click();
  await settle();
  assert.equal(page.element("rsvp-notice").hidden, true);
  assert.match(page.element("rsvp-status").textContent, /سجّلنا حضورك/);
});

// 6a: the bucket keeps the photo private; the page reads it through this
// link's own route on its own origin (the server may name another host of
// the same site), and loads nothing else.
test("the card photo is read through the link's own route on the page's origin", async () => {
  const route = `/api/v1/public/rsvp/${token}/card-photo`;
  for (const origin of ["https://3.121.198.183", "https://3-121-198-183.sslip.io"]) {
    const page = await openPage([
      [200, { ...invitation([]), card: { photoUrl: `${origin}${route}` } }],
    ]);
    assert.equal(page.element("rsvp-photo").hidden, false);
    assert.equal(page.element("rsvp-photo").src, route);
  }
  for (const foreign of [
    "https://aarast-media.s3.eu-central-1.amazonaws.com/guest-invitation-card/u/a.jpg",
    `https://3.121.198.183/api/v1/public/rsvp/${"B".repeat(43)}/card-photo`,
    `http://3.121.198.183${route}`,
  ]) {
    const page = await openPage([[200, { ...invitation([]), card: { photoUrl: foreign } }]]);
    assert.equal(page.element("rsvp-photo").hidden, true, foreign);
    assert.equal(page.element("rsvp-photo").src, undefined, foreign);
  }
});

// From the second review of the field-notes branch: a photo the route
// could not give (its signed link refused, the connection dropped) stayed
// on the page as a broken picture over the invitation.
test("a card photo that fails to load is taken off the page, the invitation stays", async () => {
  const route = `/api/v1/public/rsvp/${token}/card-photo`;
  const page = await openPage([
    [200, { ...invitation([]), card: { photoUrl: `https://3.121.198.183${route}` } }],
  ]);
  const photo = page.element("rsvp-photo");
  assert.equal(photo.hidden, false);

  photo.dispatch("error");

  assert.equal(photo.hidden, true);
  assert.equal(page.element("rsvp-title").hidden, false);
});

// 6a: a crawler reads the head without running the script. The page keeps
// its generic tags as the SSI stub; nginx puts the link's own in their place.
test("the page head names the link's own preview through SSI, generic without it", () => {
  const head = html.slice(0, html.indexOf("</head>"));
  const block = /<!--# block name="rsvp_preview" -->([\s\S]*?)<!--# endblock -->/.exec(head);
  assert.ok(block, "the generic tags are the stub block");
  assert.match(block[1], /<meta property="og:title" content="دعوة عرس">/);
  assert.match(block[1], /<meta property="og:description" content="[^"]+">/);
  assert.match(head, /<!--# include virtual="\/__rsvp_preview\/\$rsvp_token" stub="rsvp_preview" -->/);
  // Outside the stub the page names no title or image of its own.
  const rest = head.replace(block[0], "");
  assert.doesNotMatch(rest, /og:title|og:description|og:image/);
});

test("a link the server does not know is still a dead link", async () => {
  const page = await openPage([
    [200, invitation([lunch])],
    [404, { statusCode: 404, code: "RSVP_LINK_NOT_FOUND", message: "This invitation link is not valid" }],
  ]);
  page.element("rsvp-events-list").find("حاضر").click();
  await settle();

  assert.equal(page.element("rsvp-title").textContent, "الرابط ما يشتغل");
  assert.equal(page.element("rsvp-answer").hidden, true);
  assert.equal(page.element("rsvp-events").hidden, true);
});

// D116: a bride's plan invites women; every line addressed to the guest
// takes the feminine form.
test("D116: a bride's guests are spoken to as women, on the buttons and the status line", async () => {
  const bride = (over = {}) => ({
    ...invitation([lunch]),
    persona: "BRIDE",
    wedding: { ...wedding, mapUrl: "https://maps.example.com/hall" },
    ...over,
  });
  const page = await openPage([
    [200, bride()],
    [200, bride({ attendanceStatus: "CONFIRMED" })],
    [429, { statusCode: 429 }],
    [500, {}],
    [404, { statusCode: 404, code: "RSVP_LINK_NOT_FOUND" }],
  ]);
  assert.equal(page.element("rsvp-yes").textContent, "إن شاء الله حاضرة");
  assert.equal(page.element("rsvp-no").textContent, "أعتذر");
  assert.equal(page.element("rsvp-map").textContent, "افتحي الموقع على الخريطة");
  const events = page.element("rsvp-events-list");
  assert.ok(events.find("حاضرة"));
  assert.equal(events.find("حاضر"), null);

  page.element("rsvp-yes").click();
  await settle();
  assert.equal(
    page.element("rsvp-status").textContent,
    "سجّلنا حضورك. تقدرين تغيّرين ردك متى ما تشتين.",
  );

  page.element("rsvp-no").click();
  await settle();
  assert.equal(page.element("rsvp-status").textContent, "محاولات كثيرة. انتظري دقيقة وجرّبي ثاني.");

  page.element("rsvp-no").click();
  await settle();
  assert.equal(page.element("rsvp-status").textContent, "ما وصل ردك. جرّبي مرة ثانية.");

  page.element("rsvp-events-list").find("حاضرة").click();
  await settle();
  assert.equal(page.element("rsvp-title").textContent, "الرابط ما يشتغل");
  assert.equal(
    page.element("rsvp-invite-line").textContent,
    "اطلبي من صاحبة الدعوة ترسل لك رابط جديد.",
  );
});

test("D116: a groom's guests, and a plan that names no side, keep the masculine form", async () => {
  for (const persona of ["GROOM", null]) {
    const page = await openPage([
      [200, { ...invitation([lunch]), persona }],
      [200, { ...invitation([lunch]), persona, attendanceStatus: "DECLINED" }],
    ]);
    assert.equal(page.element("rsvp-yes").textContent, "إن شاء الله حاضر", String(persona));
    assert.ok(page.element("rsvp-events-list").find("حاضر"), String(persona));
    page.element("rsvp-no").click();
    await settle();
    assert.equal(
      page.element("rsvp-status").textContent,
      "سجّلنا اعتذارك. تقدر تغيّر ردك متى ما تشتي.",
      String(persona),
    );
  }
});

test("D116: each occasion opens its own map; a link that is not https is not shown", async () => {
  const page = await openPage([
    [
      200,
      {
        ...invitation([
          {
            ...lunch,
            placeLabel: "بيت العم",
            address: "حدة، جنب الجامع",
            mapUrl: "https://maps.example.com/lunch",
          },
          { ...samra, mapUrl: "http://maps.example.com/samra" },
          { ...lunch, id: "event-henna", label: "الحناء", mapUrl: "javascript:alert(1)" },
        ]),
        wedding: {
          ...wedding,
          placeLabel: "قاعة الماسة",
          address: "شارع الستين",
          mapUrl: "https://maps.example.com/hall",
        },
        // The card's own copy is the older pages'; the wedding's is read.
        card: { photoUrl: null, photoKind: "PHOTO", mapUrl: "https://maps.example.com/old", address: "قديم" },
      },
    ],
  ]);
  const map = page.element("rsvp-map");
  assert.equal(map.hidden, false);
  assert.equal(map.href, "https://maps.example.com/hall");
  assert.equal(map.textContent, "افتح الموقع على الخريطة");
  assert.equal(page.element("rsvp-address").hidden, false);
  assert.equal(page.element("rsvp-address").textContent, "شارع الستين");
  assert.equal(page.element("rsvp-where-row").hidden, false);
  assert.equal(page.element("rsvp-place").textContent, "قاعة الماسة");

  const list = page.element("rsvp-events-list");
  const links = list.findAll((node) => node.tagName === "a");
  assert.equal(links.length, 1, "only the https map is a link");
  assert.equal(links[0].href, "https://maps.example.com/lunch");
  assert.equal(links[0].target, "_blank");
  assert.equal(links[0].rel, "noopener noreferrer");
  assert.equal(links[0].textContent, "افتح الموقع على الخريطة");
  const [lunchBlock] = list.children;
  assert.ok(lunchBlock.find("بيت العم"));
  assert.ok(lunchBlock.find("حدة، جنب الجامع"));
  assert.ok(lunchBlock.children.includes(links[0]));

  // A wedding whose map is not https shows no map, and no empty row.
  const plain = await openPage([
    [200, { ...invitation([]), wedding: { ...wedding, mapUrl: "http://maps.example.com/hall" } }],
  ]);
  assert.equal(plain.element("rsvp-map").hidden, true);
  assert.equal(plain.element("rsvp-map").href, undefined);
  assert.equal(plain.element("rsvp-where-row").hidden, true);
});

test("D116: an answer given before a change asks to be confirmed again, until it is", async () => {
  const changed = (over = {}) => ({
    ...invitation([{ ...lunch, attendanceStatus: "CONFIRMED", needsReconfirm: true }]),
    attendanceStatus: "CONFIRMED",
    wedding: { ...wedding, needsReconfirm: true },
    ...over,
  });
  const page = await openPage([
    [200, changed()],
    [200, changed({ wedding: { ...wedding } })],
    [
      200,
      changed({ wedding: { ...wedding }, events: [{ ...lunch, attendanceStatus: "CONFIRMED" }] }),
    ],
  ]);
  const weddingLine = "تغيّر موعد أو مكان العرس. أكّد حضورك من جديد.";
  const eventLine = "تغيّر موعد أو مكان هذي المناسبة. أكّد حضورك من جديد.";
  assert.equal(page.element("rsvp-reconfirm").hidden, false);
  assert.equal(page.element("rsvp-reconfirm").textContent, weddingLine);
  // The answer given is kept and shown, the buttons ready to confirm again.
  assert.match(page.element("rsvp-status").textContent, /^سجّلنا حضورك/);
  assert.equal(page.element("rsvp-status").className, "rsvp-status");
  assert.equal(page.element("rsvp-yes").disabled, false);
  assert.ok(page.element("rsvp-events-list").find(eventLine));

  page.element("rsvp-yes").click();
  await settle();
  assert.equal(page.element("rsvp-reconfirm").hidden, true);
  assert.equal(page.element("rsvp-status").className, "rsvp-status rsvp-done");
  assert.ok(page.element("rsvp-events-list").find(eventLine), "the event still asks");

  page.element("rsvp-events-list").find("حاضر").click();
  await settle();
  assert.equal(page.element("rsvp-events-list").find(eventLine), null);

  const bride = await openPage([[200, { ...changed(), persona: "BRIDE" }]]);
  assert.equal(
    bride.element("rsvp-reconfirm").textContent,
    "تغيّر موعد أو مكان العرس. أكّدي حضورك من جديد.",
  );
  assert.ok(
    bride.element("rsvp-events-list").find("تغيّر موعد أو مكان هذي المناسبة. أكّدي حضورك من جديد."),
  );
});

test("D116: a ready-made card is shown whole, without the host line and title under it", async () => {
  const route = `/api/v1/public/rsvp/${token}/card-photo`;
  const withCard = (photoKind) => ({
    ...invitation([lunch]),
    hostPhrase: "يتشرف أبو أحمد بدعوتكم لحضور",
    card: { photoUrl: `https://3.121.198.183${route}`, photoKind, hostLine: "أبو أحمد" },
  });
  const page = await openPage([[200, withCard("CARD")]]);
  const photo = page.element("rsvp-photo");
  assert.equal(photo.hidden, false);
  assert.ok(hasClass(photo, "rsvp-photo-card"));
  assert.equal(page.element("rsvp-invite-line").hidden, true);
  assert.equal(page.element("rsvp-title").hidden, true);
  // The guest is still greeted, and each occasion is still told and answered.
  assert.equal(page.element("rsvp-greeting").textContent, "أهلًا عمي صالح");
  assert.equal(page.element("rsvp-details").hidden, false);
  assert.equal(page.element("rsvp-answer").hidden, false);
  assert.equal(page.element("rsvp-events").hidden, false);

  // Without the picture, its words come back.
  photo.dispatch("error");
  assert.equal(page.element("rsvp-invite-line").hidden, false);
  assert.equal(page.element("rsvp-title").hidden, false);
  assert.equal(page.element("rsvp-title").textContent, "عرس أحمد");

  const framed = await openPage([[200, withCard("PHOTO")]]);
  assert.equal(framed.element("rsvp-photo").hidden, false);
  assert.equal(hasClass(framed.element("rsvp-photo"), "rsvp-photo-card"), false);
  assert.equal(framed.element("rsvp-invite-line").hidden, false);
  assert.equal(framed.element("rsvp-title").hidden, false);

  // Whole: its own proportions, never cropped.
  const rule = /\.rsvp-photo\.rsvp-photo-card\s*\{([^}]*)\}/.exec(css)?.[1] ?? "";
  assert.match(rule, /object-fit:\s*contain;/);
  assert.match(rule, /max-height:\s*none;/);
  assert.match(rule, /height:\s*auto;/);
});

test("D116: ?e= marks the occasion its own message was about and scrolls to it", async () => {
  const page = await openPage([[200, invitation([lunch, samra])]], { search: "?e=event-samra" });
  const [lunchBlock, samraBlock] = page.element("rsvp-events-list").children;
  assert.ok(hasClass(samraBlock, "rsvp-focus"));
  assert.equal(samraBlock.scrolledWith?.block, "start");
  assert.equal(hasClass(lunchBlock, "rsvp-focus"), false);
  assert.equal(lunchBlock.scrolledWith, null);
  assert.equal(hasClass(page.element("rsvp-answer"), "rsvp-focus"), false);

  const weddingPage = await openPage([[200, invitation([lunch])]], {
    search: "?x=1&e=event-wedding",
  });
  assert.ok(hasClass(weddingPage.element("rsvp-answer"), "rsvp-focus"));
  assert.equal(weddingPage.element("rsvp-card").scrolledWith?.block, "start");

  const unknown = await openPage([[200, invitation([lunch, samra])]], { search: "?e=nope" });
  for (const block of unknown.element("rsvp-events-list").children) {
    assert.equal(hasClass(block, "rsvp-focus"), false);
    assert.equal(block.scrolledWith, null);
  }
  assert.equal(hasClass(unknown.element("rsvp-answer"), "rsvp-focus"), false);
  assert.equal(unknown.element("rsvp-card").scrolledWith, null);
});

test("D116: the page tells the server once that the guest saw it, after it is drawn", async () => {
  const opened = `POST ${endpoint}/opened`;
  const page = await openPage([
    [200, invitation([lunch])],
    [409, { statusCode: 409, code: "RSVP_EVENT_NOT_INVITED" }],
    [200, invitation([])],
    [200, { ...invitation([]), attendanceStatus: "CONFIRMED" }],
  ]);
  assert.deepEqual(page.beacons, [opened]);
  page.element("rsvp-events-list").find("حاضر").click();
  await settle();
  page.element("rsvp-yes").click();
  await settle();
  assert.deepEqual(page.beacons, [opened], "drawn again, never told again");

  for (const reply of ["network", [500, {}], [404, { statusCode: 404 }]]) {
    const failed = await openPage([reply]);
    assert.deepEqual(failed.beacons, [], JSON.stringify(reply));
  }
  const invalid = await openPage([], { path: "/rsvp/short" });
  assert.deepEqual(invalid.requests, []);
  assert.deepEqual(invalid.beacons, []);
  assert.equal(invalid.element("rsvp-title").textContent, "الرابط ما يشتغل");
  assert.equal(
    invalid.element("rsvp-invite-line").textContent,
    "أهل الدعوة يقدرون يرسلون لك رابط جديد.",
  );

  // Its failure changes nothing on the page.
  for (const answer of ["network", [500, {}]]) {
    const quiet = await openPage([[200, invitation([lunch])]], { opened: () => answer });
    assert.equal(quiet.beacons.length, 1);
    assert.equal(quiet.element("rsvp-title").textContent, "عرس أحمد");
    assert.equal(quiet.element("rsvp-answer").hidden, false);
    assert.equal(quiet.element("rsvp-retry").hidden, true);
  }
});

test("D116: after a failed load the guest tries again from the page", async () => {
  const page = await openPage(["network", [500, {}], [200, invitation([lunch])]]);
  const retry = page.element("rsvp-retry");
  assert.equal(page.element("rsvp-title").textContent, "ما قدرنا نفتح الدعوة");
  assert.equal(page.element("rsvp-invite-line").textContent, "يمكن النت ضعيف أو مقطوع.");
  assert.equal(retry.hidden, false);
  assert.equal(page.element("rsvp-answer").hidden, true);

  retry.click();
  await settle();
  assert.equal(page.element("rsvp-title").textContent, "ما قدرنا نفتح الدعوة");
  assert.equal(retry.hidden, false);

  retry.click();
  await settle();
  assert.deepEqual(page.requests, [`GET ${endpoint}`, `GET ${endpoint}`, `GET ${endpoint}`]);
  assert.equal(page.element("rsvp-title").textContent, "عرس أحمد");
  assert.equal(retry.hidden, true);
  assert.equal(page.element("rsvp-answer").hidden, false);
  assert.equal(page.element("rsvp-events").hidden, false);
  assert.equal(page.beacons.length, 1);

  // A dead link has its own words and nothing to try again.
  const dead = await openPage([[404, { statusCode: 404 }]]);
  assert.equal(dead.element("rsvp-title").textContent, "الرابط ما يشتغل");
  assert.equal(dead.element("rsvp-retry").hidden, true);
});

test("D116: a reload that fails after a bride's page was drawn says so to her, and the retry keeps why", async () => {
  const bride = (events) => ({ ...invitation(events), persona: "BRIDE" });
  const page = await openPage([
    [200, bride([lunch])],
    [409, { statusCode: 409, code: "RSVP_EVENT_NOT_INVITED" }],
    [500, {}],
    [200, bride([])],
  ]);
  page.element("rsvp-events-list").find("حاضرة").click();
  await settle();
  assert.equal(page.element("rsvp-title").textContent, "ما قدرنا نفتح الدعوة");
  assert.equal(page.element("rsvp-invite-line").textContent, "تأكدي من النت وحاولي مرة ثانية.");
  assert.equal(page.element("rsvp-answer").hidden, true);
  assert.equal(page.element("rsvp-events").hidden, true);

  page.element("rsvp-retry").click();
  await settle();
  assert.equal(page.element("rsvp-title").textContent, "عرس أحمد");
  assert.equal(page.element("rsvp-notice").textContent, "تغيّرت دعوتك قبل ما يوصل ردك، وهذي هي الحين.");
});

// RA-BE-173 (Q-43): the owner sets how many may come with the guest; the page
// offers exactly that, and asks nothing when it is no one.
test("RA-BE-173: the companion chips are the owner's number, and none asks nothing", async () => {
  const chipsOf = (container) => container.children.map((chip) => chip.textContent);

  const five = await openPage([[200, { ...invitation([lunch]), maxCompanions: 5 }]]);
  assert.deepEqual(chipsOf(five.element("rsvp-companions")), ["لحالي", "+1", "+2", "+3", "+4", "+5"]);
  assert.equal(five.element("rsvp-companions").hidden, false);
  assert.equal(five.element("rsvp-companions-label").hidden, false);
  const lunchChips = five.element("rsvp-events-list").findAll((element) => hasClass(element, "rsvp-chips"));
  assert.equal(lunchChips.length, 1);
  assert.deepEqual(chipsOf(lunchChips[0]), ["لحالي", "+1", "+2", "+3", "+4", "+5"]);

  const one = await openPage([[200, { ...invitation([lunch]), maxCompanions: 1 }]]);
  assert.deepEqual(chipsOf(one.element("rsvp-companions")), ["لحالي", "+1"]);

  const alone = await openPage([
    [200, { ...invitation([lunch]), maxCompanions: 0 }],
    [200, { ...invitation([lunch]), maxCompanions: 0, attendanceStatus: "CONFIRMED" }],
  ]);
  assert.equal(alone.element("rsvp-companions").hidden, true);
  assert.equal(alone.element("rsvp-companions-label").hidden, true);
  const list = alone.element("rsvp-events-list");
  assert.equal(list.findAll((element) => hasClass(element, "rsvp-chips")).length, 0);
  assert.equal(list.find("كم معك؟"), null);
  // The answer still goes, alone.
  alone.element("rsvp-yes").click();
  await settle();
  assert.equal(alone.requests[1], `POST ${endpoint}`);
});
