import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { PUSH_COPY } from "../src/shared-kernel/copy/push.ar";
import { NEXT_STEP_COPY } from "../src/shared-kernel/copy/next-steps.ar";
import { MONEY_WARNING_COPY } from "../src/shared-kernel/copy/money-warnings.ar";
import { dayCountWords } from "../src/shared-kernel/voice/day-words";

// D129 (docs/project/LANGUAGE.md): the server's words have one source,
// src/shared-kernel/copy. These hold it: every catalog word keeps the
// language's rules, and the Arabic still typed elsewhere in src only goes
// down, each moved module lowering the number in the same change.

const BANNED = [
  "الحين", "اللي", "ايش", "إيش", "فين", "مش", "مو", "تشتي", "تبي", "عشان",
  "لسا", "بكرة", "برّا", "الجاي", "كمان", "شوي", "بعدين", "لين", "مين",
  "يرجى", "الرجاء", "تعذّر", "تعذر",
  // The home's steps moved from these (LANGUAGE §6): «شوف» is «افتح» or
  // «اعرض», «برا» is «خارج», «لحاله» is «وحده», «بدري» is «مبكرًا».
  "شوف", "شوفي", "شوفه", "شوفيه", "برا", "لحاله", "بدري", "يبان", "يخلي",
  "الجاية", "اتفقتوا", "العروسة",
];

/**
 * The Arabic string literals in src outside the catalog. 1030 to 1028 on
 * 2026-11-26: the home's next steps moved to their own file and dropped an
 * unreachable line; the steps REFINEMENT_SPEC 2.1 added took their words
 * from the catalog (`next-steps.ar.ts`). 1028 to 954 the same day: every
 * word of the home's summary (the next steps, the setup chain, the money
 * warnings) moved to `next-steps.ar.ts` and `money-warnings.ar.ts`.
 */
const LITERALS_LEFT = 954;

/**
 * A sample argument for each kind a catalog line takes: a day's words, and
 * a count in each of Arabic's number categories (LANGUAGE §4.6).
 */
const SAMPLE_ARGUMENTS: unknown[] = ["غدًا", 1, 2, 3, 11, 100, 103];

/** Every word of a catalog, each form, each line with each sample argument. */
function wordsOf(name: string, catalog: unknown): Array<[string, string]> {
  const words: Array<[string, string]> = [];
  const add = (key: string, value: unknown) => {
    if (typeof value === "string") words.push([key, value]);
    else if (typeof value === "function") {
      for (const sample of SAMPLE_ARGUMENTS) add(key, value(sample));
    } else if (value && typeof value === "object") {
      for (const [inner, text] of Object.entries(value)) add(`${key}.${inner}`, text);
    }
  };
  add(name, catalog);
  return words;
}

function catalogWords(): Array<[string, string]> {
  const words: Array<[string, string]> = [
    ...wordsOf("next", NEXT_STEP_COPY),
    ...wordsOf("moneyWarning", MONEY_WARNING_COPY),
  ];
  for (const [key, value] of Object.entries(PUSH_COPY)) {
    const copies =
      typeof value === "function"
        ? [value(null), value("غدًا")]
        : [value];
    for (const copy of copies) {
      words.push([`${key}.title`, copy.title], [`${key}.body`, copy.body]);
    }
  }
  return words;
}

test("a count agrees with its noun by its last two digits (LANGUAGE §4.6)", () => {
  const offers = [1, 2, 3, 10, 11, 99, 100, 102, 103, 111].map((count) =>
    NEXT_STEP_COPY.quotesReceived.title(count),
  );
  assert.deepEqual(offers, [
    "وصلك عرض سعر",
    "وصلك عرضان",
    "وصلك 3 عروض",
    "وصلك 10 عروض",
    "وصلك 11 عرضًا",
    "وصلك 99 عرضًا",
    "وصلك 100 عرض",
    "وصلك 102 عرض",
    "وصلك 103 عروض",
    "وصلك 111 عرضًا",
  ]);
  assert.deepEqual(
    [1, 2, 3, 11].map((count) => MONEY_WARNING_COPY.paymentsOverdue(count)),
    [
      "عندك دفعة متأخرة.",
      "عندك دفعتان متأخرتان.",
      "عندك 3 دفعات متأخرة.",
      "عندك 11 دفعة متأخرة.",
    ],
  );
  assert.equal(dayCountWords(103), "103 أيام");
  assert.equal(dayCountWords(100), "100 يوم");
});

test("every catalog word keeps the language's rules", () => {
  const problems: string[] = [];
  for (const [key, text] of catalogWords()) {
    for (const word of BANNED) {
      if (new RegExp(`(^|[^\\u0600-\\u06FF])${word}($|[^\\u0600-\\u06FF])`, "u").test(text)) {
        problems.push(`${key}: «${word}»`);
      }
    }
    if (/[A-Za-z]/u.test(text)) problems.push(`${key}: Latin letters`);
    // LANGUAGE §3: «المزوّد» always carries its shadda.
    if (/مزود/u.test(text)) problems.push(`${key}: «مزود» without its shadda`);
    if (/[٠-٩]/u.test(text)) problems.push(`${key}: Indic digits`);
    if (/ر\.س|SAR|USD/u.test(text)) problems.push(`${key}: another currency`);
  }
  assert.deepEqual(problems, []);
});

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const full = path.join(dir, name);
    return statSync(full).isDirectory()
      ? sourceFiles(full)
      : full.endsWith(".ts")
        ? [full]
        : [];
  });
}

/** Arabic literals ('…', "…", `…`) in src, outside the catalog, not in comments. */
export function arabicLiteralsLeft(src: string): number {
  const literal = /'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"|`(?:[^`\\]|\\.)*`/gu;
  let count = 0;
  for (const file of sourceFiles(src)) {
    if (file.includes(`${path.sep}shared-kernel${path.sep}copy${path.sep}`)) continue;
    for (const line of readFileSync(file, "utf8").split(/\r?\n/u)) {
      const code = line.trimStart();
      if (code.startsWith("//") || code.startsWith("*") || code.startsWith("/*")) continue;
      for (const match of code.matchAll(literal)) {
        if (/[؀-ۿ]/u.test(match[0])) count += 1;
      }
    }
  }
  return count;
}

test("the Arabic still typed outside the catalog only goes down", () => {
  const count = arabicLiteralsLeft(path.join(__dirname, "..", "src"));
  assert.ok(count <= LITERALS_LEFT, `new words go in src/shared-kernel/copy, not in the code (${count})`);
  assert.equal(count, LITERALS_LEFT, `fewer are left: lower LITERALS_LEFT to ${count}`);
});
