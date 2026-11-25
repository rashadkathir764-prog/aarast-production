import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { weddingLocationResponse } from "../src/modules/planning/public/wedding-location";

// RA-MO-335 (rest): «أمانة العاصمة» is the capital, Sana'a; a plan in it
// with its city typed «صنعاء» was labelled «أمانة العاصمة - صنعاء» while
// other places said «صنعاء». The two are one place, said once: «صنعاء».

test("RA-MO-335: the capital and its city are one place, said «صنعاء»", () => {
  const location = weddingLocationResponse({
    governorate: "أمانة العاصمة",
    city: "صنعاء",
    district: "حدة",
  });
  assert.equal(location?.shortLabel, "صنعاء");
  assert.equal(location?.mediumLabel, "صنعاء - حدة");
  assert.equal(location?.fullLabel, "صنعاء - حدة");
  // The stored facts stay as given.
  assert.equal(location?.governorate, "أمانة العاصمة");
  assert.equal(location?.city, "صنعاء");
});

test("RA-MO-335: the capital with a district of its own keeps its name", () => {
  const location = weddingLocationResponse({ governorate: "أمانة العاصمة", city: "السبعين" });
  assert.equal(location?.shortLabel, "أمانة العاصمة - السبعين");
  const elsewhere = weddingLocationResponse({ governorate: "عدن", city: "المنصورة" });
  assert.equal(elsewhere?.shortLabel, "عدن - المنصورة");
});
