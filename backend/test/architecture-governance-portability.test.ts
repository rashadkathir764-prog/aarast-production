import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';

// Governance portability.
//
// The R12 governance chain binds to repository content: the immutable base
// commit, the overlay measured against it, and the fingerprints of governed
// files. It must therefore validate the same content from any checkout: a
// differently named directory, any branch, a committed or an uncommitted
// extension of the base. It must equally keep rejecting drifted governed
// bytes, undeclared files, forged ancestry and unregistered protected changes.
//
// The proofs below run the real gate commands as child processes inside a
// fresh clone whose working tree is exactly what committing the current
// working tree would materialize; nothing in memory is neutralized.

const repositoryRoot = path.resolve(__dirname, '../..');
const backendRoot = path.join(repositoryRoot, 'backend');
const identity = require(path.join(backendRoot, 'scripts/architecture/repository-identity.cjs'));
const r12c = require(path.join(backendRoot, 'scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs'));
const baseCommit: string = r12c.BASE_COMMIT;
// Closure. While the phase is open the gates replay the byte lineage over the
// exact overlay; once the closure record exists they prove live invariants and
// the lineage stays verifiable at the recorded lineage commit (the lineage
// proof below runs it). Lineage-only probes are skipped in closed mode with
// that reason; closed-mode probes are skipped while the phase is open.
const closureModule = require(path.join(backendRoot, 'scripts/architecture/modular-monolith-closure.cjs'));
const closure: { lineageCommit: string } | null = closureModule.readClosure(repositoryRoot, baseCommit);
const lineageOnly = closure
  ? `R12C is closed: this lineage law is proven at lineage commit ${closure.lineageCommit.slice(0, 12)} by the lineage proof in this suite`
  : false;
const closedOnly = closure ? false : 'the phase is open: the closure record does not exist yet';
const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const gateScripts = {
  r3: ['scripts/architecture/r3-context-scan.cjs', '--check', '--stage', 'strict'],
  r5: ['scripts/architecture/r5-identity-scan.cjs', '--check'],
  r6: ['scripts/architecture/r6-sharing-otp-transport-scan.cjs', '--check'],
  r7: ['scripts/architecture/r7-collaboration-relocation-scan.cjs', '--check'],
  r8: ['scripts/architecture/r8-global-module-removal-scan.cjs', '--check'],
  r12a: ['scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs', '--check'],
  r12b: ['scripts/architecture/r12b-planning-public-contracts-scan.cjs', '--check'],
  r12c: ['scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs', '--check'],
} as const;
type Gate = keyof typeof gateScripts;

function git(cwd: string, args: string[], env: NodeJS.ProcessEnv = {}): string {
  return execFileSync('git', args, { cwd, encoding: 'utf8', windowsHide: true, env: { ...process.env, ...env } }).trim();
}

// A dangling commit of the current working tree, built through a private index
// so neither the real index nor any ref changes. Its checkout is what a commit
// of this working tree would materialize on any machine.
function commitWorkingTreeSnapshot(): string {
  const indexFile = path.join(mkdtempSync(path.join(tmpdir(), 'aarast-portability-index-')), 'index');
  const env = { GIT_INDEX_FILE: indexFile };
  git(repositoryRoot, ['read-tree', 'HEAD'], env);
  git(repositoryRoot, ['add', '-A', '--', '.'], env);
  const tree = git(repositoryRoot, ['write-tree'], env);
  const commit = git(repositoryRoot, ['commit-tree', tree, '-p', 'HEAD', '-m', 'governance portability snapshot'], {
    ...env,
    GIT_AUTHOR_NAME: 'portability', GIT_AUTHOR_EMAIL: 'portability@test', GIT_COMMITTER_NAME: 'portability', GIT_COMMITTER_EMAIL: 'portability@test',
  });
  rmSync(path.dirname(indexFile), { recursive: true, force: true });
  return commit;
}

function runGate(cwd: string, gate: Gate): { status: number | null; output: string } {
  const [script, ...args] = gateScripts[gate];
  const result = spawnSync(process.execPath, [path.join(cwd, 'backend', script), ...args], {
    cwd: path.join(cwd, 'backend'),
    encoding: 'utf8',
    windowsHide: true,
    env: { ...process.env, ARCHITECTURE_DEBUG: '1', R12A_DEBUG: '1', R12B_DEBUG: '1', R12C_DEBUG: '1' },
  });
  return { status: result.status, output: `${result.stdout}${result.stderr}` };
}

function expectPass(cwd: string, gate: Gate): void {
  const { status, output } = runGate(cwd, gate);
  assert.equal(status, 0, `${gate} must pass from ${cwd}:\n${output}`);
  assert.match(output, /^PASS - /mu, gate);
}

function expectFailure(cwd: string, gate: Gate, reason: RegExp): void {
  const { status, output } = runGate(cwd, gate);
  assert.notEqual(status, 0, `${gate} must fail from ${cwd}`);
  assert.match(output, reason, `${gate} must fail for the expected reason:\n${output}`);
}

function npmRun(cwd: string, script: string): { status: number | null; output: string } {
  const result = spawnSync(npmCommand, ['run', '-s', script], {
    cwd: path.join(cwd, 'backend'), encoding: 'utf8', windowsHide: true, shell: process.platform === 'win32', maxBuffer: 64 * 1024 * 1024,
  });
  return { status: result.status, output: `${result.stdout}${result.stderr}` };
}

describe('governance portability', () => {
  let scratch = '';
  let clone = '';
  let snapshot = '';

  before(() => {
    scratch = mkdtempSync(path.join(tmpdir(), 'aarast-portability-'));
    // A directory name that shares nothing with the source checkout.
    clone = path.join(scratch, 'renamed-checkout');
    snapshot = commitWorkingTreeSnapshot();
    git(scratch, ['clone', '--quiet', '--shared', '--no-checkout', repositoryRoot, clone]);
    git(clone, ['checkout', '--quiet', '-b', 'portability-proof', snapshot]);
    // A fresh checkout is verified after the documented dependency install:
    // the scanners resolve Nest decorators through a real TypeScript program.
    // The clone owns a plain node_modules directory of its own; nothing is
    // linked to this worktree's installation.
    const install = spawnSync(npmCommand, ['ci', '--ignore-scripts', '--no-audit', '--no-fund', '--prefer-offline', '--loglevel=error'], {
      cwd: path.join(clone, 'backend'), encoding: 'utf8', windowsHide: true, shell: process.platform === 'win32',
    });
    assert.equal(install.status, 0, `dependency install in the clone failed:\n${install.stdout}${install.stderr}`);
    assert.equal(existsSync(path.join(clone, 'backend/node_modules/typescript/package.json')), true);
  });

  after(() => {
    if (scratch) rmSync(scratch, { recursive: true, force: true });
  });

  test('the identity helper accepts only a Git top level extending the base commit', () => {
    const root = identity.verifyRepositoryIdentity(repositoryRoot, baseCommit);
    assert.equal(path.resolve(root), path.resolve(repositoryRoot));
    assert.throws(() => identity.verifyRepositoryIdentity(backendRoot, baseCommit), /not the Git top level/u);
    assert.throws(() => identity.verifyRepositoryIdentity(path.dirname(repositoryRoot), baseCommit), /Repository identity/u);
    assert.throws(() => identity.verifyRepositoryIdentity(repositoryRoot, '0'.repeat(40)), /not present/u);
    assert.throws(() => identity.verifyRepositoryIdentity(repositoryRoot, 'HEAD'), /full lowercase SHA-1/u);
    assert.throws(() => identity.verifyRepositoryIdentity('relative/path', baseCommit), /absolute/u);
    const rows = identity.workingTreeInventory(repositoryRoot, baseCommit);
    for (const row of rows) assert.ok([' M', ' D', '??'].includes(row.status), JSON.stringify(row));
    assert.deepEqual(rows.map((row: { path: string }) => row.path), [...rows.map((row: { path: string }) => row.path)].sort());
    assert.equal(new Set(rows.map((row: { path: string }) => row.path)).size, rows.length);
  });

  test('the working tree is in canonical Git form, so a checkout reproduces every fingerprinted byte', () => {
    const tracked = git(repositoryRoot, ['ls-files', '-z']).split('\u0000').filter(Boolean);
    const drifted: string[] = [];
    for (const relative of tracked) {
      if (!/\.(cjs|mjs|ts|js|json|md)$/u.test(relative)) continue;
      const file = path.join(repositoryRoot, relative);
      if (!existsSync(file)) continue;
      const raw = git(repositoryRoot, ['hash-object', '--no-filters', '--', file]);
      const filtered = git(repositoryRoot, ['hash-object', '--path', relative, '--', file]);
      if (raw !== filtered) drifted.push(relative);
    }
    assert.deepEqual(drifted, [], 'files whose committed bytes would differ from their working bytes');
  });

  test('every governed gate passes from a renamed clone on another branch with the work committed', () => {
    assert.notEqual(path.basename(clone), path.basename(repositoryRoot));
    assert.equal(git(clone, ['branch', '--show-current']), 'portability-proof');
    assert.notEqual(git(clone, ['rev-parse', 'HEAD']), baseCommit);
    assert.equal(git(clone, ['status', '--porcelain']), '', 'the clone starts with a clean, fully committed tree');
    for (const gate of Object.keys(gateScripts) as Gate[]) expectPass(clone, gate);
  });

  test('the same content passes when the extension of the base commit is uncommitted', { skip: lineageOnly }, () => {
    git(clone, ['reset', '--quiet', '--mixed', baseCommit]);
    try {
      assert.equal(git(clone, ['rev-parse', 'HEAD']), baseCommit);
      assert.notEqual(git(clone, ['status', '--porcelain']), '', 'the overlay is now uncommitted');
      expectPass(clone, 'r12c');
      expectPass(clone, 'r12b');
      expectPass(clone, 'r3');
    } finally {
      git(clone, ['reset', '--quiet', '--hard', snapshot]);
      git(clone, ['clean', '--quiet', '-fd']);
    }
  });

  test('identical content on a history that does not extend the base commit is rejected', () => {
    git(clone, ['checkout', '--quiet', '--orphan', 'forged-history']);
    try {
      git(clone, ['commit', '--quiet', '-m', 'forged ancestry'], {
        GIT_AUTHOR_NAME: 'portability', GIT_AUTHOR_EMAIL: 'portability@test', GIT_COMMITTER_NAME: 'portability', GIT_COMMITTER_EMAIL: 'portability@test',
      });
      assert.equal(git(clone, ['status', '--porcelain']), '');
      // Open phase: the base commit is not an ancestor. Closed phase: the
      // closure record's lineage commit is not an ancestor either.
      expectFailure(clone, 'r12c', /does not extend base commit|does not extend the lineage commit/u);
      expectFailure(clone, 'r12b', /does not extend base commit|does not extend the lineage commit/u);
      expectFailure(clone, 'r12a', /does not extend base commit|does not extend the lineage commit|validation failed/u);
    } finally {
      git(clone, ['checkout', '--quiet', 'portability-proof']);
      git(clone, ['branch', '--quiet', '-D', 'forged-history']);
      git(clone, ['reset', '--quiet', '--hard', snapshot]);
    }
  });

  test('drift of a governed file, an undeclared file, and an unregistered protected change are still rejected', { skip: lineageOnly }, () => {
    const scanner = path.join(clone, 'backend/scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs');
    const original = readFileSync(scanner);
    writeFileSync(scanner, Buffer.concat([original, Buffer.from('\n')]));
    try {
      expectFailure(clone, 'r12c', /governed fingerprint changed/u);
    } finally {
      writeFileSync(scanner, original);
    }

    const attacker = path.join(clone, 'backend/src/attacker.ts');
    mkdirSync(path.dirname(attacker), { recursive: true });
    writeFileSync(attacker, 'export const attacker = true;\n');
    try {
      expectFailure(clone, 'r12c', /undeclared, duplicated or changed status: backend\/src\/attacker\.ts/u);
    } finally {
      rmSync(attacker, { force: true });
    }

    const lock = path.join(clone, 'backend/package-lock.json');
    const lockBytes = readFileSync(lock);
    writeFileSync(lock, Buffer.concat([lockBytes, Buffer.from('\n')]));
    try {
      expectFailure(clone, 'r12c', /package-lock|security prerequisite|governed|changed/u);
    } finally {
      writeFileSync(lock, lockBytes);
    }

    const overlay = path.join(clone, 'docs/project/STATUS.md');
    const overlayBytes = readFileSync(overlay);
    writeFileSync(overlay, Buffer.concat([overlayBytes, Buffer.from('\n')]));
    try {
      expectFailure(clone, 'r12c', /predecessor reconstruction changed|documentation projection drifted|changed/u);
    } finally {
      writeFileSync(overlay, overlayBytes);
    }
    assert.equal(git(clone, ['status', '--porcelain']), '', 'every probe restored the clone');
    expectPass(clone, 'r12c');
  });

  test('closed gates accept an unrelated product change and still reject a cross-context import, a recreated ledger, a legacy import, a tampered lock and a tampered closure record', { skip: closedOnly }, () => {
    const service = path.join(clone, 'backend/src/tasks/tasks.service.ts');
    const original = readFileSync(service);
    // A product change nowhere near the governed surfaces needs no registration.
    writeFileSync(service, Buffer.concat([original, Buffer.from('\n// product change after closure\n')]));
    try {
      for (const gate of Object.keys(gateScripts) as Gate[]) expectPass(clone, gate);
      const imports = npmRun(clone, 'architecture:imports');
      assert.equal(imports.status, 0, imports.output);
    } finally {
      writeFileSync(service, original);
    }
    // A cross-context import is a violation of the strict, unbaselined command.
    writeFileSync(service, Buffer.concat([original, Buffer.from('\nimport { MarketplaceService as _Probe } from "../marketplace/marketplace.service";\n')]));
    try {
      const imports = npmRun(clone, 'architecture:imports');
      assert.notEqual(imports.status, 0, 'the strict import command must reject a cross-context import');
      assert.match(imports.output, /context-tasks-cross-context/u, imports.output);
    } finally {
      writeFileSync(service, original);
    }
    // A reintroduced import of a published contract at its legacy location, a
    // re-export of it, and a copied declaration are each rejected.
    for (const [probe, reason] of [
      ['\nimport { providerAccessPolicy as _Probe } from "../provider-dashboard/provider-access-policy";\n', /alternate Marketplace policy import is forbidden: backend\/src\/tasks\/tasks\.service\.ts/u],
      ['\nexport { providerAccessPolicy } from "../modules/marketplace/public/provider-access-policy";\n', /Marketplace policy re-export is forbidden: backend\/src\/tasks\/tasks\.service\.ts/u],
      ['\nexport const PROVIDER_PORTAL_ROUTE = "/provider";\n', /Marketplace policy copy is forbidden: backend\/src\/tasks\/tasks\.service\.ts/u],
    ] as Array<[string, RegExp]>) {
      writeFileSync(service, Buffer.concat([original, Buffer.from(probe)]));
      try {
        expectFailure(clone, 'r12c', reason);
      } finally {
        writeFileSync(service, original);
      }
    }
    // A recreated dependency ledger is rejected.
    const ledger = path.join(clone, 'backend/.dependency-cruiser-known-violations.json');
    writeFileSync(ledger, '[]\n');
    try {
      expectFailure(clone, 'r12c', /strict dependency baseline must be absent/u);
    } finally {
      rmSync(ledger, { force: true });
    }
    // A lock outside the approved lineage fails the security prerequisite and R5.
    const lock = path.join(clone, 'backend/package-lock.json');
    const lockBytes = readFileSync(lock);
    writeFileSync(lock, Buffer.from(JSON.stringify({ ...JSON.parse(lockBytes.toString('utf8')), probe: true }, null, 2)));
    try {
      const security = npmRun(clone, 'security:prisma-config-merge');
      assert.notEqual(security.status, 0, 'the security prerequisite must reject a lock outside the approved lineage');
      assert.match(security.output, /FAIL - Prisma config merge security/u, security.output);
      expectFailure(clone, 'r5', /R5 Identity relocation validation failed/u);
    } finally {
      writeFileSync(lock, lockBytes);
    }
    // A closure record that no longer matches the frozen manifests fails every closed gate.
    const record = path.join(clone, closureModule.CLOSURE_PATH);
    const recordBytes = readFileSync(record);
    const parsed = JSON.parse(recordBytes.toString('utf8'));
    writeFileSync(record, JSON.stringify({ ...parsed, manifests: { ...parsed.manifests, r12c: '0'.repeat(64) } }, null, 2));
    try {
      expectFailure(clone, 'r12c', /r12c manifest changed after closure/u);
      expectFailure(clone, 'r12b', /r12c manifest changed after closure/u);
      expectFailure(clone, 'r12a', /r12c manifest changed after closure|validation failed/u);
    } finally {
      writeFileSync(record, recordBytes);
    }
    assert.equal(git(clone, ['status', '--porcelain']), '', 'every probe restored the clone');
    expectPass(clone, 'r12c');
  });

  test('closed gates accept ordinary product evolution inside the R3-R8 governed areas and still reject their law violations', { skip: closedOnly }, () => {
    // The relocation phases R3-R8 proved their moves with exact inventories and
    // byte parity. After closure those proofs are history; the live laws are
    // layout, boundaries, wiring rules and counts. A product change that
    // respects the laws needs no scanner edit.
    const edits = new Map<string, Buffer | null>();
    const file = (relative: string) => path.join(clone, relative);
    const remember = (relative: string) => {
      if (!edits.has(relative)) edits.set(relative, existsSync(file(relative)) ? readFileSync(file(relative)) : null);
    };
    const append = (relative: string, text: string) => { remember(relative); writeFileSync(file(relative), Buffer.concat([readFileSync(file(relative)), Buffer.from(text)])); };
    const replace = (relative: string, before: string, after: string) => {
      remember(relative);
      const current = readFileSync(file(relative), 'utf8');
      assert.equal(current.split(before).length, 2, `${relative}: probe anchor`);
      writeFileSync(file(relative), current.replace(before, after));
    };
    const createdDirectories: string[] = [];
    const create = (relative: string, text: string) => {
      remember(relative);
      const directory = path.dirname(file(relative));
      // A directory this probe creates is removed with it: an empty retired
      // root (backend/src/auth) is invisible to git status but visible to R5.
      if (!existsSync(directory)) createdDirectories.push(directory);
      mkdirSync(directory, { recursive: true });
      writeFileSync(file(relative), text);
    };
    const restore = () => {
      for (const [relative, bytes] of edits) {
        if (bytes === null) rmSync(file(relative), { force: true });
        else writeFileSync(file(relative), bytes);
      }
      edits.clear();
      for (const directory of createdDirectories.splice(0).reverse()) rmSync(directory, { recursive: true, force: true });
    };
    const gatesPass = (gates: Gate[]) => { for (const gate of gates) expectPass(clone, gate); };
    const all = Object.keys(gateScripts) as Gate[];

    // 1. A new Nest module wired into an existing context, and a new consumer
    //    of a public port: legal evolution, every gate passes.
    create('backend/src/tasks/task-probe.module.ts', 'import { Module } from "@nestjs/common";\n\n@Module({})\nexport class TaskProbeModule {}\n');
    replace('backend/src/modules/tasks/tasks.module.ts', 'imports: [TasksPublicModule, TasksServiceInternalModule],', 'imports: [TasksPublicModule, TasksServiceInternalModule, TaskProbeModule],');
    replace('backend/src/modules/tasks/tasks.module.ts', 'import { TasksServiceInternalModule } from "./internal/tasks-service.internal.module";', 'import { TasksServiceInternalModule } from "./internal/tasks-service.internal.module";\nimport { TaskProbeModule } from "../../tasks/task-probe.module";');
    // D83 added PlanReadPublicModule after the scope module; the probe
    // anchors on the last import.
    replace('backend/src/modules/guests/internal/guests-service.internal.module.ts', '    PlanReadPublicModule,\n  ],', '    PlanReadPublicModule,\n    NotificationsPublicModule,\n  ],');
    replace('backend/src/modules/guests/internal/guests-service.internal.module.ts', 'import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";', 'import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";\nimport { NotificationsPublicModule } from "../../notifications/public/notifications-public.module";');
    replace('backend/src/guests/guests.service.ts', '    @Inject(PLAN_READ_PORT)\n    private readonly plans: PlanReadPort,\n  ) {}', '    @Inject(PLAN_READ_PORT)\n    private readonly plans: PlanReadPort,\n    @Inject(NOTIFICATIONS_PORT)\n    private readonly notificationsProbe: NotificationsPort,\n  ) {}');
    replace('backend/src/guests/guests.service.ts', 'import { PrismaService } from "../platform/database/prisma.service";', 'import { PrismaService } from "../platform/database/prisma.service";\nimport { NOTIFICATIONS_PORT, NotificationsPort } from "../modules/notifications/public/notifications.port";');
    // 2. Ordinary edits inside the relocated Identity, OTP-transport and
    //    Collaboration files.
    append('backend/src/modules/identity/internal/auth/auth.service.ts', '\n// product change after closure\n');
    append('backend/src/modules/identity/api/auth.controller.ts', '\n// product change after closure\n');
    append('backend/src/platform/otp-transport/openwa-transient-text.ts', '\n// product change after closure\n');
    append('backend/src/modules/collaboration/public/collaboration-permission.port.ts', '\n// product change after closure\n');
    append('backend/src/modules/collaboration/internal/sharing.service.ts', '\n// product change after closure\n');
    try {
      gatesPass(all);
      const imports = npmRun(clone, 'architecture:imports');
      assert.equal(imports.status, 0, imports.output);
      const ports = npmRun(clone, 'architecture:ports');
      assert.equal(ports.status, 0, ports.output);
    } finally {
      restore();
    }

    // Violations of the live laws are still rejected, each with a visible reason.
    create('backend/src/tasks/task-probe.module.ts', 'import { Global, Module } from "@nestjs/common";\n\n@Global()\n@Module({})\nexport class TaskProbeModule {}\n');
    try {
      expectFailure(clone, 'r8', /global/iu);
      const ports = npmRun(clone, 'architecture:ports');
      assert.notEqual(ports.status, 0, 'a project @Global() must fail the ports gate');
    } finally {
      restore();
    }
    append('backend/src/tasks/tasks.service.ts', '\nimport { OpenWaOtpChannel as _Probe } from "../platform/otp-transport/openwa-otp.channel";\n');
    try {
      expectFailure(clone, 'r6', /transport/iu);
    } finally {
      restore();
    }
    create('backend/src/auth/legacy-probe.ts', 'export const legacy = true;\n');
    try {
      expectFailure(clone, 'r5', /retired identity root remains/u);
    } finally {
      restore();
    }
    append('backend/src/tasks/tasks.service.ts', '\nimport { ConversationsService as _Probe } from "../conversations/conversations.service";\n');
    replace('backend/src/tasks/tasks.service.ts', '  constructor(\n', '  constructor(\n    private readonly conversationsProbe: _Probe,\n');
    try {
      const r3 = runGate(clone, 'r3');
      assert.notEqual(r3.status, 0, 'a cross-context injection of an internal service must fail R3');
      assert.match(r3.output, /illegal|cross-context|boundary/iu, `R3 must name the violation:\n${r3.output}`);
    } finally {
      restore();
    }
    append('backend/src/tasks/tasks.service.ts', '\nimport { SharingService as _Probe } from "../modules/collaboration/internal/sharing.service";\n');
    try {
      expectFailure(clone, 'r7', /collaboration|internal|protected/iu);
    } finally {
      restore();
    }
    assert.equal(git(clone, ['status', '--porcelain']), '', 'every probe restored the clone');
  });

  test('the recorded lineage commit still passes the complete lineage gates verbatim', { skip: closedOnly }, () => {
    // History stays provable: the clone is checked out at the lineage commit,
    // where no closure record exists, and the lineage gates the record names
    // that need only the installed dependency surface run there unchanged
    // (every package the lineage lock installs is installed identically; an
    // approved later lock may only add packages, as the planning assistant's
    // SDK did in V1 checklist 4.12). The typecheck gate additionally needs
    // the generated Prisma client, an install-time step this clone does not
    // perform; it is verified in the clean-room checkout, not here.
    const lineageCommit = (closure as { lineageCommit: string }).lineageCommit;
    type LockPackages = Record<string, { version?: string; integrity?: string; resolved?: string }>;
    const lockAt = (ref: string) =>
      JSON.parse(git(clone, ['show', `${ref}:backend/package-lock.json`])) as { packages: LockPackages };
    const lineageLock = lockAt(lineageCommit);
    const headLock = lockAt('HEAD');
    const security = require(path.join(clone, 'backend', 'scripts', 'security', 'prisma-config-merge-security.cjs'));
    assert.ok(
      security.PACKAGE_LOCK_LINEAGE.includes(security.fingerprintPlainJson(headLock)),
      'the HEAD lock is an approved lock',
    );
    for (const [name, entry] of Object.entries(lineageLock.packages)) {
      if (name === '') continue;
      const head = headLock.packages[name];
      assert.ok(head, `the HEAD lock still installs ${name}`);
      assert.deepEqual(
        { version: head.version, integrity: head.integrity, resolved: head.resolved },
        { version: entry.version, integrity: entry.integrity, resolved: entry.resolved },
        `${name} is installed exactly as at the lineage commit`,
      );
    }
    git(clone, ['checkout', '--quiet', '--detach', lineageCommit]);
    try {
      assert.equal(existsSync(path.join(clone, closureModule.CLOSURE_PATH)), false, 'the lineage commit predates the closure record');
      assert.equal(git(clone, ['status', '--porcelain']), '');
      const architecture = npmRun(clone, 'architecture');
      assert.equal(architecture.status, 0, `lineage architecture aggregate:\n${architecture.output}`);
      for (const phase of ['R12A', 'R12B', 'R12C']) {
        assert.match(architecture.output, new RegExp(`^PASS - ${phase} .*stage=strict`, 'mu'), `${phase} lineage gate`);
        assert.doesNotMatch(architecture.output, new RegExp(`^PASS - ${phase} .*\\(closed\\)`, 'mu'), `${phase} must run in lineage mode`);
      }
      const security = npmRun(clone, 'security:prisma-config-merge');
      assert.equal(security.status, 0, `lineage security prerequisite:\n${security.output}`);
    } finally {
      git(clone, ['checkout', '--quiet', 'portability-proof']);
      git(clone, ['reset', '--quiet', '--hard', snapshot]);
      git(clone, ['clean', '--quiet', '-fd']);
    }
  });

  test('the historical R12B replay substitutes exactly its pinned environment preamble and nothing else', () => {
    const preamble = r12c.R12B_CLOSURE_ENVIRONMENT_PREAMBLE;
    assert.equal(require('node:crypto').createHash('sha256').update(preamble.text, 'utf8').digest('hex'), preamble.sha256);
    assert.match(preamble.text, /rootName|show-current|'HEAD'/u, 'the substituted text is the environment binding');
    assert.doesNotMatch(preamble.replacement, /rootName|branch|show-current/u);
    const replayed = r12c.replayClosureScannerSource(Buffer.from(`head\n${preamble.text}tail\n`, 'utf8'));
    assert.equal(replayed, `head\n${preamble.replacement}tail\n`);
    assert.throws(() => r12c.replayClosureScannerSource(Buffer.from('no preamble here\n')), /not exactly once/u);
    assert.throws(() => r12c.replayClosureScannerSource(Buffer.from(`${preamble.text}${preamble.text}`)), /not exactly once/u);
  });
});
