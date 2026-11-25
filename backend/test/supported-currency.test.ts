import "reflect-metadata";

import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { BadRequestException, ValidationPipe } from "@nestjs/common";
import { plainToInstance } from "class-transformer";
import { getMetadataStorage, validate } from "class-validator";
import {
  SUPPORTED_CURRENCIES,
  UNSUPPORTED_CURRENCY,
} from "../src/shared-kernel/money/currency";
import { CreateWeddingPlanDto } from "../src/wedding-plans/dto/create-wedding-plan.dto";

// RA-BE-149 (D124): a plan's, a budget's, a price's or an offer's currency
// was free text (at most 8 characters). It is one of the currencies the
// product offers: the phone's plan and budget choices (`weddingCurrencyOptions`:
// ريال يمني، ريال سعودي، دولار أمريكي), which an offer must match (it is in its
// plan's currency). Anything else is a 400 that names UNSUPPORTED_CURRENCY.

const srcRoot = path.join(__dirname, "..", "src");

function dtoClasses(): Function[] {
  const files: string[] = [];
  const walk = (dir: string) => {
    for (const name of readdirSync(dir)) {
      const full = path.join(dir, name);
      if (statSync(full).isDirectory()) walk(full);
      else if (/\.dto\.ts$/u.test(name)) files.push(full);
    }
  };
  walk(srcRoot);
  const classes = new Set<Function>();
  for (const file of files) {
    for (const value of Object.values(require(file) as Record<string, unknown>)) {
      if (typeof value === "function") classes.add(value);
    }
  }
  return [...classes];
}

function currencyRules(target: Function) {
  return getMetadataStorage()
    .getTargetValidationMetadatas(target, "", true, false)
    .filter((metadata) => metadata.propertyName === "currency");
}

test("RA-BE-149: the product's currencies, in one list", () => {
  assert.deepEqual([...SUPPORTED_CURRENCIES], ["YER", "SAR", "USD"]);
});

test("RA-BE-149: every request form that takes a currency checks it against the one list", async () => {
  const forms = dtoClasses().filter((target) => currencyRules(target).length > 0);
  assert.deepEqual(
    forms.map((form) => form.name).sort(),
    [
      "AdminServiceDto",
      "ApplyProviderServiceDto",
      "CompleteOnboardingDto",
      "CreateProviderPackageDto",
      "CreateProviderServiceDto",
      "CreateQuoteOfferDto",
      "CreateWeddingPlanDto",
      // The phone's local plan, sent as onboarding's form (it extends it).
      "ImportLocalPlanDto",
      "ReplaceMoneyBudgetDto",
      "UpdateProviderPackageDto",
      "UpdateProviderServiceDto",
      "UpdateQuoteOfferDto",
    ],
  );
  for (const form of forms) {
    const isIn = currencyRules(form).find((rule) => rule.name === "isIn");
    assert.ok(isIn, `${form.name}.currency is checked against a list`);
    assert.deepEqual(isIn.constraints, [SUPPORTED_CURRENCIES], `${form.name}: the one list`);

    for (const currency of SUPPORTED_CURRENCIES) {
      const errors = await validate(plainToInstance(form as any, { currency }) as object);
      assert.equal(
        errors.some((error) => error.property === "currency"),
        false,
        `${form.name} takes ${currency}`,
      );
    }
    for (const currency of ["EUR", "yer", "YR", "ريال", "YER "]) {
      const errors = await validate(plainToInstance(form as any, { currency }) as object);
      const error = errors.find((item) => item.property === "currency");
      assert.ok(error, `${form.name} refuses ${JSON.stringify(currency)}`);
      assert.match(
        Object.values(error.constraints ?? {}).join(" "),
        new RegExp(`^${UNSUPPORTED_CURRENCY}\\b`, "u"),
      );
    }
  }
});

test("RA-BE-149: an unknown currency is a 400 that names its code", async () => {
  const pipe = new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true });
  await assert.rejects(
    () =>
      pipe.transform(
        { title: "عرسنا", currency: "EUR" },
        { type: "body", metatype: CreateWeddingPlanDto },
      ),
    (error: unknown) => {
      assert.ok(error instanceof BadRequestException);
      assert.equal(error.getStatus(), 400);
      const body = error.getResponse() as { message: string[] };
      assert.ok(body.message.some((line) => line.startsWith(`${UNSUPPORTED_CURRENCY}:`)));
      return true;
    },
  );
  const accepted = await pipe.transform(
    { title: "عرسنا", currency: "SAR" },
    { type: "body", metatype: CreateWeddingPlanDto },
  );
  assert.equal(accepted.currency, "SAR");
});

test("RA-BE-149: no saved row keeps a currency the server refuses, and none is changed to get there", () => {
  // A row in another currency would be stuck: each later save repeats it and
  // gets the 400, and a phone's queued change waits to be deleted (D85).
  const sql = readFileSync(
    path.join(process.cwd(), "prisma/migrations/20261125200000_supported_currencies/migration.sql"),
    "utf8",
  ).replace(/\r\n/g, "\n");
  const list = SUPPORTED_CURRENCIES.map((code) => `'${code}'`).join(", ");
  const tables = ["WeddingPlan", "ProviderService", "ProviderPackage", "QuoteOffer", "QuoteOfferVersion"];
  const check = sql.indexOf("RAISE EXCEPTION");
  assert.ok(check > 0, "rows outside the list stop the migration, named");
  for (const table of tables) {
    assert.ok(sql.indexOf(`('${table}')`) < check, `${table} is checked`);
    const constraint = sql.indexOf(`ADD CONSTRAINT "${table}_currency_supported" CHECK ("currency" IN (${list}))`);
    assert.ok(constraint > check, `${table} is held to the list after its check`);
  }
  assert.doesNotMatch(sql, /^\s*(UPDATE|DELETE)\b/mu, "no amount or currency is rewritten");
});
