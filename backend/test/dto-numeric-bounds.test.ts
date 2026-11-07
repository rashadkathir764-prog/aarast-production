import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { test } from 'node:test';

// RA-BE-14: an integer field with no upper bound reached PostgreSQL's int4
// column as 3000000000 (an unclassified "out of range" error) or Prisma as
// 1e20 (a validation error): both a 500, which the phone's queue retries as a
// passing fault. Every numeric field of a request DTO carries an upper bound,
// so an out-of-range number is a 400 from validation, never the database's.

const SOURCE = join(__dirname, '..', 'src');

function dtoFiles(directory: string): string[] {
  return readdirSync(directory).flatMap((name) => {
    const path = join(directory, name);
    if (statSync(path).isDirectory()) return dtoFiles(path);
    return name.endsWith('.dto.ts') ? [path] : [];
  });
}

/** Each property with the decorators written above it. */
function decoratedProperties(source: string): { name: string; decorators: string }[] {
  const properties: { name: string; decorators: string }[] = [];
  let decorators: string[] = [];
  for (const line of source.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (trimmed.startsWith('@')) {
      decorators.push(trimmed);
      continue;
    }
    const property = /^(?:readonly\s+)?([A-Za-z_][A-Za-z0-9_]*)[?!]?\s*:/.exec(trimmed);
    if (property && decorators.length > 0) {
      properties.push({ name: property[1], decorators: decorators.join(' ') });
    }
    if (trimmed && !trimmed.startsWith('//') && !trimmed.startsWith('*') && !trimmed.startsWith('/*')) {
      decorators = [];
    }
  }
  return properties;
}

test('the scan finds the numeric fields it guards', () => {
  const numeric = dtoFiles(SOURCE).flatMap((file) =>
    decoratedProperties(readFileSync(file, 'utf8')).filter((p) => /@Is(Int|Number)\(/.test(p.decorators)),
  );
  assert.ok(numeric.length >= 20, `expected the request DTOs' numeric fields, found ${numeric.length}`);
});

// Compared in memory only (`!==` against the member's version), never sent
// to the database, so a huge value is a 409; and the file is byte-pinned by
// the R7 relocation proof.
const COMPARED_IN_MEMORY_ONLY = new Set([
  'modules/collaboration/api/dto/leave-plan.dto.ts: expectedAuthorityVersion',
]);

test('every numeric field of a request DTO has a lower and an upper bound', () => {
  const unbounded = dtoFiles(SOURCE).flatMap((file) =>
    decoratedProperties(readFileSync(file, 'utf8'))
      .filter(
        (p) =>
          /@Is(Int|Number)\(/.test(p.decorators) &&
          !(/@Min\(/.test(p.decorators) && /@Max\(/.test(p.decorators)),
      )
      .map((p) => `${relative(SOURCE, file).replace(/\\/g, '/')}: ${p.name}`)
      .filter((field) => !COMPARED_IN_MEMORY_ONLY.has(field)),
  );
  assert.deepEqual(unbounded, []);
});

test('the written exception is still a real field', () => {
  for (const field of COMPARED_IN_MEMORY_ONLY) {
    const [file, name] = field.split(': ');
    const source = readFileSync(join(SOURCE, file), 'utf8');
    assert.ok(
      decoratedProperties(source).some((p) => p.name === name && /@IsInt\(/.test(p.decorators)),
      `${field} no longer exists: drop it from the exception`,
    );
  }
});
