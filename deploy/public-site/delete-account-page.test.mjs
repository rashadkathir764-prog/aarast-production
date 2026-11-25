import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

// Q-52 (أ, D124), RA-OP-21: the deletion page as it behaves: delete-account.js
// run against the ids of delete-account.html and a scripted server, with no
// browser.

const root = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(root, "delete-account.html"), "utf8");
const script = readFileSync(join(root, "delete-account.js"), "utf8");

class FakeElement {
  constructor(id, hidden) {
    this.id = id;
    this.hidden = hidden;
    this.textContent = "";
    this.value = "";
    this.disabled = false;
    this.attributes = {};
    this.listeners = {};
    this.focused = false;
  }
  setAttribute(name, value) {
    this.attributes[name] = String(value);
  }
  addEventListener(type, listener) {
    (this.listeners[type] ??= []).push(listener);
  }
  async fire(type, event = {}) {
    for (const listener of this.listeners[type] ?? []) await listener(event);
  }
  focus() {
    this.focused = true;
  }
}

function page(answers) {
  const elements = new Map();
  for (const match of html.matchAll(/<[a-z0-9]+ id="([^"]+)"([^>]*)>/g)) {
    elements.set(match[1], new FakeElement(match[1], /\bhidden\b/.test(match[2])));
  }
  const requests = [];
  const fetch = async (url, options) => {
    requests.push({ url, options, body: JSON.parse(options.body) });
    const next = answers.shift();
    if (next instanceof Error) throw next;
    return { status: next.status, json: async () => next.body };
  };
  const context = vm.createContext({
    document: { getElementById: (id) => elements.get(id) ?? null },
    fetch,
    JSON,
    Date,
    String,
    isNaN,
  });
  vm.runInContext(script, context);
  const at = (id) => {
    const element = elements.get(id);
    assert.ok(element, `#${id} is on the page`);
    return element;
  };
  return { at, requests };
}

async function settle() {
  for (let n = 0; n < 5; n += 1) await new Promise((resolve) => setImmediate(resolve));
}

test("a number, its code, and the account waits its 30 days to the day the server names", async () => {
  const { at, requests } = page([
    { status: 200, body: { phone: "+967777300003", deliveryStatus: "DELIVERED" } },
    { status: 200, body: { status: "PENDING", scheduledFor: "2026-12-25T10:00:00.000Z" } },
  ]);
  assert.equal(at("deletion-code-step").hidden, true);
  at("deletion-phone").value = "٧٧٧٣٠٠٠٠٣";
  await at("deletion-send").fire("click");
  await settle();
  assert.equal(requests[0].url, "/api/v1/public/account-deletion/code");
  assert.deepEqual(requests[0].body, { phone: "777300003" }, "Arabic digits are sent as Latin");
  assert.equal(requests[0].options.credentials, "omit");
  assert.equal(at("deletion-phone-step").hidden, true);
  assert.equal(at("deletion-code-step").hidden, false);
  assert.equal(at("deletion-phone-echo").textContent, "777300003");

  at("deletion-code").value = "123456";
  await at("deletion-confirm").fire("click");
  await settle();
  assert.equal(requests[1].url, "/api/v1/public/account-deletion/confirm");
  assert.deepEqual(requests[1].body, { phone: "777300003", code: "123456" });
  assert.equal(at("deletion-done").hidden, false);
  assert.equal(at("deletion-code-step").hidden, true);
  assert.equal(at("deletion-day").textContent, "25/12/2026");
});

test("each refusal is said in words, and nothing is sent for a malformed number or code", async () => {
  const { at, requests } = page([
    { status: 429, body: { code: "OTP_LIMIT_PHONE_HOUR", message: "هذا الرقم طلب 5 رموز في ساعة. يتاح رمز جديد بعد 50 دقيقة." } },
    { status: 200, body: { deliveryStatus: "DELIVERED" } },
    { status: 400, body: { code: "OTP_INVALID_OR_EXPIRED" } },
    { status: 404, body: { code: "ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF" } },
    { status: 409, body: { code: "PROVIDER_HAS_UPCOMING_BOOKINGS" } },
    new Error("offline"),
  ]);
  const status = at("deletion-status");
  at("deletion-phone").value = "abc";
  await at("deletion-send").fire("click");
  assert.equal(requests.length, 0);
  assert.match(status.textContent, /الرقم غلط/);

  at("deletion-phone").value = "+967 777 300 003";
  await at("deletion-send").fire("click");
  await settle();
  assert.equal(status.textContent, "هذا الرقم طلب 5 رموز في ساعة. يتاح رمز جديد بعد 50 دقيقة.");
  await at("deletion-send").fire("click");
  await settle();
  assert.equal(at("deletion-code-step").hidden, false);

  at("deletion-code").value = "12";
  await at("deletion-confirm").fire("click");
  assert.equal(requests.length, 2);
  assert.match(status.textContent, /6 أرقام/);
  at("deletion-code").value = "123456";
  for (const expected of [/الرمز غلط أو انتهى/, /ما في حساب/, /حجوزات قادمة/, /ما قدرنا نوصل/]) {
    await at("deletion-confirm").fire("click");
    await settle();
    assert.match(status.textContent, expected);
    assert.equal(status.hidden, false);
    assert.equal(at("deletion-done").hidden, true);
    assert.equal(at("deletion-confirm").disabled, false, "the button comes back");
  }

  await at("deletion-again").fire("click");
  assert.equal(at("deletion-phone-step").hidden, false);
  assert.equal(status.hidden, true);
});
