import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { PUSH_COPY } from "../src/shared-kernel/copy/push.ar";

// D129 (docs/project/LANGUAGE.md): the server's words have one source,
// src/shared-kernel/copy. These hold it: every catalog word keeps the
// language's rules, and the Arabic still typed elsewhere in src only goes
// down, each moved module lowering the number in the same change.

const BANNED = [
  "الحين", "اللي", "ايش", "إيش", "فين", "مش", "مو", "تشتي", "تبي", "عشان",
  "لسا", "بكرة", "برّا", "الجاي", "كمان", "شوي", "بعدين", "لين", "مين",
  "يرجى", "الرجاء", "تعذّر", "تعذر",
];

/** The Arabic string literals in src outside the catalog. */
const LITERALS_LEFT = 1030;

function catalogWords(): Array<[string, string]> {
  const words: Array<[string, string]> = [];
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

test("every catalog word keeps the language's rules", () => {
  const problems: string[] = [];
  for (const [key, text] of catalogWords()) {
    for (const word of BANNED) {
      if (new RegExp(`(^|[^\\u0600-\\u06FF])${word}($|[^\\u0600-\\u06FF])`, "u").test(text)) {
        problems.push(`${key}: «${word}»`);
      }
    }
    if (/[A-Za-z]/u.test(text)) problems.push(`${key}: Latin letters`);
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
