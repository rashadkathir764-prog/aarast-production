import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { getMetadataStorage } from 'class-validator';

// RA-BE-15: about a hundred text fields the app writes had no length at all;
// the only bound was the 100 KB request body, so one account could make
// every reader of a review, a provider's about or an offer download that.
// Every text field of every request form now states its bound: a length
// (`MaxCharacters` for what a person types, counted as the phone counts,
// RA-BE-16; `MaxLength` for codes) or a fixed shape that bounds it already.
// A new field without one fails here.

const srcRoot = path.join(__dirname, '..', 'src');

/** Rules that bound a string by themselves. */
const BOUNDING_RULES = new Set([
  'maxCharacters',
  'maxLength',
  'length',
  'isIn',
  'isEnum',
  'isUuid',
  'isUUID',
  'matches',
  'isDateString',
  'isIso8601',
  'isISO8601',
  'isEmail',
  'isUrl',
  'isURL',
  'isNumberString',
  'isMobilePhone',
  'isPhoneNumber',
  'isHexadecimal',
  'isBase64',
  'isJWT',
  'isMilitaryTime',
  'isBooleanString',
  // A password: bcrypt reads 72 bytes (max-utf8-bytes.decorator.ts).
  'maxUtf8Bytes',
]);

/**
 * Fields the server reads into another kind of value before any use, and
 * never keeps or shows as the text sent: a record's id (looked up; an
 * unknown one is refused), a page or a count, a status (read against its
 * list, as `parseReviewStatus`), a day or a time (parsed as a date), an
 * amount (parsed as money, `optionalMoneyAmount`), a yes/no filter, an
 * upload's key (looked up), and the words of a search (sent in the address
 * only, which Node stops at 16 KB). Their length has no reader.
 */
const PARSED_FIELD =
  /^(?:id|[a-z][A-Za-z]*Ids?|page|limit|search|status|state|from|to|eventDate|validUntil|dueDate|reminderAt|amount|price|basePrice|budgetMin|budgetMax|minPrice|maxPrice|reported|resubmitted|featured|key)$/u;

/**
 * Byte-pinned forms (R12B) that no route takes as they are: a guest and a
 * task are added through the forms that extend them and bound their text
 * (create-guest-with-events.dto.ts, create-plan-task.dto.ts); the local
 * plan's guests and tasks are bounded by `withinLength` in
 * wedding-plans.service.ts. The second test keeps a route from taking the
 * first two directly.
 */
const PINNED_BASE_FORMS = new Set([
  'CreateGuestDto',
  'CreateTaskDto',
  'ImportLocalGuestDto',
  'ImportLocalTaskDto',
]);

/**
 * Every file that can declare a request form: the `*.dto.ts` files and the
 * `dto/` folders, and any other file that uses class-validator. RA-BE-78:
 * the events' form is declared inside `plan-events.controller.ts`, and the
 * first version of this check, reading the dto files only, never saw it.
 */
function dtoFiles(directory: string): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(directory)) {
    const full = path.join(directory, entry);
    if (statSync(full).isDirectory()) {
      files.push(...dtoFiles(full));
    } else if (
      /\.dto\.ts$/u.test(entry) ||
      (/[\\/]dto[\\/]/u.test(full) && /\.ts$/u.test(entry)) ||
      (/\.ts$/u.test(entry) &&
        /from ['"]class-validator['"]/u.test(readFileSync(full, 'utf8')))
    ) {
      files.push(full);
    }
  }
  return files;
}

test('RA-BE-15: every text field of every request form states its bound', () => {
  const files = dtoFiles(srcRoot);
  assert.ok(files.length > 50, `found ${files.length} request forms`);
  const classes = new Set<Function>();
  for (const file of files) {
    for (const value of Object.values(require(file) as Record<string, unknown>)) {
      if (typeof value === 'function') classes.add(value);
    }
  }

  const storage = getMetadataStorage();
  const unbounded: string[] = [];
  let checked = 0;
  for (const target of classes) {
    if (PINNED_BASE_FORMS.has(target.name)) continue;
    const metadatas = storage.getTargetValidationMetadatas(
      target,
      '',
      true,
      false,
    );
    const rulesByProperty = new Map<string, Set<string>>();
    for (const metadata of metadatas) {
      const name = (metadata as { name?: string }).name;
      if (!name) continue;
      const rules = rulesByProperty.get(metadata.propertyName) ?? new Set<string>();
      rules.add(name);
      rulesByProperty.set(metadata.propertyName, rules);
    }
    for (const [property, rules] of rulesByProperty) {
      if (!rules.has('isString')) continue;
      if (PARSED_FIELD.test(property)) continue;
      checked += 1;
      if (![...rules].some((rule) => BOUNDING_RULES.has(rule))) {
        unbounded.push(`${target.name}.${property}`);
      }
    }
  }

  assert.ok(checked > 100, `checked ${checked} text fields`);
  assert.deepEqual(unbounded.sort(), []);
});

test("RA-BE-15: a package's features are a list of short lines, as the phone sends them", async () => {
  const { plainToInstance } = await import('class-transformer');
  const { validate } = await import('class-validator');
  const { CreateProviderPackageDto } = await import(
    '../src/provider-dashboard/dto/create-provider-package.dto'
  );
  const { UpdateProviderPackageDto } = await import(
    '../src/provider-dashboard/dto/update-provider-package.dto'
  );
  const refused = async (form: Function, items: unknown) =>
    (
      await validate(
        plainToInstance(form as new () => object, { title: 'باقة', items }),
      )
    ).some((error) => error.property === 'items');

  for (const form of [CreateProviderPackageDto, UpdateProviderPackageDto]) {
    assert.equal(await refused(form, ['تصوير', 'فيديو']), false);
    assert.equal(await refused(form, Array(50).fill('ميزة')), false);
    // 200 characters as read, 400 code units: its marks are not counted.
    assert.equal(await refused(form, ['مُ'.repeat(200)]), false);
    assert.equal(await refused(form, ['👨‍👩‍👧'.repeat(200)]), false);
    // Any JSON was stored and served as sent.
    assert.equal(await refused(form, { html: '<b>x</b>' }), true);
    assert.equal(await refused(form, [{ nested: true }]), true);
    assert.equal(await refused(form, Array(51).fill('ميزة')), true);
    assert.equal(await refused(form, ['ا'.repeat(201)]), true);
  }
});

function controllerFiles(directory: string): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(directory)) {
    const full = path.join(directory, entry);
    if (statSync(full).isDirectory()) files.push(...controllerFiles(full));
    else if (/\.controller\.ts$/u.test(entry)) files.push(full);
  }
  return files;
}

test('RA-BE-15: no route takes the pinned guest or task form, whose text is unbounded', () => {
  const files = controllerFiles(srcRoot);
  assert.ok(files.length > 20, `found ${files.length} controllers`);
  const taking = files.filter((file) =>
    /\b(?:CreateGuestDto|CreateTaskDto)\b/u.test(readFileSync(file, 'utf8')),
  );
  assert.deepEqual(taking, []);
});
