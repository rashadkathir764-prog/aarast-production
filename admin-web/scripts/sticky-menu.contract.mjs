import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

// RA-AD-20: the desk's side menu sticks to the window while a long page
// scrolls. `overflow-x: hidden` on body made body a scroll box of its own
// (its `overflow-y` then computes to `auto`); the menu stuck to that box,
// which never scrolls, and went up with the rows. Measured in Chrome: after
// scrolling 2000 the menu's top was at -2000, and at 0 with `clip`.
//
// The unit tests cannot see it (they load no stylesheet), so the styles
// themselves are read: nothing between the window and the menu may be a
// scroll box.

const here = path.dirname(fileURLToPath(import.meta.url));
const css = ['globals.css', 'desk.css']
  .map((file) => readFileSync(path.join(here, '../src/styles', file), 'utf8'))
  .join('\n');

function blocksOf(selector) {
  const escaped = selector.replace(/[.#]/g, '\\$&');
  return [...css.matchAll(new RegExp(`(?:^|[},])\\s*${escaped}\\s*\\{([^}]*)\\}`, 'g'))].map(
    (match) => match[1],
  );
}

test('the side menu sticks', () => {
  assert.match(css, /\.desk-side\s*\{[^}]*position:\s*sticky/);
});

for (const selector of ['body', '#root', '.desk-shell']) {
  test(`${selector} is no scroll box between the window and the side menu`, () => {
    const blocks = blocksOf(selector);
    assert.ok(blocks.length > 0, `no rule found for ${selector}`);
    for (const block of blocks) {
      assert.doesNotMatch(block, /overflow(-[xy])?\s*:\s*(hidden|auto|scroll)/);
    }
  });
}
