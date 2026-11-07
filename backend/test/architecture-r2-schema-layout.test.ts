import assert from 'node:assert/strict';
import {
  existsSync,
  readFileSync,
  readdirSync,
  statSync,
} from 'node:fs';
import path from 'node:path';
import test from 'node:test';

type Owner = {
  owner: string;
  file: string;
  models: string[];
  enums: string[];
};

type Manifest = {
  schemaVersion: number;
  splitBaseRevision: string;
  baseFile: string;
  owners: Owner[];
  modelOrder: string[];
};

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(backendRoot, '..');
const schemaRoot = path.join(backendRoot, 'prisma', 'schema');
const retiredSchema = path.join(backendRoot, 'prisma', 'schema.prisma');
const manifestPath = path.join(backendRoot, 'architecture', 'prisma-schema-layout.json');
const registryPath = path.join(backendRoot, 'architecture', 'ownership-registry.json');
const expectedFiles = [
  '_base.prisma',
  'backoffice.prisma',
  'catalog.prisma',
  'collaboration.prisma',
  'finance.prisma',
  'guests.prisma',
  'identity.prisma',
  'marketplace.prisma',
  'media.prisma',
  'messaging.prisma',
  'notifications.prisma',
  'planning.prisma',
  'platform.prisma',
  'tasks.prisma',
];

function readJson<T>(file: string) {
  return JSON.parse(readFileSync(file, 'utf8')) as T;
}

function declarations(text: string, keyword: 'model' | 'enum') {
  return [...text.matchAll(new RegExp(`^${keyword}\\s+([A-Za-z][A-Za-z0-9_]*)\\s*\\{`, 'gm'))]
    .map((match) => match[1]);
}

function listFiles(root: string): string[] {
  const result: string[] = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const absolute = path.join(root, entry.name);
    if (entry.isDirectory()) {
      result.push(...listFiles(absolute));
    } else if (entry.isFile()) {
      result.push(absolute);
    }
  }
  return result;
}

test('the retired schema is absent and the native folder has exactly the manifest 14 files', () => {
  assert.equal(existsSync(retiredSchema), false, 'retired prisma/schema.prisma must be absent');
  assert.equal(existsSync(schemaRoot), true, 'native prisma/schema folder must exist');
  assert.equal(statSync(schemaRoot).isDirectory(), true);
  assert.deepEqual(readdirSync(schemaRoot).sort(), expectedFiles);

  const manifest = readJson<Manifest>(manifestPath);
  assert.deepEqual([manifest.baseFile, ...manifest.owners.map((entry) => entry.file)].sort(), expectedFiles);
});

test('the base file contains only generator and datasource while owner declarations are unique and exact', () => {
  const manifest = readJson<Manifest>(manifestPath);
  const registry = readJson<{ owners: Record<string, string[]> }>(registryPath);
  const base = readFileSync(path.join(schemaRoot, manifest.baseFile), 'utf8');
  assert.equal(declarations(base, 'model').length, 0);
  assert.equal(declarations(base, 'enum').length, 0);
  assert.equal((base.match(/^generator\s+client\s*\{/gm) ?? []).length, 1);
  assert.equal((base.match(/^datasource\s+db\s*\{/gm) ?? []).length, 1);
  assert.doesNotMatch(base, /^\s*(?:type|view)\s+/m);

  const actualModels: string[] = [];
  const actualEnums: string[] = [];
  for (const owner of manifest.owners) {
    const text = readFileSync(path.join(schemaRoot, owner.file), 'utf8');
    assert.deepEqual(declarations(text, 'model').sort(), [...owner.models].sort(), owner.file);
    assert.deepEqual(declarations(text, 'enum').sort(), [...owner.enums].sort(), owner.file);
    assert.ok(text.trim().length > 0, `${owner.file} must not be empty`);
    actualModels.push(...owner.models);
    actualEnums.push(...owner.enums);
    assert.deepEqual([...(registry.owners[owner.owner] ?? [])].sort(), [...owner.models].sort());
  }

  // B-16: + PortfolioItem and PortfolioItemStatus (D62).
  // D63: + DataExport (the one-time download of an account's data).
  // D65: + PlanEvent, + PlanEventType and PlanEventTimeSlot.
  // D83: + GuestInvitationCard and GuestEventInvite.
  // RA-ST-05: + ReviewReport (a review reported as offensive or false).
  // RA-ST-04: + AssistantAnswerReport (an assistant answer reported).
  assert.equal(actualModels.length, 72);
  assert.equal(new Set(actualModels).size, 72);
  // B5: + BudgetCategoryKind (the groom's mahr item, C1).
  // Home guidance: + BudgetItemSuggestion («ما أحتاجها» / «بعدين»).
  assert.equal(actualEnums.length, 56);
  assert.equal(new Set(actualEnums).size, 56);
  assert.equal(manifest.modelOrder.length, 72);
  assert.deepEqual([...manifest.modelOrder].sort(), [...actualModels].sort());
  assert.deepEqual(
    Object.keys(registry.owners).filter((owner) => registry.owners[owner].length > 0).sort(),
    manifest.owners.map((entry) => entry.owner).sort(),
  );
});

test('Prisma config and both Docker stages discover the native schema folder without fallback', () => {
  const config = readFileSync(path.join(backendRoot, 'prisma.config.ts'), 'utf8');
  const docker = readFileSync(path.join(backendRoot, 'Dockerfile'), 'utf8');
  const packageJson = readJson<Record<string, unknown>>(path.join(backendRoot, 'package.json'));

  assert.match(config, /schema:\s*["']prisma\/schema["']/);
  assert.doesNotMatch(config, /schema\.prisma/i);
  assert.equal((docker.match(/^COPY prisma\.config\.ts \.\/$/gm) ?? []).length, 1);
  assert.equal((docker.match(/^COPY --from=build \/app\/prisma\.config\.ts \.\/$/gm) ?? []).length, 1);
  assert.ok(docker.indexOf('COPY prisma.config.ts ./') > docker.indexOf('COPY prisma ./prisma'));
  assert.ok(
    docker.indexOf('COPY --from=build /app/prisma.config.ts ./')
      > docker.indexOf('COPY --from=build /app/prisma ./prisma'),
  );
  assert.equal(Object.prototype.hasOwnProperty.call(packageJson, 'prisma'), false);
});

test('the canonical loader agrees with the exact manifest and combined current schema', () => {
  const { readPrismaSchemaFiles } = require('../scripts/prisma/schema-files.cjs') as {
    readPrismaSchemaFiles: (options?: { backendRoot?: string }) => {
      files: Array<{ file: string; models: string[]; enums: string[]; text: string }>;
      modelOrder: string[];
      combinedText: string;
    };
  };
  const manifest = readJson<Manifest>(manifestPath);
  const loaded = readPrismaSchemaFiles({ backendRoot });

  assert.deepEqual(loaded.files.map((entry) => entry.file), [manifest.baseFile, ...manifest.owners.map((entry) => entry.file)]);
  assert.deepEqual(loaded.modelOrder, manifest.modelOrder);
  assert.equal(declarations(loaded.combinedText, 'model').length, 72);
  assert.equal(declarations(loaded.combinedText, 'enum').length, 56);
});

test('the contributor migration rehearsal keeps migrations discoverable under the passed schema directory', () => {
  const smoke = readFileSync(
    path.join(backendRoot, 'scripts', 'smoke', 'contributor-history-migration-smoke.js'),
    'utf8',
  );

  assert.match(
    smoke,
    /const targetMigrationsRoot = join\(targetPrismaRoot, 'schema', 'migrations'\);/,
  );
  assert.match(smoke, /cpSync\(join\(prismaRoot, 'schema'\), join\(targetPrismaRoot, 'schema'\), \{/);
  assert.match(smoke, /schemaPath: join\(targetPrismaRoot, 'schema'\),/);
});

test('active executable and documentation readers contain no retired single-file dependency', () => {
  const executableExtensions = new Set(['.ts', '.js', '.cjs', '.mjs', '.json']);
  const executableAllowlist = new Set([
    'backend/test/architecture-r2-schema-layout.test.ts',
    'backend/test/prisma-schema-files.test.ts',
  ]);
  // Historical documents that describe the single file's dissolution: the
  // original architecture target (tracked verbatim) and the R0-R2 records.
  const documentationAllowlist = new Set([
    'CHANGELOG.md',
    'docs/project/STATUS.md',
    'docs/superpowers/specs/2026-08-04-modular-monolith-architecture-design.md',
    'docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md',
    'docs/superpowers/plans/2026-08-12-modular-monolith-r1-platform-shared-kernel.md',
    'docs/superpowers/plans/2026-08-13-modular-monolith-r2-prisma-schema.md',
    'docs/superpowers/specs/2026-08-13-modular-monolith-r2-prisma-schema-design.md',
  ]);
  const stale: string[] = [];

  for (const absolute of listFiles(repoRoot)) {
    const relative = path.relative(repoRoot, absolute).replaceAll('\\', '/');
    if (relative.startsWith('.git/') || relative.startsWith('.superpowers/') || relative.startsWith('node_modules/')) continue;
    const extension = path.extname(relative).toLowerCase();
    if (!executableExtensions.has(extension) && extension !== '.md') continue;
    if (relative.includes('/node_modules/') || relative.includes('/dist/')) continue;
    const text = readFileSync(absolute, 'utf8');
    if (!/prisma[\\/]schema\.prisma/i.test(text)) continue;
    if (relative.startsWith('docs/archive/') && relative.endsWith('.md.txt')) continue;
    if (executableExtensions.has(extension) && executableAllowlist.has(relative)) continue;
    if (extension === '.md' && documentationAllowlist.has(relative)) continue;
    stale.push(relative);
  }

  assert.deepEqual(stale, []);
});
