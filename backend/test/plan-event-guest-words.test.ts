import assert from "node:assert/strict";
import { test } from "node:test";
import type { PlanEventType } from "@prisma/client";
import {
  planEventLabel,
  planEventNaming,
} from "../src/modules/guests/domain/invitation-card";

// Batch 5 note (D55): in a bride's plan the phone names the groom's night
// and afternoon in her words, «الحفلة» and «النسمة» (`PlanEventType.label`),
// while the server's guest texts, the guest's page and the owner's notice
// of a reply still said «السمرة» and «المقيل». The server names them as the
// phone does. Where another occasion of her plan is already called by that
// word (her own «الحفلة» or «النسمة», or one the couple titled so), the
// groom's night or afternoon keeps its kind's word: two occasions are never
// told to a guest by the same name. (The date cannot tell them apart: an
// occasion may have none, or the same day.)

type Event = { type: PlanEventType; title: string | null };
const event = (type: PlanEventType, title: string | null = null): Event => ({ type, title });

function labels(persona: "GROOM" | "BRIDE" | "HELPER" | null, events: Event[]) {
  const naming = planEventNaming(persona, events);
  return events.map((item) => planEventLabel(item, naming));
}

test("a bride's plan names the groom's night and afternoon in her words", () => {
  assert.deepEqual(
    labels("BRIDE", [event("WEDDING"), event("SAMRA"), event("MAQEEL"), event("LUNCH")]),
    ["العرس", "الحفلة", "النسمة", "الغداء"],
  );
});

test("the groom's plan, and a plan of no side, keep his words", () => {
  for (const persona of ["GROOM", "HELPER", null] as const) {
    assert.deepEqual(labels(persona, [event("SAMRA"), event("MAQEEL"), event("HAFLA")]), [
      "السمرة",
      "المقيل",
      "الحفلة",
    ]);
  }
});

test("a title the couple gave is the occasion's name in any plan", () => {
  assert.deepEqual(labels("BRIDE", [event("SAMRA", " سهرة البنات "), event("CUSTOM")]), [
    "سهرة البنات",
    "مناسبة",
  ]);
});

test("a bride's plan holding her own «الحفلة» or «النسمة» keeps the kind's word for his", () => {
  assert.deepEqual(
    labels("BRIDE", [event("SAMRA"), event("HAFLA"), event("MAQEEL"), event("NASHMA")]),
    ["السمرة", "الحفلة", "المقيل", "النسمة"],
  );
  // Only the one whose word is taken.
  assert.deepEqual(labels("BRIDE", [event("SAMRA"), event("HAFLA"), event("MAQEEL")]), [
    "السمرة",
    "الحفلة",
    "النسمة",
  ]);
  // An occasion the couple called «الحفلة» takes it too.
  assert.deepEqual(labels("BRIDE", [event("SAMRA"), event("CUSTOM", "الحفلة")]), [
    "السمرة",
    "الحفلة",
  ]);
  // A «الحفلة» the couple named otherwise does not.
  assert.deepEqual(labels("BRIDE", [event("SAMRA"), event("HAFLA", "ليلة الحناء")]), [
    "الحفلة",
    "ليلة الحناء",
  ]);
});
