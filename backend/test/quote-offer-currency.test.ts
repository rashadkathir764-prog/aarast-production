import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import {
  currencyNameAr,
  quoteOfferCurrencyMismatch,
} from "../src/marketplace/quote-offer-currency";

// G19: one currency per plan. The refusal is a stable code with Arabic words
// for whoever reads it, not an English detail.
test("a currency refusal names the plan's currency to the provider and the customer", () => {
  const provider = quoteOfferCurrencyMismatch("yer", "provider");
  assert.ok(provider instanceof BadRequestException);
  assert.deepEqual(provider.getResponse(), {
    code: "QUOTE_OFFER_CURRENCY_MISMATCH",
    message: "خطة هذا العرس بـالريال اليمني، فأرسل عرضك بـالريال اليمني.",
    planCurrency: "YER",
  });
  const customer = quoteOfferCurrencyMismatch("SAR", "customer")
    .getResponse() as { message: string; code: string };
  assert.equal(customer.code, "QUOTE_OFFER_CURRENCY_MISMATCH");
  assert.equal(
    customer.message,
    "هذا العرض بعملة غير عملة خطتك (الريال السعودي). اطلب من المزود يرسله بـالريال السعودي.",
  );
  assert.equal(currencyNameAr("usd"), "الدولار");
  assert.equal(currencyNameAr("EUR"), "EUR");
});
