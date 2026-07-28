const localAdminPath = /^\/(?:[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_-]+)*)?$/;

/**
 * Login return targets originate from router state, but the browser pathname
 * can still be attacker-controlled. Keep redirects inside the admin SPA and
 * reject network-path, backslash, encoded-separator, query, and hash forms.
 */
export function safeAdminReturnPath(value: unknown): string {
  return typeof value === 'string' && localAdminPath.test(value) ? value : '/';
}
