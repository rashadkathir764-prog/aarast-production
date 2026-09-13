import { createHash } from 'node:crypto';
import {
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

// Isolated dependency surface for architecture fixtures.
//
// A fixture that compiles TypeScript or resolves installed packages must never
// reach this worktree's real node_modules through a link. A junction from a
// fixture to the live installation turns every fixture write into a write to
// the real packages: that is exactly how @nestjs/schedule and
// @nestjs/throttler were stubbed out in the original worktree. Instead, one
// real copy of the Nest dependency closure is materialized per test file under
// the OS temp directory and fixture roots are created *beneath* it, so Node
// and TypeScript resolve packages by walking up plain directories. A stub a
// fixture writes into its own backend/node_modules shadows the shared copy for
// that fixture only and can never touch the real installation.

const SURFACE_ROOTS = Object.freeze([
  '@nestjs/common',
  '@nestjs/core',
  '@nestjs/jwt',
  '@nestjs/passport',
  '@nestjs/platform-express',
  '@nestjs/platform-socket.io',
  '@nestjs/schedule',
  '@nestjs/throttler',
  '@nestjs/websockets',
  '@nest-lab/throttler-storage-redis',
  'reflect-metadata',
  'rxjs',
]);

type LockPackages = Record<string, { dependencies?: Record<string, string>; optionalDependencies?: Record<string, string> }>;

export interface DependencySurface {
  /** Temp directory owning the copied node_modules and every fixture root. */
  readonly root: string;
  /** The copied, link-free node_modules directory. */
  readonly nodeModules: string;
  /** Packages copied into the surface, in lockfile closure order. */
  readonly packages: readonly string[];
  /** Creates a fresh fixture root beneath the surface so resolution walks up into it. */
  fixtureRoot(prefix: string): string;
  /** Removes the surface and every fixture created beneath it. */
  dispose(): void;
}

export function lockfileClosure(backendRoot: string, roots: readonly string[] = SURFACE_ROOTS): string[] {
  const lock = JSON.parse(readFileSync(path.join(backendRoot, 'package-lock.json'), 'utf8')) as { packages: LockPackages };
  const seen = new Set<string>();
  const queue = [...roots];
  while (queue.length > 0) {
    const name = queue.shift()!;
    if (seen.has(name)) continue;
    const entry = lock.packages[`node_modules/${name}`];
    if (!entry) throw new Error(`dependency surface root is not in the lockfile: ${name}`);
    seen.add(name);
    for (const dependency of Object.keys({ ...entry.dependencies, ...entry.optionalDependencies })) queue.push(dependency);
  }
  return [...seen];
}

/** Throws if anything under `root` is a symbolic link, junction or other reparse point. */
export function assertNoReparsePoints(root: string): void {
  const visit = (directory: string): void => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      if (entry.isSymbolicLink() || lstatSync(target).isSymbolicLink()) {
        throw new Error(`reparse point inside an isolated fixture: ${target}`);
      }
      if (entry.isDirectory()) visit(target);
    }
  };
  visit(root);
}

/** Throws if any path under `root` resolves outside `root` (an escape through a link or alias). */
export function assertContained(root: string): void {
  const canonicalRoot = realpathSync.native(root);
  const visit = (directory: string): void => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      const canonical = realpathSync.native(target);
      const relative = path.relative(canonicalRoot, canonical);
      if (relative.startsWith('..') || path.isAbsolute(relative)) {
        throw new Error(`fixture path escapes its root: ${target} -> ${canonical}`);
      }
      if (entry.isDirectory()) visit(target);
    }
  };
  visit(root);
}

/** sha256 of every file beneath the given installed packages, keyed by repository-relative path. */
export function installationSentinel(backendRoot: string, packages: readonly string[]): Record<string, string> {
  const sentinel: Record<string, string> = {};
  const nodeModules = path.join(backendRoot, 'node_modules');
  const hidden = path.join(nodeModules, '.package-lock.json');
  if (existsSync(hidden)) sentinel['node_modules/.package-lock.json'] = createHash('sha256').update(readFileSync(hidden)).digest('hex');
  for (const name of packages) {
    const packageRoot = path.join(nodeModules, ...name.split('/'));
    if (!existsSync(packageRoot)) {
      sentinel[`node_modules/${name}`] = 'missing';
      continue;
    }
    const visit = (directory: string): void => {
      for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const target = path.join(directory, entry.name);
        const relative = path.relative(nodeModules, target).replaceAll('\\', '/');
        if (entry.isSymbolicLink()) sentinel[`node_modules/${relative}`] = 'symlink';
        else if (entry.isDirectory()) visit(target);
        else sentinel[`node_modules/${relative}`] = createHash('sha256').update(readFileSync(target)).digest('hex');
      }
    };
    visit(packageRoot);
  }
  return sentinel;
}

export function createDependencySurface(backendRoot: string, prefix = 'aarast-dependency-surface-'): DependencySurface {
  const root = mkdtempSync(path.join(tmpdir(), prefix));
  const nodeModules = path.join(root, 'node_modules');
  const packages = lockfileClosure(backendRoot);
  const source = path.join(backendRoot, 'node_modules');
  for (const name of packages) {
    const from = path.join(source, ...name.split('/'));
    if (!existsSync(from)) throw new Error(`dependency surface package is not installed: ${name}`);
    const to = path.join(nodeModules, ...name.split('/'));
    mkdirSync(path.dirname(to), { recursive: true });
    // Real copies only: links are dereferenced into files, never recreated.
    cpSync(from, to, { recursive: true, dereference: true, errorOnExist: false, force: true });
  }
  assertNoReparsePoints(root);
  const fixtures = path.join(root, 'fixtures');
  mkdirSync(fixtures, { recursive: true });
  return Object.freeze({
    root,
    nodeModules,
    packages: Object.freeze(packages),
    fixtureRoot(fixturePrefix: string): string {
      return mkdtempSync(path.join(fixtures, fixturePrefix));
    },
    dispose(): void {
      rmSync(root, { recursive: true, force: true });
    },
  });
}
