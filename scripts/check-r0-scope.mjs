import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const R0_BASE = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';

export const R0_ALLOWED_PATHS = new Set([
  '.github/workflows/ci.yml',
  '.gitleaksignore',
  'AGENTS.md',
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/.dependency-cruiser-known-violations.json',
  'backend/.dependency-cruiser.cjs',
  'backend/architecture/ownership-baseline.json',
  'backend/architecture/ownership-registry.json',
  'backend/package-lock.json',
  'backend/package.json',
  'backend/scripts/architecture/ownership-scan.cjs',
  'backend/scripts/architecture/ports-scan.cjs',
  'backend/test/architecture-dependencies.test.ts',
  'backend/test/architecture-ownership.test.ts',
  'backend/test/architecture-ports.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/frontend/MOBILE_ARCHITECTURE.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md',
  'mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart',
  'scripts/architecture/mobile-boundaries-baseline.json',
  'scripts/check-mobile-boundaries.mjs',
  'scripts/check-mobile-boundaries.test.mjs',
  'scripts/check-r0-scope.mjs',
  'scripts/check-r0-scope.test.mjs',
]);

function normalizeRepositoryPath(value) {
  const normalized = value.replaceAll('\\', '/');
  const segments = normalized.split('/');
  if (
    normalized.startsWith('/')
    || /^[A-Za-z]:\//.test(normalized)
    || normalized.includes('\0')
    || segments.includes('..')
  ) {
    throw new Error('invalid repository path');
  }
  return normalized;
}

function parseGitPaths(output) {
  return String(output)
    .split(/\r\n|\r|\n/)
    .filter((value) => value.length > 0)
    .map(normalizeRepositoryPath);
}

function defaultRunGit(repoRoot) {
  return (args) => execFileSync('git', args, {
    cwd: repoRoot,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });
}

export function collectChangedPaths({ runGit, base = R0_BASE }) {
  runGit(['cat-file', '-e', `${base}^{commit}`]);
  const tracked = parseGitPaths(runGit([
    'diff',
    '--name-only',
    '--no-renames',
    '--diff-filter=ACMRDTUXB',
    base,
    '--',
  ]));
  const untracked = parseGitPaths(runGit([
    'ls-files',
    '--others',
    '--exclude-standard',
  ]));

  return [...new Set([...tracked, ...untracked])].sort();
}

export function findUnexpectedPaths(paths) {
  return [...new Set(paths.map(normalizeRepositoryPath))]
    .filter((repositoryPath) => !R0_ALLOWED_PATHS.has(repositoryPath))
    .sort();
}

function writeLine(writer, message) {
  writer(message);
}

export function runCli({ argv, collect, stdout, stderr }) {
  if (argv.length !== 1 || argv[0] !== '--check') {
    writeLine(stderr, 'usage: check-r0-scope.mjs --check');
    return 2;
  }

  try {
    const unexpected = findUnexpectedPaths(collect());
    if (unexpected.length > 0) {
      writeLine(stderr, 'FAIL - R0 scope: unexpected paths');
      for (const repositoryPath of unexpected) writeLine(stderr, repositoryPath);
      return 1;
    }
    writeLine(stdout, 'PASS - R0 scope: no unexpected paths');
    return 0;
  } catch {
    writeLine(stderr, 'R0 scope configuration error');
    return 2;
  }
}

function defaultDependencies(argv) {
  const scriptFile = fileURLToPath(import.meta.url);
  const repoRoot = path.resolve(path.dirname(scriptFile), '..');
  const runGit = defaultRunGit(repoRoot);
  return {
    argv,
    collect: () => collectChangedPaths({ runGit }),
    stdout: (message) => process.stdout.write(`${message}\n`),
    stderr: (message) => process.stderr.write(`${message}\n`),
  };
}

const invokedDirectly = process.argv[1]
  && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) {
  process.exitCode = runCli(defaultDependencies(process.argv.slice(2)));
}
