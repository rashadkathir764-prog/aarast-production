import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  compareMobileBaseline,
  parseDartDirectives,
  runCli,
  scanMobileBoundaries,
} from './check-mobile-boundaries.mjs';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..');
const scriptPath = path.join(scriptDir, 'check-mobile-boundaries.mjs');
const baselinePath = path.join(
  scriptDir,
  'architecture',
  'mobile-boundaries-baseline.json',
);
const sourceRevision = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';

function withMobileFixture(files, callback) {
  const root = mkdtempSync(path.join(os.tmpdir(), 'aarast-mobile-boundaries-'));
  const mobileLib = path.join(root, 'mobile', 'lib');
  mkdirSync(mobileLib, { recursive: true });
  try {
    for (const [relativePath, source] of Object.entries(files)) {
      const target = path.join(mobileLib, ...relativePath.split('/'));
      mkdirSync(path.dirname(target), { recursive: true });
      writeFileSync(target, source, 'utf8');
    }
    return callback({ root, mobileLib });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function record(overrides = {}) {
  return {
    source: 'mobile/lib/core/source.dart',
    target: 'mobile/lib/features/alpha/alpha_api.dart',
    sourceArea: 'core',
    targetArea: 'features/alpha',
    kind: 'core-to-feature',
    count: 1,
    ...overrides,
  };
}

function baseline(records = []) {
  return {
    schemaVersion: 1,
    sourceRevision,
    records,
  };
}

function captureCli(overrides = {}) {
  const stdout = [];
  const stderr = [];
  const dependencies = {
    argv: ['--check-baseline'],
    scan: () => ({ records: [], errors: [] }),
    readBaseline: () => baseline(),
    writeBaseline: () => {},
    stdout: (message) => stdout.push(message),
    stderr: (message) => stderr.push(message),
    ...overrides,
  };
  return {
    exitCode: runCli(dependencies),
    stdout,
    stderr,
  };
}

test('character scanner finds quoted, multiline, and conditional URI alternatives only', () => {
  const source = String.raw`
// import 'commented.dart';
/* outer
   /* export "nested-comment.dart"; */
   part 'also-commented.dart';
*/
const fake = "import 'inside-string.dart';";
const multilineFake = '''
export 'inside-triple-string.dart';
''';

import
  'primary.dart'
  if (dart.library.io)
    "native.dart"
  if (dart.library.html) 'browser.dart';
export "public.dart"
  if (dart.library.js_interop) 'web_public.dart';
part './child.dart';
part of
  "library.dart";
`;

  assert.deepEqual(parseDartDirectives(source), [
    {
      kind: 'import',
      uris: ['primary.dart', 'native.dart', 'browser.dart'],
    },
    {
      kind: 'export',
      uris: ['public.dart', 'web_public.dart'],
    },
    { kind: 'part', uris: ['./child.dart'] },
    { kind: 'part-of', uris: ['library.dart'] },
  ]);
});

test('bare, dot-relative, parent-relative, and Aarast package URIs resolve as local files', () => {
  withMobileFixture({
    'root_source.dart': [
      "import 'features/alpha/internal.dart';",
      "import './features/alpha/internal.dart';",
      "import 'package:aarast_mobile/features/alpha/internal.dart';",
    ].join('\n'),
    'features/alpha/internal.dart': "import '../../core/helper.dart';\n",
    'core/helper.dart': "export '../features/alpha/internal.dart';\n",
  }, ({ mobileLib }) => {
    const scan = scanMobileBoundaries({ mobileLib });
    assert.deepEqual(scan.errors, []);
    assert.deepEqual(scan.records, [
      record({
        source: 'mobile/lib/core/helper.dart',
        target: 'mobile/lib/features/alpha/internal.dart',
      }),
    ]);
  });
});

test('same-feature and feature-to-core directives are allowed while counted forbidden edges are aggregated', () => {
  withMobileFixture({
    'core/routing/source.dart': [
      "import '../../features/alpha/internal.dart';",
      "export 'package:aarast_mobile/features/alpha/internal.dart';",
    ].join('\n'),
    'core/helper.dart': '',
    'features/alpha/internal.dart': "import '../../core/helper.dart';\n",
    'features/alpha/source.dart': [
      "import 'internal.dart';",
      "import '../beta/internal.dart';",
      "export 'package:aarast_mobile/features/beta/internal.dart';",
    ].join('\n'),
    'features/beta/internal.dart': '',
  }, ({ mobileLib }) => {
    assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
      records: [
        record({
          source: 'mobile/lib/core/routing/source.dart',
          target: 'mobile/lib/features/alpha/internal.dart',
          count: 2,
        }),
        record({
          source: 'mobile/lib/features/alpha/source.dart',
          target: 'mobile/lib/features/beta/internal.dart',
          sourceArea: 'features/alpha',
          targetArea: 'features/beta',
          kind: 'direct-cross-feature',
          count: 2,
        }),
      ],
      errors: [],
    });
  });
});

test('reciprocal URI-style same-feature part contracts pass for relative and package URIs', () => {
  withMobileFixture({
    'features/alpha/library.dart': "part 'child.dart';\n",
    'features/alpha/child.dart': "part of './library.dart';\n",
    'features/alpha/second_library.dart': (
      "part 'package:aarast_mobile/features/alpha/second_child.dart';\n"
    ),
    'features/alpha/second_child.dart': "part of 'second_library.dart';\n",
  }, ({ mobileLib }) => {
    assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
      records: [],
      errors: [],
    });
  });
});

test('missing local import, export, part, and part-of targets are scan errors', () => {
  withMobileFixture({
    'features/alpha/source.dart': [
      "import 'missing_import.dart';",
      "export './missing_export.dart';",
      "part 'missing_part.dart';",
    ].join('\n'),
    'features/alpha/child.dart': "part of 'missing_library.dart';\n",
  }, ({ mobileLib }) => {
    assert.deepEqual(scanMobileBoundaries({ mobileLib }).errors, [
      {
        source: 'mobile/lib/features/alpha/child.dart',
        target: 'mobile/lib/features/alpha/missing_library.dart',
        kind: 'unresolved-local-target',
      },
      {
        source: 'mobile/lib/features/alpha/source.dart',
        target: 'mobile/lib/features/alpha/missing_export.dart',
        kind: 'unresolved-local-target',
      },
      {
        source: 'mobile/lib/features/alpha/source.dart',
        target: 'mobile/lib/features/alpha/missing_import.dart',
        kind: 'unresolved-local-target',
      },
      {
        source: 'mobile/lib/features/alpha/source.dart',
        target: 'mobile/lib/features/alpha/missing_part.dart',
        kind: 'unresolved-local-target',
      },
    ]);
  });
});

test('cross-area parts fail even when both reciprocal files exist', () => {
  withMobileFixture({
    'core/library.dart': "part '../features/alpha/child.dart';\n",
    'features/alpha/child.dart': "part of '../../core/library.dart';\n",
  }, ({ mobileLib }) => {
    assert.deepEqual(scanMobileBoundaries({ mobileLib }).errors, [
      {
        source: 'mobile/lib/core/library.dart',
        target: 'mobile/lib/features/alpha/child.dart',
        kind: 'cross-area-part',
      },
    ]);
  });
});

test('missing reciprocity and name-style part-of declarations are invalid contracts', () => {
  withMobileFixture({
    'features/alpha/library.dart': "part 'child.dart';\n",
    'features/alpha/child.dart': '// missing part of\n',
    'features/alpha/orphan.dart': 'part of some.named.library;\n',
  }, ({ mobileLib }) => {
    assert.deepEqual(scanMobileBoundaries({ mobileLib }).errors, [
      {
        source: 'mobile/lib/features/alpha/library.dart',
        target: 'mobile/lib/features/alpha/child.dart',
        kind: 'invalid-part-contract',
      },
      {
        source: 'mobile/lib/features/alpha/orphan.dart',
        target: 'some.named.library',
        kind: 'invalid-part-contract',
      },
    ]);
  });
});

test('counted baseline comparison allows removal and decreases but rejects additions and increases', () => {
  const oldEdge = record({ count: 3 });
  const newEdge = record({
    source: 'mobile/lib/core/other.dart',
    target: 'mobile/lib/features/beta/internal.dart',
    targetArea: 'features/beta',
  });

  assert.deepEqual(compareMobileBaseline([], [oldEdge]), {
    ok: true,
    additions: [],
  });
  assert.deepEqual(compareMobileBaseline([{ ...oldEdge, count: 2 }], [oldEdge]), {
    ok: true,
    additions: [],
  });
  assert.deepEqual(
    compareMobileBaseline([{ ...oldEdge, count: 4 }, newEdge], [oldEdge]),
    { ok: false, additions: [newEdge, { ...oldEdge, count: 4 }] },
  );
});

test('strict mode allows only feature APIs and the narrow core routing composition exception', () => {
  const allowed = [
    record({
      source: 'mobile/lib/core/routing/app_router.dart',
    }),
    record({
      source: 'mobile/lib/features/alpha/source.dart',
      target: 'mobile/lib/features/beta/beta_api.dart',
      sourceArea: 'features/alpha',
      targetArea: 'features/beta',
      kind: 'direct-cross-feature',
    }),
  ];
  assert.equal(captureCli({
    argv: ['--strict'],
    scan: () => ({ records: allowed, errors: [] }),
  }).exitCode, 0);

  const forbidden = [
    record({ source: 'mobile/lib/core/network/api_client.dart' }),
    record({
      source: 'mobile/lib/core/routing/app_router.dart',
      target: 'mobile/lib/features/alpha/internal.dart',
    }),
    record({
      source: 'mobile/lib/features/alpha/source.dart',
      target: 'mobile/lib/features/beta/internal.dart',
      sourceArea: 'features/alpha',
      targetArea: 'features/beta',
      kind: 'direct-cross-feature',
    }),
  ];
  const result = captureCli({
    argv: ['--strict'],
    scan: () => ({ records: forbidden, errors: [] }),
  });
  assert.equal(result.exitCode, 1);
  assert.match(result.stderr.join('\n'), /strict mobile boundary violations \(3 records\)/);
});

test('every scan error kind fails write, check, and strict modes in canonical order', () => {
  const scanErrors = [
    {
      source: 'mobile/lib/features/beta/child.dart',
      target: 'mobile/lib/features/alpha/library.dart',
      kind: 'cross-area-part',
    },
    {
      source: 'mobile/lib/features/alpha/source.dart',
      target: 'mobile/lib/features/alpha/missing.dart',
      kind: 'unresolved-local-target',
    },
    {
      source: 'mobile/lib/features/alpha/library.dart',
      target: 'mobile/lib/features/alpha/child.dart',
      kind: 'invalid-part-contract',
    },
  ];
  for (const mode of ['--write-baseline', '--check-baseline', '--strict']) {
    let baselineAccessed = false;
    const result = captureCli({
      argv: [mode],
      scan: () => ({ records: [], errors: scanErrors }),
      readBaseline: () => {
        baselineAccessed = true;
        return baseline();
      },
      writeBaseline: () => {
        baselineAccessed = true;
      },
    });
    assert.equal(result.exitCode, 1, mode);
    assert.equal(baselineAccessed, false, mode);
    assert.deepEqual(result.stderr.slice(1), [
      'invalid-part-contract: mobile/lib/features/alpha/library.dart -> mobile/lib/features/alpha/child.dart',
      'unresolved-local-target: mobile/lib/features/alpha/source.dart -> mobile/lib/features/alpha/missing.dart',
      'cross-area-part: mobile/lib/features/beta/child.dart -> mobile/lib/features/alpha/library.dart',
    ]);
  }
});

test('dependency-injected CLI writes sorted metadata and returns 0, 1, and 2', () => {
  const alpha = record();
  const beta = record({
    source: 'mobile/lib/features/alpha/source.dart',
    target: 'mobile/lib/features/beta/beta_api.dart',
    sourceArea: 'features/alpha',
    targetArea: 'features/beta',
    kind: 'direct-cross-feature',
  });
  let written;
  const writeResult = captureCli({
    argv: ['--write-baseline'],
    scan: () => ({ records: [beta, alpha], errors: [] }),
    writeBaseline: (value) => {
      written = value;
    },
  });
  assert.equal(writeResult.exitCode, 0);
  assert.deepEqual(written, baseline([alpha, beta]));

  assert.equal(captureCli({
    scan: () => ({ records: [alpha], errors: [] }),
    readBaseline: () => baseline([alpha]),
  }).exitCode, 0);
  assert.equal(captureCli({
    scan: () => ({ records: [{ ...alpha, count: 2 }], errors: [] }),
    readBaseline: () => baseline([alpha]),
  }).exitCode, 1);
  assert.equal(captureCli({ argv: [] }).exitCode, 2);
  assert.equal(captureCli({ argv: ['--strict', '--check-baseline'] }).exitCode, 2);
  assert.equal(captureCli({ argv: ['--unknown'] }).exitCode, 2);
  assert.equal(captureCli({
    readBaseline: () => ({ ...baseline(), schemaVersion: 2 }),
  }).exitCode, 2);
});

test('baseline validation rejects malformed metadata, records, paths, counts, ordering, and secrets', () => {
  const alpha = record();
  const beta = record({
    source: 'mobile/lib/features/alpha/source.dart',
    target: 'mobile/lib/features/beta/beta_api.dart',
    sourceArea: 'features/alpha',
    targetArea: 'features/beta',
    kind: 'direct-cross-feature',
  });
  const malformed = [
    null,
    { ...baseline(), extra: true },
    { ...baseline(), sourceRevision: 'wrong' },
    { ...baseline(), records: 'not-an-array' },
    baseline([{ ...alpha, count: 0 }]),
    baseline([{ ...alpha, source: 'C:/Users/person/mobile/lib/core/source.dart' }]),
    baseline([{ ...alpha, target: '/tmp/mobile/lib/features/alpha/alpha_api.dart' }]),
    baseline([{ ...alpha, target: 'mobile/lib/features/alpha/../secret.dart' }]),
    baseline([{ ...alpha, target: 'TOKEN=do-not-print' }]),
    baseline([beta, alpha]),
    baseline([alpha, alpha]),
  ];

  for (const value of malformed) {
    const result = captureCli({ readBaseline: () => value });
    assert.equal(result.exitCode, 2, JSON.stringify(value));
    const diagnostic = result.stderr.join('\n');
    assert.doesNotMatch(
      diagnostic,
      /do-not-print|C:[\\/]|\/tmp\/|aarast-mobile-boundaries-|\bat\s+file:/i,
    );
  }
});

test('tracked baseline metadata and records are canonical, sorted, unique, counted, and secret-free', () => {
  const text = readFileSync(baselinePath, 'utf8');
  const value = JSON.parse(text);
  assert.deepEqual(Object.keys(value).sort(), [
    'records',
    'schemaVersion',
    'sourceRevision',
  ]);
  assert.equal(value.schemaVersion, 1);
  assert.equal(value.sourceRevision, sourceRevision);
  assert.ok(Array.isArray(value.records));

  const keys = value.records.map((item) => [
    item.source,
    item.target,
    item.sourceArea,
    item.targetArea,
    item.kind,
  ].join('|'));
  assert.deepEqual(keys, [...keys].sort());
  assert.equal(new Set(keys).size, keys.length);
  for (const item of value.records) {
    assert.deepEqual(Object.keys(item).sort(), [
      'count',
      'kind',
      'source',
      'sourceArea',
      'target',
      'targetArea',
    ]);
    assert.match(item.source, /^mobile\/lib\/(?!.*(?:^|\/)\.\.?(?:\/|$)).+\.dart$/);
    assert.match(item.target, /^mobile\/lib\/(?!.*(?:^|\/)\.\.?(?:\/|$)).+\.dart$/);
    assert.equal(Number.isInteger(item.count) && item.count > 0, true);
  }
  assert.doesNotMatch(
    text,
    /[A-Za-z]:[\\/]|(?:DATABASE_URL|JWT_SECRET|PASSWORD|SECRET|TOKEN)\s*=|BEGIN (?:RSA |OPENSSH )?PRIVATE KEY|:\/\//i,
  );

  assert.equal(captureCli({
    scan: () => ({ records: [], errors: [] }),
    readBaseline: () => value,
  }).exitCode, 0);
});

test('real wrapper rejects invalid arguments without absolute paths or stack traces', () => {
  const result = spawnSync(process.execPath, [scriptPath, '--unknown'], {
    cwd: path.join(repoRoot, 'mobile'),
    encoding: 'utf8',
  });
  assert.equal(result.status, 2);
  const diagnostic = `${result.stdout}\n${result.stderr}`;
  assert.match(diagnostic, /usage:/);
  assert.doesNotMatch(diagnostic, /[A-Za-z]:[\\/]|aarast-modular-monolith|Error:|\bat\s+file:/i);
});
