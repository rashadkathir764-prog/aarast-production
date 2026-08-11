import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
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

function expectedUnresolved(source, target) {
  return {
    records: [],
    errors: [{ source, target, kind: 'unresolved-local-target' }],
  };
}

function directoryLinkType() {
  return process.platform === 'win32' ? 'junction' : 'dir';
}

const localUriForms = [
  {
    name: 'bare',
    specifier: 'missing.dart',
    target: 'mobile/lib/features/alpha/nested/missing.dart',
  },
  {
    name: 'dot-relative',
    specifier: './missing.dart',
    target: 'mobile/lib/features/alpha/nested/missing.dart',
  },
  {
    name: 'parent-relative',
    specifier: '../missing.dart',
    target: 'mobile/lib/features/alpha/missing.dart',
  },
  {
    name: 'Aarast package',
    specifier: 'package:aarast_mobile/features/alpha/package_missing.dart',
    target: 'mobile/lib/features/alpha/package_missing.dart',
  },
];

for (const directive of ['import', 'export', 'part']) {
  for (const form of localUriForms) {
    test(`${directive} resolves its ${form.name} URI independently`, () => {
      withMobileFixture({
        'features/alpha/nested/source.dart': `${directive} '${form.specifier}';\n`,
      }, ({ mobileLib }) => {
        assert.deepEqual(
          scanMobileBoundaries({ mobileLib }),
          expectedUnresolved(
            'mobile/lib/features/alpha/nested/source.dart',
            form.target,
          ),
        );
      });
    });
  }
}

for (const form of localUriForms) {
  test(`part-of resolves its ${form.name} URI independently`, () => {
    withMobileFixture({
      'features/alpha/nested/source.dart': `part of '${form.specifier}';\n`,
    }, ({ mobileLib }) => {
      assert.deepEqual(
        scanMobileBoundaries({ mobileLib }),
        expectedUnresolved(
          'mobile/lib/features/alpha/nested/source.dart',
          form.target,
        ),
      );
    });
  });
}

for (const directive of ['import', 'export']) {
  test(`${directive} resolves every conditional URI alternative independently`, () => {
    withMobileFixture({
      'core/source.dart': [
        `${directive} '../features/alpha/primary.dart'`,
        "  if (dart.library.io) '../features/beta/native.dart'",
        "  if (dart.library.html) 'package:aarast_mobile/features/gamma/browser.dart';",
      ].join('\n'),
    }, ({ mobileLib }) => {
      assert.deepEqual(scanMobileBoundaries({ mobileLib }).errors, [
        {
          source: 'mobile/lib/core/source.dart',
          target: 'mobile/lib/features/alpha/primary.dart',
          kind: 'unresolved-local-target',
        },
        {
          source: 'mobile/lib/core/source.dart',
          target: 'mobile/lib/features/beta/native.dart',
          kind: 'unresolved-local-target',
        },
        {
          source: 'mobile/lib/core/source.dart',
          target: 'mobile/lib/features/gamma/browser.dart',
          kind: 'unresolved-local-target',
        },
      ]);
    });
  });
}

const decodedUriCases = [
  {
    name: 'hex escape',
    source: String.raw`import 'package:aarast_mobile/features/alpha/hex\x2edart';`,
    targetFile: 'features/alpha/hex.dart',
    target: 'mobile/lib/features/alpha/hex.dart',
  },
  {
    name: 'four-digit Unicode escape',
    source: String.raw`import 'package:aarast_mobile/features/alpha/unicode\u002edart';`,
    targetFile: 'features/alpha/unicode.dart',
    target: 'mobile/lib/features/alpha/unicode.dart',
  },
  {
    name: 'braced Unicode escape',
    source: String.raw`import 'package:aarast_mobile/features/alpha/braced\u{2e}dart';`,
    targetFile: 'features/alpha/braced.dart',
    target: 'mobile/lib/features/alpha/braced.dart',
  },
  {
    name: 'escaped single quote',
    source: String.raw`import 'package:aarast_mobile/features/alpha/child\'s.dart';`,
    targetFile: "features/alpha/child's.dart",
    target: "mobile/lib/features/alpha/child's.dart",
  },
  {
    name: 'identity escape',
    source: String.raw`import 'package:aarast_mobile/features/alpha/identity\q.dart';`,
    targetFile: 'features/alpha/identityq.dart',
    target: 'mobile/lib/features/alpha/identityq.dart',
  },
  {
    name: 'escaped dollar',
    source: String.raw`import 'package:aarast_mobile/features/alpha/money\$.dart';`,
    targetFile: 'features/alpha/money$.dart',
    target: 'mobile/lib/features/alpha/money$.dart',
  },
  {
    name: 'escaped slash',
    source: String.raw`import 'package:aarast_mobile/features/alpha/folder\/child.dart';`,
    targetFile: 'features/alpha/folder/child.dart',
    target: 'mobile/lib/features/alpha/folder/child.dart',
  },
  {
    name: 'escaped backslash',
    source: String.raw`import 'package:aarast_mobile/features/alpha/folder\\child.dart';`,
    targetFile: 'features/alpha/folder\\child.dart',
    target: 'mobile/lib/features/alpha/folder/child.dart',
  },
  {
    name: 'single-quoted raw string',
    source: String.raw`import r'package:aarast_mobile/features/alpha/raw\u002edart';`,
    targetFile: 'features/alpha/raw\\u002edart',
    target: 'mobile/lib/features/alpha/raw/u002edart',
  },
  {
    name: 'double-quoted raw string',
    source: String.raw`export r"package:aarast_mobile/features/alpha/raw\x2edart";`,
    targetFile: 'features/alpha/raw\\x2edart',
    target: 'mobile/lib/features/alpha/raw/x2edart',
  },
  {
    name: 'normal triple string',
    source: String.raw`import '''package:aarast_mobile/features/alpha/triple\u002edart''';`,
    targetFile: 'features/alpha/triple.dart',
    target: 'mobile/lib/features/alpha/triple.dart',
  },
  {
    name: 'raw triple string',
    source: String.raw`import r'''package:aarast_mobile/features/alpha/raw\u{2e}dart''';`,
    targetFile: 'features/alpha/raw\\u{2e}dart',
    target: 'mobile/lib/features/alpha/raw/u{2e}dart',
  },
  {
    name: 'multiline triple string ignored leading line',
    source: "import '''\npackage:aarast_mobile/features/alpha/multiline.dart''';",
    targetFile: 'features/alpha/multiline.dart',
    target: 'mobile/lib/features/alpha/multiline.dart',
  },
];

for (const item of decodedUriCases) {
  test(`Dart ${item.name} preserves exact URI resolution semantics`, () => {
    const files = {
      'core/source.dart': `${item.source}\n`,
    };
    if (item.targetFile) files[item.targetFile] = '';
    withMobileFixture(files, ({ mobileLib }) => {
      const actual = scanMobileBoundaries({ mobileLib });
      if (item.unresolvedTarget) {
        assert.deepEqual(
          actual,
          expectedUnresolved('mobile/lib/core/source.dart', item.unresolvedTarget),
        );
      } else {
        assert.deepEqual(actual, {
          records: [record({ target: item.target })],
          errors: [],
        });
      }
    });
  });
}

function tripleDirective({ raw = false, quote, firstLine = '', lineBreak, uri }) {
  const delimiter = quote.repeat(3);
  return `import ${raw ? 'r' : ''}${delimiter}${firstLine}${lineBreak}${uri}${delimiter};\n`;
}

const tripleForms = [
  { name: 'normal triple single quote', raw: false, quote: "'" },
  { name: 'normal triple double quote', raw: false, quote: '"' },
  { name: 'raw triple single quote', raw: true, quote: "'" },
  { name: 'raw triple double quote', raw: true, quote: '"' },
];

for (const form of tripleForms) {
  test(`${form.name} suppresses a whitespace-only first line`, () => {
    withMobileFixture({
      'core/source.dart': tripleDirective({
        ...form,
        firstLine: ' \t',
        lineBreak: '\n',
        uri: 'package:aarast_mobile/features/alpha/whitespace.dart',
      }),
      'features/alpha/whitespace.dart': '',
    }, ({ mobileLib }) => {
      assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
        records: [record({ target: 'mobile/lib/features/alpha/whitespace.dart' })],
        errors: [],
      });
    });
  });

  test(`${form.name} suppresses a backslash-prefixed whitespace first line`, () => {
    withMobileFixture({
      'core/source.dart': tripleDirective({
        ...form,
        firstLine: '\\ \t',
        lineBreak: '\n',
        uri: 'package:aarast_mobile/features/alpha/backslash.dart',
      }),
      'features/alpha/backslash.dart': '',
    }, ({ mobileLib }) => {
      assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
        records: [record({ target: 'mobile/lib/features/alpha/backslash.dart' })],
        errors: [],
      });
    });
  });

  test(`${form.name} retains a non-whitespace first line`, () => {
    withMobileFixture({
      'core/source.dart': tripleDirective({
        ...form,
        firstLine: 'prefix',
        lineBreak: '\n',
        uri: 'package:aarast_mobile/features/alpha/retained.dart',
      }),
    }, ({ mobileLib }) => {
      assert.deepEqual(
        scanMobileBoundaries({ mobileLib }),
        expectedUnresolved(
          'mobile/lib/core/source.dart',
          'mobile/lib/core/prefix\npackage:aarast_mobile/features/alpha/retained.dart',
        ),
      );
    });
  });

  for (const [lineBreakName, lineBreak] of [
    ['LF', '\n'],
    ['CRLF', '\r\n'],
    ['CR', '\r'],
  ]) {
    test(`${form.name} normalizes ${lineBreakName} to one newline`, () => {
      const delimiter = form.quote.repeat(3);
      const source = [
        `import ${form.raw ? 'r' : ''}${delimiter}`,
        'package:aarast_mobile/features/alpha/line',
        lineBreak,
        `break.dart${delimiter};\n`,
      ].join('');
      withMobileFixture({ 'core/source.dart': source }, ({ mobileLib }) => {
        assert.deepEqual(
          scanMobileBoundaries({ mobileLib }),
          expectedUnresolved(
            'mobile/lib/core/source.dart',
            'mobile/lib/features/alpha/line\nbreak.dart',
          ),
        );
      });
    });
  }
}

test('lowercase r is the only accepted Dart raw-string prefix', () => {
  assert.throws(
    () => parseDartDirectives("import R'package:aarast_mobile/features/alpha/child.dart';"),
    /invalid Dart source/,
  );
});

test('adjacent string tokens form one URI string literal in grammar position', () => {
  withMobileFixture({
    'core/source.dart': (
      "import 'package:aarast_mobile/features/' 'alpha/adjacent.dart';\n"
    ),
    'features/alpha/adjacent.dart': '',
  }, ({ mobileLib }) => {
    assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
      records: [record({ target: 'mobile/lib/features/alpha/adjacent.dart' })],
      errors: [],
    });
  });
});

test('valid configurable import grammar collects only target URIs', () => {
  const source = [
    "import '../features/alpha/primary.dart'",
    "  if (dart.library.io) '../features/beta/native.dart'",
    "  if (dart.library.html == 'true') '../features/gamma/browser.dart'",
    '  deferred as lazy_feature show First, Second hide Third;',
  ].join('\n');
  assert.deepEqual(parseDartDirectives(source), [{
    kind: 'import',
    uris: [
      '../features/alpha/primary.dart',
      '../features/beta/native.dart',
      '../features/gamma/browser.dart',
    ],
  }]);
});

test('valid configurable export grammar accepts ordered combinators', () => {
  const source = [
    "export '../features/alpha/primary.dart'",
    "  if (dart.library.io == 'enabled') '../features/beta/native.dart'",
    '  show First hide Second, Third;',
  ].join('\n');
  assert.deepEqual(parseDartDirectives(source), [{
    kind: 'export',
    uris: [
      '../features/alpha/primary.dart',
      '../features/beta/native.dart',
    ],
  }]);
});

test('valid immediate import accepts a direct as prefix', () => {
  assert.deepEqual(parseDartDirectives("import 'a.dart' as prefix;"), [{
    kind: 'import',
    uris: ['a.dart'],
  }]);
});

test('built-in dynamic is rejected as an import prefix', () => {
  assert.throws(
    () => parseDartDirectives("import 'a.dart' as dynamic;"),
    /invalid Dart source/,
  );
});

test('rejected dynamic prefix cannot smuggle configurable URIs or combinators', () => {
  assert.throws(
    () => parseDartDirectives(
      "import 'primary.dart' if (dart.library.io) 'smuggled.dart' as dynamic show Thing;",
    ),
    /invalid Dart source/,
  );
});

for (const prefix of ['type', 'base', 'sealed', 'when']) {
  test(`project Dart analyzer-compatible import prefix accepts ${prefix}`, () => {
    assert.deepEqual(parseDartDirectives(`import 'a.dart' as ${prefix};`), [{
      kind: 'import',
      uris: ['a.dart'],
    }]);
  });
}

test('valid URI test accepts built-in identifier library in a dotted name', () => {
  assert.deepEqual(parseDartDirectives(
    "import 'a.dart' if (dart.library.io) 'b.dart';",
  ), [{
    kind: 'import',
    uris: ['a.dart', 'b.dart'],
  }]);
});

test('allowed built-in and contextual identifiers remain valid in identifier positions', () => {
  assert.deepEqual(parseDartDirectives([
    "import 'a.dart' as async show library, type hide of;",
    'part of library.of.type;',
  ].join('\n')), [
    { kind: 'import', uris: ['a.dart'] },
    { kind: 'part-of', uris: [], name: 'library.of.type' },
  ]);
});

test('current unrestricted keywords remain valid across directive identifier positions', () => {
  assert.deepEqual(parseDartDirectives([
    "import 'a.dart' if (dart.base.sealed.when) 'b.dart' show base, sealed hide when;",
    'part of base.sealed.when;',
  ].join('\n')), [
    { kind: 'import', uris: ['a.dart', 'b.dart'] },
    { kind: 'part-of', uris: [], name: 'base.sealed.when' },
  ]);
});

test('built-in type remains valid in general identifier positions', () => {
  assert.deepEqual(parseDartDirectives([
    "export 'a.dart' if (dart.type.enabled) 'b.dart' show type;",
    'part of type.library;',
  ].join('\n')), [
    { kind: 'export', uris: ['a.dart', 'b.dart'] },
    { kind: 'part-of', uris: [], name: 'type.library' },
  ]);
});

test('built-in dynamic remains valid in general identifier positions', () => {
  assert.deepEqual(parseDartDirectives([
    "export 'a.dart' if (dart.dynamic.enabled) 'b.dart' show dynamic;",
    'part of dynamic.library;',
  ].join('\n')), [
    { kind: 'export', uris: ['a.dart', 'b.dart'] },
    { kind: 'part-of', uris: [], name: 'dynamic.library' },
  ]);
});

test('async await and yield contextual boundaries remain valid identifiers', () => {
  assert.deepEqual(parseDartDirectives([
    "import 'a.dart' as async show await, yield;",
    'part of await.yield;',
  ].join('\n')), [
    { kind: 'import', uris: ['a.dart'] },
    { kind: 'part-of', uris: [], name: 'await.yield' },
  ]);
});

const reservedDirectiveIdentifiers = [
  {
    name: 'URI-test first component if',
    source: "import 'a.dart' if (if.foo) 'smuggled.dart';",
  },
  {
    name: 'URI-test inner component if',
    source: "import 'a.dart' if (dart.if.foo) 'smuggled.dart';",
  },
  { name: 'import prefix if', source: "import 'a.dart' as if;" },
  { name: 'show name if', source: "import 'a.dart' show if;" },
  { name: 'hide name if', source: "import 'a.dart' hide if;" },
  { name: 'name-style part-of if', source: 'part of if.foo;' },
  {
    name: 'URI-test first component true',
    source: "export 'a.dart' if (true.library) 'smuggled.dart';",
  },
  {
    name: 'URI-test inner component null',
    source: "export 'a.dart' if (dart.null) 'smuggled.dart';",
  },
  { name: 'import prefix return', source: "import 'a.dart' as return;" },
  { name: 'built-in non-type prefix library', source: "import 'a.dart' as library;" },
  { name: 'show name true', source: "export 'a.dart' show true;" },
  { name: 'hide name null', source: "export 'a.dart' hide null;" },
  { name: 'name-style part-of return', source: 'part of return.library;' },
];

for (const item of reservedDirectiveIdentifiers) {
  test(`invalid Dart directive identifier fails closed in ${item.name}`, () => {
    assert.throws(() => parseDartDirectives(item.source), /invalid Dart source/);
  });
}

const malformedDirectiveGrammar = [
  "import as 'child.dart';",
  "import deferred as prefix 'child.dart';",
  "export show Thing 'child.dart';",
  "part as 'child.dart';",
  "part of as 'library.dart';",
  "import 'primary.dart' as prefix 'later.dart';",
  "export 'primary.dart' show Thing 'later.dart';",
  "part 'child.dart' as 'later.dart';",
  "part of 'library.dart' show 'later.dart';",
];

for (const source of malformedDirectiveGrammar) {
  test(`malformed directive grammar fails closed: ${source}`, () => {
    assert.throws(() => parseDartDirectives(source), /invalid Dart source/);
  });
}

test('escaped double quote reaches resolution without silent retargeting', () => {
  withMobileFixture({
    'core/source.dart': `${String.raw`import "package:aarast_mobile/features/alpha/child\"name.dart";`}\n`,
  }, ({ mobileLib }) => {
    assert.deepEqual(
      scanMobileBoundaries({ mobileLib }),
      expectedUnresolved(
        'mobile/lib/core/source.dart',
        'mobile/lib/features/alpha/child"name.dart',
      ),
    );
  });
});

const controlEscapes = new Map([
  ['n', '\n'],
  ['r', '\r'],
  ['f', '\f'],
  ['b', '\b'],
  ['t', '\t'],
  ['v', '\v'],
]);

for (const [escape, decoded] of controlEscapes) {
  test(`Dart control escape \\${escape} is decoded before target resolution`, () => {
    withMobileFixture({
      'core/source.dart': `import 'package:aarast_mobile/features/alpha/control\\${escape}tail.dart';\n`,
    }, ({ mobileLib }) => {
      assert.deepEqual(
        scanMobileBoundaries({ mobileLib }),
        expectedUnresolved(
          'mobile/lib/core/source.dart',
          `mobile/lib/features/alpha/control${decoded}tail.dart`,
        ),
      );
    });
  });
}

const malformedDartSources = [
  "import 'child\\x2.dart';",
  "import 'child\\xGG.dart';",
  "import 'child\\u123.dart';",
  "import 'child\\u{}.dart';",
  "import 'child\\u{110000}.dart';",
  "import 'child\\u{D800}.dart';",
  "import 'child${suffix}.dart';",
  "import 'child.dart;",
  "import '''child.dart;",
  "import 'child.dart'",
  "import 'child\n.dart';",
];

for (const source of malformedDartSources) {
  test(`malformed Dart directive fails closed: ${JSON.stringify(source)}`, () => {
    assert.throws(
      () => parseDartDirectives(source),
      /invalid Dart source/,
    );
  });
}

test('package-form reciprocal part and part-of pair passes', () => {
  withMobileFixture({
    'features/alpha/library.dart': (
      "part 'package:aarast_mobile/features/alpha/parts/child.dart';\n"
    ),
    'features/alpha/parts/child.dart': (
      "part of 'package:aarast_mobile/features/alpha/library.dart';\n"
    ),
  }, ({ mobileLib }) => {
    assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
      records: [],
      errors: [],
    });
  });
});

test('parent-relative reciprocal part and part-of pair passes', () => {
  withMobileFixture({
    'features/alpha/library/library.dart': "part '../parts/child.dart';\n",
    'features/alpha/parts/child.dart': "part of '../library/library.dart';\n",
  }, ({ mobileLib }) => {
    assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
      records: [],
      errors: [],
    });
  });
});

test('internal directory junction target is accepted under its logical URI', () => {
  withMobileFixture({
    'core/source.dart': "import '../features/alpha/logical/target.dart';\n",
    'features/alpha/real/target.dart': '',
  }, ({ mobileLib }) => {
    const realDirectory = path.join(mobileLib, 'features', 'alpha', 'real');
    const logicalDirectory = path.join(mobileLib, 'features', 'alpha', 'logical');
    symlinkSync(realDirectory, logicalDirectory, directoryLinkType());
    assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
      records: [record({
        target: 'mobile/lib/features/alpha/logical/target.dart',
      })],
      errors: [],
    });
  });
});

test('directory junction target outside mobile lib fails closed', () => {
  const external = mkdtempSync(path.join(os.tmpdir(), 'aarast-mobile-external-'));
  try {
    writeFileSync(path.join(external, 'target.dart'), '', 'utf8');
    withMobileFixture({
      'core/source.dart': "import '../features/alpha/external/target.dart';\n",
    }, ({ mobileLib }) => {
      const logicalDirectory = path.join(mobileLib, 'features', 'alpha', 'external');
      mkdirSync(path.dirname(logicalDirectory), { recursive: true });
      symlinkSync(external, logicalDirectory, directoryLinkType());
      assert.deepEqual(
        scanMobileBoundaries({ mobileLib }),
        expectedUnresolved(
          'mobile/lib/core/source.dart',
          'mobile/lib/features/alpha/external/target.dart',
        ),
      );
    });
  } finally {
    rmSync(external, { recursive: true, force: true });
  }
});

test('dangling directory junction target fails closed', () => {
  const removedTarget = mkdtempSync(path.join(os.tmpdir(), 'aarast-mobile-dangling-'));
  const removedFile = path.join(removedTarget, 'target.dart');
  writeFileSync(removedFile, '', 'utf8');
  withMobileFixture({
    'core/source.dart': "import '../features/alpha/dangling/target.dart';\n",
  }, ({ mobileLib }) => {
    const logicalDirectory = path.join(mobileLib, 'features', 'alpha', 'dangling');
    mkdirSync(path.dirname(logicalDirectory), { recursive: true });
    symlinkSync(removedTarget, logicalDirectory, directoryLinkType());
    rmSync(removedTarget, { recursive: true, force: true });
    assert.deepEqual(
      scanMobileBoundaries({ mobileLib }),
      expectedUnresolved(
        'mobile/lib/core/source.dart',
        'mobile/lib/features/alpha/dangling/target.dart',
      ),
    );
  });
});

test('configuration diagnostics redact every absolute path family and later lines', () => {
  const dangerousPaths = [
    'C:\\Users\\person\\secret.txt',
    '/tmp/person/secret.txt',
    '\\\\server\\share\\secret.txt',
    '\\\\?\\C:\\Users\\person\\secret.txt',
    '\\\\?\\UNC\\server\\share\\secret.txt',
  ];
  for (const dangerousPath of dangerousPaths) {
    const result = captureCli({
      scan: () => {
        throw new Error(`cannot read ${dangerousPath}\nsecond line at file:///secret`);
      },
    });
    assert.equal(result.exitCode, 2);
    assert.equal(result.stderr.length, 1);
    assert.equal(result.stderr[0], 'mobile boundary configuration error');
  }
});

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
