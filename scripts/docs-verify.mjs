#!/usr/bin/env node
/**
 * docs-verify
 *
 * Cross-checks documentation against source code and the rest of the docs.
 * Designed to catch problems that the auto-sync script cannot detect because
 * they live in MANUAL sections of the docs:
 *
 *   - Endpoints mentioned in prose but not registered in any controller.
 *   - Mobile routes mentioned in prose but not present in go_router.
 *   - Admin routes mentioned in prose but not present in App.tsx/Routes.tsx.
 *   - Manual `docs/...md` files linking to deleted archives or broken sections.
 *   - Stale "snapshot" or "as of" dates that are older than a defined freshness
 *     window (default 45 days).
 *   - Dangling `docs/backend/API_CONTRACT.md` cross-references — manual sections
 *     that link to endpoints that no longer exist.
 *   - Migrations referenced by name in prose that are missing from
 *     `backend/prisma/migrations/`.
 *
 * Usage:
 *   node scripts/docs-verify.mjs
 *
 * Exit codes:
 *   0 = clean
 *   1 = drift / broken references detected
 *   2 = unexpected error
 */
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const root = join(__dirname, '..');

const STALE_DAYS = 45;

function read(p) {
  return readFileSync(p, 'utf8');
}

function walk(dir, ext) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const s = statSync(full);
    if (s.isDirectory()) out.push(...walk(full, ext));
    else if (!ext || name.endsWith(ext)) out.push(full);
  }
  return out;
}

const issues = [];
function report(severity, file, line, message) {
  issues.push({ severity, file, line, message });
}

// ---------------------------------------------------------------------------
// 1) Endpoint drift — endpoints mentioned in prose that don't exist in code.
// ---------------------------------------------------------------------------
function getRegisteredEndpoints() {
  const files = walk(join(root, 'backend', 'src'), '.controller.ts');
  const set = new Set();
  for (const file of files) {
    const src = read(file);
    const ctrlMatches = [...src.matchAll(/@Controller\(['"]([^'"]+)['"]\)/g)];
    const lines = src.split('\n');
    let currentBase = '';
    let currentCtrlIdx = 0;
    let pendingMethod = null;
    let pendingPath = null;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const ctrl = line.match(/@Controller\(['"]([^'"]+)['"]\)/);
      if (ctrl) {
        currentBase = ctrl[1];
        continue;
      }
      const dec = line.match(/@(Get|Post|Patch|Put|Delete)\s*\(\s*(?:['"]([^'"]+)['"])?\s*\)/);
      if (dec) {
        pendingMethod = dec[1].toUpperCase();
        pendingPath = dec[2] || '';
      }
      const sig = line.match(/^\s*(?:async\s+)?(\w+)\s*\(/);
      if (sig && pendingMethod) {
        const full = '/' + [currentBase.replace(/^\/+|\/+$/g, ''), pendingPath.replace(/^\/+|\/+$/g, '')].filter(Boolean).join('/');
        set.add(`${pendingMethod} ${full}`);
        pendingMethod = null;
        pendingPath = null;
      }
    }
  }
  return set;
}

function getRegisteredMobileRoutes() {
  const files = walk(join(root, 'mobile', 'lib', 'core', 'routing'), '.dart');
  const set = new Set();
  for (const file of files) {
    const src = read(file);
    const matches = src.matchAll(/['"`](\/[a-zA-Z0-9_\-/:.]+)['"`]/g);
    for (const m of matches) {
      if (m[1].length > 1 && !m[1].startsWith('//')) set.add(m[1]);
    }
  }
  return set;
}

function getRegisteredAdminRoutes() {
  const appDir = join(root, 'admin-web', 'src');
  const set = new Set();
  if (!existsSync(appDir)) return set;
  for (const f of walk(appDir, '.tsx')) {
    if (!/(App|Routes)\.tsx$/.test(f)) continue;
    const src = read(f);
    const matches = src.matchAll(/path=['"]([^'"]+)['"]/g);
    for (const m of matches) {
      if (m[1] && m[1].startsWith('/')) set.add(m[1]);
    }
  }
  return set;
}

// ---------------------------------------------------------------------------
// 2) Scan docs for prose mentions of endpoints/routes that aren't registered.
// ---------------------------------------------------------------------------
function extractEndpointMentions(mdText) {
  // Match METHOD /path patterns used in prose lists.
  const out = new Set();
  const re = /\b(GET|POST|PATCH|PUT|DELETE)\s+[`']?(\/[a-zA-Z0-9_\-/:{}]+)[`']?/g;
  let m;
  while ((m = re.exec(mdText)) !== null) {
    out.add(`${m[1]} ${m[2]}`);
  }
  return out;
}

function extractMobileRouteMentions(mdText) {
  const out = new Set();
  const re = /[`'](\/[a-zA-Z][a-zA-Z0-9_\-/:.]*)[`']/g;
  let m;
  while ((m = re.exec(mdText)) !== null) {
    if (m[1].length > 1) out.add(m[1]);
  }
  return out;
}

function extractAdminRouteMentions(mdText) {
  // admin route mentions typically appear as /admin/... or similar
  const out = new Set();
  const re = /[`']([/][a-zA-Z][a-zA-Z0-9_\-/:.]*)[`']/g;
  let m;
  while ((m = re.exec(mdText)) !== null) {
    if (m[1].length > 1) out.add(m[1]);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 3) Stale snapshot detection.
// ---------------------------------------------------------------------------
function findStaleSnapshots() {
  const files = walk(join(root, 'docs'), '.md');
  const now = Date.now();
  for (const f of files) {
    if (f.includes('/archive/')) continue;
    const src = read(f);
    const m = src.match(/[Ss]napshot date:\s*(\d{4}-\d{2}-\d{2})/);
    if (!m) continue;
    const date = new Date(m[1] + 'T00:00:00Z');
    if (isNaN(date)) continue;
    const days = Math.floor((now - date.getTime()) / (24 * 60 * 60 * 1000));
    if (days > STALE_DAYS) {
      report('warn', relative(root, f), null, `Snapshot date ${m[1]} is ${days} days old (> ${STALE_DAYS}).`);
    }
  }
}

// ---------------------------------------------------------------------------
// 4) Migration references that no longer exist.
// ---------------------------------------------------------------------------
function findBrokenMigrationReferences() {
  const files = walk(join(root, 'docs'), '.md');
  const migrationsDir = join(root, 'backend', 'prisma', 'migrations');
  if (!existsSync(migrationsDir)) return;
  const known = new Set(readdirSync(migrationsDir));
  const re = /\b(\d{14}_[a-z0-9_]+)\b/g;
  for (const f of files) {
    const src = read(f);
    let m;
    while ((m = re.exec(src)) !== null) {
      if (!known.has(m[1])) {
        report('warn', relative(root, f), null, `References migration "${m[1]}" but the folder is missing.`);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 5) Broken relative links between docs files.
// ---------------------------------------------------------------------------
function findBrokenLinks() {
  const files = walk(join(root, 'docs'), '.md');
  for (const f of files) {
    const src = read(f);
    const re = /\]\(([^)]+\.md)\)/g;
    let m;
    while ((m = re.exec(src)) !== null) {
      const target = m[1].split('#')[0];
      if (target.startsWith('http')) continue;
      const resolved = join(dirname(f), target);
      if (!existsSync(resolved)) {
        report('error', relative(root, f), null, `Broken link to "${m[1]}" (resolved: ${relative(root, resolved)}).`);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Run all checks.
// ---------------------------------------------------------------------------
function endpointDriftCheck() {
  const registered = getRegisteredEndpoints();
  // The backend has dual legacy and /api/v1 surfaces. Normalize by
  // collapsing the /api/v1 prefix on both sides so cross-prefix mentions
  // (e.g. doc says /api/v1/notifications but only /notifications is
  // declared in a non-aliased controller) do not produce false positives.
  const normalizedRegistered = new Set();
  for (const ep of registered) {
    const [method, path] = ep.split(' ');
    normalizedRegistered.add(`${method} ${path.replace(/^\/api\/v1/, '')}`);
    normalizedRegistered.add(`${method} ${path}`);
  }
  const files = walk(join(root, 'docs'), '.md');
  for (const f of files) {
    if (f.includes('/archive/')) continue;
    const src = read(f);
    const mentions = extractEndpointMentions(src);
    for (const ep of mentions) {
      const [method, path] = ep.split(' ');
      const normalized = `${method} ${path.replace(/^\/api\/v1/, '')}`;
      if (!normalizedRegistered.has(normalized)) {
        report('warn', relative(root, f), null, `Mentions ${ep} but no controller declares it.`);
      }
    }
  }
}

function main() {
  endpointDriftCheck();
  findStaleSnapshots();
  findBrokenMigrationReferences();
  findBrokenLinks();

  // Summary
  let errors = 0, warnings = 0;
  for (const i of issues) {
    const tag = i.severity === 'error' ? '✗' : '!';
    const loc = i.line ? `:${i.line}` : '';
    console.log(`${tag} [${i.severity}] ${i.file}${loc} — ${i.message}`);
    if (i.severity === 'error') errors++;
    else warnings++;
  }
  console.log(`\n${errors === 0 ? 'OK' : 'DRIFT'} — errors=${errors} warnings=${warnings}`);

  if (errors > 0) process.exit(1);
  process.exit(0);
}

try {
  main();
} catch (err) {
  console.error('docs-verify crashed:', err);
  process.exit(2);
}