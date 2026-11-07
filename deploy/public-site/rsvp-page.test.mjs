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
const token = "A".repeat(43);

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
  }
  setAttribute(name, value) {
    this.attributes[name] = String(value);
  }
  removeAttribute(name) {
    delete this.attributes[name];
  }
  addEventListener(type, listener) {
    if (type === "click") this.listeners.push(listener);
  }
  click() {
    for (const listener of this.listeners) listener();
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
}

/** Opens the page on [token] with [replies] as the server's answers, in order. */
async function openPage(replies) {
  const elements = new Map(
    [...html.matchAll(/<(\w+) id="([^"]+)"([^>]*)>/g)].map(([, tag, id, rest]) => [
      id,
      new FakeElement(tag, /\shidden\b/.test(rest)),
    ]),
  );
  const requests = [];
  const context = vm.createContext({
    window: { location: { pathname: `/rsvp/${token}` } },
    document: {
      getElementById: (id) => elements.get(id) ?? null,
      createElement: (tag) => new FakeElement(tag),
    },
    fetch: async (url, options = {}) => {
      requests.push(`${options.method ?? "GET"} ${url}`);
      const [status, body] = replies.shift();
      return { status, ok: status >= 200 && status < 300, json: async () => body };
    },
  });
  vm.runInContext(script, context);
  await settle();
  return { element: (id) => elements.get(id), requests };
}

async function settle() {
  for (let turn = 0; turn < 20; turn += 1) await new Promise((resolve) => setImmediate(resolve));
}

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
    wedding: null,
    card: null,
    hostPhrase: null,
    events,
  };
}

const lunch = {
  id: "event-lunch",
  label: "الغداء",
  date: "2027-02-18",
  timeLabel: "الظهر",
  placeLabel: null,
  attendanceStatus: "PENDING",
  companionsCount: 0,
};

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

  const endpoint = `/api/v1/public/rsvp/${token}`;
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
