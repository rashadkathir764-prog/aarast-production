import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { extname, join, relative } from 'node:path';
import { test } from 'node:test';

const { futureDay } = require('../scripts/smoke/smoke-utils.js') as {
  futureDay: (daysFromNow: number, now?: Date) => string;
};

const backendRoot = join(__dirname, '..');
const smokeRoot = join(backendRoot, 'scripts', 'smoke');

function smokeScriptFiles(directory: string): string[] {
  return readdirSync(directory).flatMap((name) => {
    const path = join(directory, name);
    if (statSync(path).isDirectory()) return smokeScriptFiles(path);
    return ['.ts', '.js'].includes(extname(name)) ? [path] : [];
  });
}

// Every YYYY-MM-DD literal that falls after `today`, as "line: date" pairs.
function futureLiteralDates(text: string, today: string): string[] {
  const found: string[] = [];
  text.split('\n').forEach((line, index) => {
    for (const match of line.matchAll(/20\d\d-\d\d-\d\d/g)) {
      if (match[0] > today) found.push(`${index + 1}: ${match[0]}`);
    }
  });
  return found;
}

test('futureDay returns the Sana\'a calendar day, UTC+3 with no daylight saving', () => {
  // 21:30 UTC on 24 Nov is 00:30 on 25 Nov in Sana'a.
  const lateUtc = new Date('2026-11-24T21:30:00Z');
  assert.equal(futureDay(0, lateUtc), '2026-11-25');
  assert.equal(futureDay(1, lateUtc), '2026-11-26');
  assert.equal(futureDay(-1, lateUtc), '2026-11-24');

  // 20:30 UTC on 24 Nov is still 23:30 on 24 Nov in Sana'a.
  assert.equal(futureDay(0, new Date('2026-11-24T20:30:00Z')), '2026-11-24');

  // Month and year boundaries: 24 Nov + 40 days is 3 Jan 2027.
  assert.equal(futureDay(40, new Date('2026-11-24T12:00:00Z')), '2027-01-03');
});

test('futureDay defaults to the current clock and returns YYYY-MM-DD', () => {
  assert.match(futureDay(7), /^\d{4}-\d{2}-\d{2}$/);
});

test('the future-literal scanner reports only dates after today', () => {
  assert.deepEqual(
    futureLiteralDates('a 2026-11-24 b\nc 2027-02-18T00:00:00Z d 2026-02-30', '2026-11-24'),
    ['2: 2027-02-18'],
  );
});

test('smoke scripts hold no literal date later than today', () => {
  const today = futureDay(0);
  const offenders = smokeScriptFiles(smokeRoot).flatMap((file) =>
    futureLiteralDates(readFileSync(file, 'utf8'), today).map(
      (entry) => `${relative(backendRoot, file)}:${entry}`,
    ),
  );
  assert.deepEqual(offenders, []);
});
