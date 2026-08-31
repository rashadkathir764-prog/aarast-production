import { describe, expect, it } from 'vitest';
import { safeAdminReturnPath } from './admin-return-path';

describe('safeAdminReturnPath', () => {
  it.each([
    '/',
    '/providers',
    '/providers/example-provider-id',
    '/providers/applications/example_application-1',
  ])('keeps a local admin path: %s', (path) => {
    expect(safeAdminReturnPath(path)).toBe(path);
  });

  it.each([
    undefined,
    null,
    '',
    'providers',
    'https://attacker.example',
    '//attacker.example',
    String.raw`/\attacker.example`,
    String.raw`\attacker.example`,
    '/%5c%5cattacker.example',
    '/%2f%2fattacker.example',
    '/providers?next=//attacker.example',
    '/providers#//attacker.example',
    '/providers\nattacker.example',
  ])('falls back to the dashboard for an unsafe return target: %s', (path) => {
    expect(safeAdminReturnPath(path)).toBe('/');
  });
});
