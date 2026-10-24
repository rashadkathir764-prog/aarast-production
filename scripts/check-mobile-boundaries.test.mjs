import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  existsSync,
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

import * as mobileBoundaries from './check-mobile-boundaries.mjs';

const {
  compareMobileBaseline,
  parseDartDirectives,
  runCli,
  scanMobileBoundaries,
} = mobileBoundaries;

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..');
const scriptPath = path.join(scriptDir, 'check-mobile-boundaries.mjs');
const baselinePath = path.join(
  scriptDir,
  'architecture',
  'mobile-boundaries-baseline.json',
);
const r9ManifestPath = path.join(
  scriptDir,
  'architecture',
  'r9-mobile-strict-manifest.json',
);
const sourceRevision = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';
const unresolvedTargetPlaceholder = 'mobile/lib/__unresolved_local_target__.dart';

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

function assertConfigurationFailure(result) {
  assert.equal(result.exitCode, 2);
  assert.deepEqual(result.stdout, []);
  assert.deepEqual(result.stderr, ['mobile boundary configuration error']);
}

function expectedUnresolved(source, target) {
  const safeTarget = (
    typeof target === 'string'
    && target.startsWith('mobile/lib/')
    && target.endsWith('.dart')
    && !/[\\\u0000-\u001F\u007F-\u009F:=?*"<>|%]/.test(target)
    && target.split('/').slice(2).every((segment) => (
      segment !== ''
      && segment !== '.'
      && segment !== '..'
      && /^[A-Za-z0-9_.$'{}@+-]+$/.test(segment)
    ))
  ) ? target : unresolvedTargetPlaceholder;
  return {
    records: [],
    errors: [{ source, target: safeTarget, kind: 'unresolved-local-target' }],
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
  assert.deepEqual(
    parseDartDirectives(String.raw`import "package:aarast_mobile/features/alpha/child\"name.dart";`),
    [{
      kind: 'import',
      uris: ['package:aarast_mobile/features/alpha/child"name.dart'],
    }],
  );
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
    assert.deepEqual(
      parseDartDirectives(
        `import 'package:aarast_mobile/features/alpha/control\\${escape}tail.dart';`,
      ),
      [{
        kind: 'import',
        uris: [`package:aarast_mobile/features/alpha/control${decoded}tail.dart`],
      }],
    );
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

for (const item of [
  {
    name: 'relative import',
    directive: "import 'logical_beta/target.dart';",
  },
  {
    name: 'package export',
    directive: "export 'package:aarast_mobile/features/alpha/logical_beta/target.dart';",
  },
  {
    name: 'conditional import alternative',
    directive: [
      "import 'same.dart'",
      "  if (dart.library.io) 'logical_beta/target.dart';",
    ].join('\n'),
  },
]) {
  test(`cross-feature directory junction cannot hide a ${item.name}`, () => {
    withMobileFixture({
      'features/alpha/source.dart': item.directive,
      'features/alpha/same.dart': '',
      'features/beta/real/target.dart': '',
    }, ({ mobileLib }) => {
      const realDirectory = path.join(mobileLib, 'features', 'beta', 'real');
      const logicalDirectory = path.join(
        mobileLib,
        'features',
        'alpha',
        'logical_beta',
      );
      symlinkSync(realDirectory, logicalDirectory, directoryLinkType());
      assert.deepEqual(scanMobileBoundaries({ mobileLib }), expectedUnresolved(
        'mobile/lib/features/alpha/source.dart',
        'mobile/lib/features/alpha/logical_beta/target.dart',
      ));
    });
  });
}

test('same-feature junction part aliases use canonical identity for reciprocity', () => {
  withMobileFixture({
    'features/alpha/library.dart': "part 'logical_parts/child.dart';\n",
    'features/alpha/parts/child.dart': "part of '../library.dart';\n",
  }, ({ mobileLib }) => {
    const realDirectory = path.join(mobileLib, 'features', 'alpha', 'parts');
    const logicalDirectory = path.join(
      mobileLib,
      'features',
      'alpha',
      'logical_parts',
    );
    symlinkSync(realDirectory, logicalDirectory, directoryLinkType());
    assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
      records: [],
      errors: [],
    });
  });
});

test('cross-feature junction part aliases fail closed before reciprocity can mask them', () => {
  withMobileFixture({
    'features/alpha/library.dart': "part 'logical_beta/child.dart';\n",
    'features/beta/parts/child.dart': "part of '../../alpha/library.dart';\n",
  }, ({ mobileLib }) => {
    const realDirectory = path.join(mobileLib, 'features', 'beta', 'parts');
    const logicalDirectory = path.join(
      mobileLib,
      'features',
      'alpha',
      'logical_beta',
    );
    symlinkSync(realDirectory, logicalDirectory, directoryLinkType());
    const scan = scanMobileBoundaries({ mobileLib });
    assert.ok(scan.errors.some((entry) => (
      entry.source === 'mobile/lib/features/alpha/library.dart'
      && entry.target === 'mobile/lib/features/alpha/logical_beta/child.dart'
      && entry.kind === 'unresolved-local-target'
    )));
    assert.ok(scan.errors.length > 0);
  });
});

test('source directory junction cannot spoof the canonical source feature area', () => {
  withMobileFixture({
    'features/alpha/target.dart': '',
    'features/beta/real/source.dart': "import '../../alpha/target.dart';\n",
  }, ({ mobileLib }) => {
    const realDirectory = path.join(mobileLib, 'features', 'beta', 'real');
    const logicalDirectory = path.join(
      mobileLib,
      'features',
      'alpha',
      'logical_beta_source',
    );
    symlinkSync(realDirectory, logicalDirectory, directoryLinkType());
    assert.deepEqual(scanMobileBoundaries({ mobileLib }), {
      records: [record({
        source: 'mobile/lib/features/beta/real/source.dart',
        target: 'mobile/lib/features/alpha/target.dart',
        sourceArea: 'features/beta',
        targetArea: 'features/alpha',
        kind: 'direct-cross-feature',
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

const interpolationStringCases = [
  {
    name: 'double-quoted outer with a nested normal string',
    source: "final value = \"${\"import 'smuggled.dart';\"}\";",
  },
  {
    name: 'single-quoted outer with a nested normal string',
    source: "final value = '${\"export 'smuggled.dart';\"}';",
  },
  {
    name: 'triple-quoted outer with a nested triple string',
    source: `final value = \"\"\"\${'''part 'smuggled.dart';'''}\"\"\";`,
  },
  {
    name: 'raw triple-quoted outer',
    source: `final value = r'''\${\"import 'smuggled.dart';\"}''';`,
  },
  {
    name: 'nested raw string',
    source: `final value = \"\${r\"export 'smuggled.dart';\"}\";`,
  },
  {
    name: 'nested braces maps and comments',
    source: `final value = \"\${{
      'key': \"import 'smuggled.dart';\",
      /* a } and \" must not close the expression or outer string */
      'nested': {'value': \"part 'smuggled.dart';\"},
    }}\";`,
  },
  {
    name: 'escaped dollar',
    source: `final value = \"\\\${import 'smuggled.dart';}\";`,
  },
  {
    name: 'dollar identifier',
    source: `final value = \"$value import 'smuggled.dart';\";`,
  },
  {
    name: 'nested interpolation',
    source: `final value = \"\${\"\${\"part 'smuggled.dart';\"}\"}\";`,
  },
];

for (const item of interpolationStringCases) {
  test(`Dart interpolation lexer ignores directives in ${item.name}`, () => {
    assert.deepEqual(
      parseDartDirectives(`${item.source}\nimport 'real.dart';`),
      [{ kind: 'import', uris: ['real.dart'] }],
    );
  });
}

test('Dart interpolation lexer ignores nested part text and still finds a real part', () => {
  const source = [
    `final value = \"\${\"part 'smuggled.dart';\"}\";`,
    "part 'real.dart';",
  ].join('\n');
  assert.deepEqual(parseDartDirectives(source), [
    { kind: 'part', uris: ['real.dart'] },
  ]);
});

const malformedInterpolationSources = [
  `final value = \"\${\"unterminated nested string}\";`,
  `final value = \"\${{'key': 1}\";`,
  `final value = \"\${/* unterminated comment }\";`,
  `final value = \"\${\"\${value}\"\";`,
];

for (const source of malformedInterpolationSources) {
  test(`malformed Dart interpolation fails closed: ${JSON.stringify(source)}`, () => {
    assert.throws(() => parseDartDirectives(source), /invalid Dart source/);
  });
}

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
        target: unresolvedTargetPlaceholder,
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
      'invalid-part-contract: mobile/lib/features/alpha/library.dart',
      'unresolved-local-target: mobile/lib/features/alpha/source.dart',
      'cross-area-part: mobile/lib/features/beta/child.dart',
    ]);
  }
});

for (const [name, escaped] of [
  ['LF', String.raw`\nTOKEN=reflected`],
  ['CR', String.raw`\rTOKEN=reflected`],
  ['tab', String.raw`\tTOKEN=reflected`],
  ['form feed', String.raw`\fTOKEN=reflected`],
  ['backspace', String.raw`\bTOKEN=reflected`],
  ['vertical tab', String.raw`\vTOKEN=reflected`],
  ['NUL', String.raw`\x00TOKEN=reflected`],
]) {
  test(`decoded ${name} in a local URI cannot inject CLI diagnostics`, () => {
    withMobileFixture({
      'core/source.dart': `import 'missing${escaped}.dart';\n`,
    }, ({ mobileLib }) => {
      const result = captureCli({
        scan: () => scanMobileBoundaries({ mobileLib }),
      });
      assert.equal(result.exitCode, 1);
      assert.deepEqual(result.stdout, []);
      assert.deepEqual(result.stderr, [
        'mobile boundary scan errors (1 records)',
        'unresolved-local-target: mobile/lib/core/source.dart',
      ]);
      assert.doesNotMatch(result.stderr.join('\n'), /TOKEN=reflected|[\u0000-\u0009\u000B-\u001F\u007F]/);
    });
  });
}

test('legitimate unresolved and part errors remain useful fixed exit-1 diagnostics', () => {
  withMobileFixture({
    'features/alpha/library.dart': "part 'child.dart';\n",
    'features/alpha/child.dart': '// missing reciprocal part-of\n',
    'features/alpha/missing.dart': "import 'not_found.dart';\n",
    'features/alpha/orphan.dart': 'part of some.named.library;\n',
  }, ({ mobileLib }) => {
    const result = captureCli({
      scan: () => scanMobileBoundaries({ mobileLib }),
    });
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.stderr, [
      'mobile boundary scan errors (3 records)',
      'invalid-part-contract: mobile/lib/features/alpha/library.dart',
      'unresolved-local-target: mobile/lib/features/alpha/missing.dart',
      'invalid-part-contract: mobile/lib/features/alpha/orphan.dart',
    ]);
    assert.doesNotMatch(result.stderr.join('\n'), /child\.dart|not_found\.dart|some\.named\.library/);
  });
});

const unsafeDiagnosticPaths = [
  '',
  '../mobile/lib/core/source.dart',
  'mobile/lib/core/../source.dart',
  'mobile\\lib\\core\\source.dart',
  'C:/mobile/lib/core/source.dart',
  'C:\\mobile\\lib\\core\\source.dart',
  '\\\\server\\share\\source.dart',
  '/mobile/lib/core/source.dart',
  'file:///mobile/lib/core/source.dart',
  'package:aarast_mobile/core/source.dart',
  'mobile/lib/core/TOKEN=reflected.dart',
  'mobile/lib/core/source.dart\nTOKEN=reflected',
  'mobile/lib/core/source.dart\0TOKEN=reflected',
];

for (const field of ['source', 'target']) {
  for (const value of unsafeDiagnosticPaths) {
    test(`scan error rejects unsafe ${field} atomically: ${JSON.stringify(value)}`, () => {
      const valid = {
        source: 'mobile/lib/core/source.dart',
        target: 'mobile/lib/core/missing.dart',
        kind: 'unresolved-local-target',
      };
      const result = captureCli({
        scan: () => ({
          records: [],
          errors: [valid, { ...valid, [field]: value }],
        }),
      });
      assertConfigurationFailure(result);
    });
  }
}

test('scan error rejects an arbitrary message without reflecting any partial result', () => {
  const result = captureCli({
    scan: () => ({
      records: [],
      errors: [{
        source: 'mobile/lib/core/source.dart',
        target: 'mobile/lib/core/missing.dart',
        kind: 'unresolved-local-target',
        message: 'TOKEN=reflected\nforged diagnostic',
      }],
    }),
  });
  assertConfigurationFailure(result);
});

test('scan results reject duplicate records and errors before output', () => {
  const edge = record();
  const error = {
    source: 'mobile/lib/core/source.dart',
    target: 'mobile/lib/core/missing.dart',
    kind: 'unresolved-local-target',
  };
  for (const scan of [
    { records: [edge, { ...edge }], errors: [] },
    { records: [], errors: [error, { ...error }] },
  ]) {
    assertConfigurationFailure(captureCli({ scan: () => scan }));
  }
});

test('scan validation rejects prototypes, accessors, proxies, symbols, BigInt, and sparse arrays', () => {
  let getterCalls = 0;
  const accessorRecord = record();
  Object.defineProperty(accessorRecord, 'source', {
    enumerable: true,
    get() {
      getterCalls += 1;
      return 'mobile/lib/core/source.dart';
    },
  });
  const inheritedRecord = Object.assign(Object.create({ inherited: true }), record());
  const symbolRecord = record();
  symbolRecord[Symbol('hidden')] = 'TOKEN=reflected';
  const transparentProxy = new Proxy(record(), {});
  const throwingProxy = new Proxy(record(), {
    get() {
      throw new Error('TOKEN=reflected');
    },
  });
  const sparseRecords = [];
  sparseRecords.length = 3;
  sparseRecords[2] = record();

  const scans = [
    { records: [accessorRecord], errors: [] },
    { records: [inheritedRecord], errors: [] },
    { records: [symbolRecord], errors: [] },
    { records: [transparentProxy], errors: [] },
    { records: [throwingProxy], errors: [] },
    { records: [{ ...record(), count: 1n }], errors: [] },
    { records: [{ ...record(), source: Symbol('source') }], errors: [] },
    { records: sparseRecords, errors: [] },
  ];
  for (const scan of scans) {
    assertConfigurationFailure(captureCli({ scan: () => scan }));
  }
  assert.equal(getterCalls, 0);
});

test('scan validation rejects oversized arrays before writer or baseline access', () => {
  let downstreamAccessed = false;
  const result = captureCli({
    argv: ['--write-baseline'],
    scan: () => ({
      records: Array.from({ length: 10_001 }, () => record()),
      errors: [],
    }),
    writeBaseline: () => {
      downstreamAccessed = true;
    },
  });
  assertConfigurationFailure(result);
  assert.equal(downstreamAccessed, false);
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

test('baseline validation rejects hostile object and array shapes without invoking accessors', () => {
  let getterCalls = 0;
  const accessorBaseline = baseline();
  Object.defineProperty(accessorBaseline, 'records', {
    enumerable: true,
    get() {
      getterCalls += 1;
      return [];
    },
  });
  const inheritedBaseline = Object.assign(Object.create({ inherited: true }), baseline());
  const symbolBaseline = baseline();
  symbolBaseline[Symbol('hidden')] = 'TOKEN=reflected';
  const proxyBaseline = new Proxy(baseline(), {});
  const sparseBaselineRecords = [];
  sparseBaselineRecords.length = 3;
  sparseBaselineRecords[2] = record();

  for (const value of [
    accessorBaseline,
    inheritedBaseline,
    symbolBaseline,
    proxyBaseline,
    baseline(sparseBaselineRecords),
    { ...baseline(), schemaVersion: 1n },
    { ...baseline(), sourceRevision: Symbol('revision') },
  ]) {
    assertConfigurationFailure(captureCli({ readBaseline: () => value }));
  }
  assert.equal(getterCalls, 0);
});

test('scan error objects reject accessors and proxies without reflecting traps', () => {
  let getterCalls = 0;
  const accessorError = {
    source: 'mobile/lib/core/source.dart',
    target: 'mobile/lib/core/missing.dart',
    kind: 'unresolved-local-target',
  };
  Object.defineProperty(accessorError, 'target', {
    enumerable: true,
    get() {
      getterCalls += 1;
      return 'mobile/lib/core/missing.dart';
    },
  });
  const proxyError = new Proxy({
    source: 'mobile/lib/core/source.dart',
    target: 'mobile/lib/core/missing.dart',
    kind: 'unresolved-local-target',
  }, {});
  for (const error of [accessorError, proxyError]) {
    assertConfigurationFailure(captureCli({
      scan: () => ({ records: [], errors: [error] }),
    }));
  }
  assert.equal(getterCalls, 0);
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

function loadR9Manifest() {
  assert.equal(typeof mobileBoundaries.validateR9Manifest, 'function');
  return mobileBoundaries.validateR9Manifest(
    JSON.parse(readFileSync(r9ManifestPath, 'utf8')),
  );
}

const ownerApiComment = '// Owner-controlled public API. Cross-feature consumers import this library.';
// R19 (spec M6): the provider persona is its own feature area. The R9
// manifest stays the closed R9 record; these two facts are the live delta.
const r19ProviderPortalApi = Object.freeze({
  area: 'features/provider_portal',
  path: 'mobile/lib/features/provider_portal/provider_portal_api.dart',
});
// 172 at R19, +2 for the suggested tasks reading the catalogs owner API
// (V1 checklist 4.9, tracked in trackedPlanningBatchContracts), +2 for the
// suggested tasks reading the plan persona from the account context and the
// guest draft (field-test Q01), +1 for the provider's booking widgets reading
// the marketplace owner API (V1 checklist 4.6), +1 for the planning
// assistant reading the signed-in account from the auth owner API to keep
// each account's consent (V1 checklist 4.12), +4 for the journey start
// (groom journey a05 to a08) reading the starting items and task count from
// the finance, tasks and catalogs owner APIs and the cities from marketplace,
// +1 for a08b reading the plan kept on the phone from the onboarding owner
// API, so its name is not asked again, -1 for the home greeting by the
// plan's name instead of the onboarding persona copy (b02).
// +1 for f03 reading the plan's money items through the finance owner API,
// so «ضمن بندك» compares the price with the item's amount; -1 for the f09
// comparison, which no longer gates on the account itself (D14); +1 for
// f07 reading the plan's item through the finance owner API (D15); -1 for
// the old add-member screen, now g06's sheet inside the sharing feature
// (D29); +2 for w09 reading the account plan's money items through the
// finance owner API, from the migration service and the entry screen that
// builds it (D31); +1 for w38 knowing a plan kept on the phone, which has
// no reminder to send, through the auth owner API (D31). +3 for the plan's
// «+» kept by the owner (D33): its choices read the plan's signals and stage
// through the wedding plans owner API and open a payment or a payment date
// through the finance owner API, and the route shell reads the money rights
// through the finance owner API. +1 for x04 «تساعد في عرس أحد؟» knowing
// whether the person is signed in through the auth owner API (D34). +3 for
// q10 and q19 (D34): «حسابي» reads the participant's phone and role word
// through the sharing owner API, its participant sections read the paths,
// the signed-in account and the leave through the account contexts, auth
// and sharing owner APIs, and q19 reads the paths; the old shared plans
// screen's two records go with it. +12 for the participant's tabs (D34):
// x06's home reads the path, the account, the role word and the tasks
// through the account contexts, auth, sharing and tasks owner APIs; the
// participant shell builds each tab's page or lock from the account
// contexts, finance, guests, marketplace, sharing, tasks and wedding plans
// owner APIs; q05 reports a finished task to the home through the wedding
// plans owner API. +1 for the provider's offer form (D35), now its own file
// beside the requests tab, reading the request through the marketplace
// owner API.
const r19LegalRecordCount = 214;
const trackedOwnerApiContracts = [
  {
    area: 'features/account_contexts',
    path: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    exports: [
      { uri: 'data/account_contexts_api.dart', show: ['AccountContextsApi'] },
      {
        uri: 'models/account_context.dart',
        show: [
          'AccountContext',
          'AccountContextPermissionChange',
          'AccountContextPermissions',
          'AccountContextPersona',
          'AccountContextRole',
        ],
      },
      {
        uri: 'providers/account_context_controller.dart',
        show: ['AccountContextController'],
      },
      {
        uri: 'widgets/account_context_entry_gate.dart',
        show: ['AccountContextEntryGate'],
      },
      {
        uri: 'widgets/wedding_plan_context_gate.dart',
        show: [
          'SelectedWeddingPlanContextGate',
          'WeddingPlanContextGate',
          'WeddingPlanRouteAccess',
        ],
      },
    ],
  },
  {
    area: 'features/auth',
    path: 'mobile/lib/features/auth/auth_api.dart',
    exports: [
      { uri: 'data/auth_repository.dart', show: ['AuthRepository'] },
      { uri: 'providers/auth_controller.dart', show: ['AuthController', 'AuthStatus'] },
      { uri: 'screens/login_screen.dart', show: ['LoginScreen'] },
      { uri: 'screens/otp_screen.dart', show: ['OtpScreen', 'OtpScreenArgs'] },
      { uri: 'screens/register_screen.dart', show: ['RegisterScreen'] },
      { uri: 'screens/reset_password_screen.dart', show: ['ResetPasswordScreen'] },
      { uri: 'screens/splash_screen.dart', show: ['SplashScreen'] },
      { uri: 'utils/auth_action_guard.dart', show: ['AuthActionGuard', 'AuthGatePanel'] },
      { uri: 'widgets/account_deletion_flow.dart', show: ['confirmAccountDeletion'] },
      {
        uri: 'widgets/auth_wedding_widgets.dart',
        show: ['AuthObscureToggle', 'AuthTextField'],
      },
    ],
  },
  {
    area: 'features/catalogs',
    path: 'mobile/lib/features/catalogs/catalogs_api.dart',
    exports: [
      { uri: 'data/reference_catalog_api.dart', show: ['ReferenceCatalogApi'] },
      {
        uri: 'models/reference_catalog.dart',
        show: ['ManagedReferenceCatalog', 'ManagedReferenceCatalogItem'],
      },
      {
        uri: 'providers/reference_catalog_provider.dart',
        show: ['ReferenceCatalogProvider'],
      },
    ],
  },
  {
    area: 'features/chat',
    path: 'mobile/lib/features/chat/chat_api.dart',
    exports: [
      { uri: 'data/chat_api.dart', show: ['ChatApi'] },
      { uri: 'data/chat_realtime_client.dart', show: ['ChatRealtimeClient'] },
      { uri: 'providers/chat_provider.dart', show: ['ChatProvider'] },
      { uri: 'screens/chat_screen.dart', show: ['ChatScreen'] },
      {
        uri: 'screens/quote_conversation_entry_screen.dart',
        show: ['QuoteConversationEntryScreen'],
      },
      { uri: 'widgets/conversation_list_view.dart', show: ['ConversationListView'] },
    ],
  },
  {
    area: 'features/finance',
    path: 'mobile/lib/features/finance/finance_api.dart',
    exports: [
      { uri: 'data/finance_api.dart', show: ['FinanceApi', 'LocalFinancePlanContext'] },
      { uri: 'data/funding_api.dart', show: ['FundingApi'] },
      { uri: 'providers/funding_provider.dart', show: ['FundingProvider'] },
      { uri: 'screens/funding_sources_screen.dart', show: ['FundingSourcesScreen'] },
      { uri: 'models/budget_category.dart', show: ['BudgetCategory'] },
      { uri: 'models/cost_draft_intent.dart', show: ['CostDraftIntent'] },
      {
        uri: 'models/money_starter_catalog.dart',
        show: ['moneyStarterPlanItemNames'],
      },
      { uri: 'models/wedding_cost.dart', show: ['WeddingCost'] },
      { uri: 'providers/finance_provider.dart', show: ['FinanceProvider'] },
      {
        uri: 'screens/budget_category_details_screen.dart',
        show: ['BudgetCategoryDetailsScreen'],
      },
      {
        uri: 'screens/budget_category_form_screen.dart',
        show: ['BudgetCategoryFormScreen'],
      },
      { uri: 'screens/cost_details_screen.dart', show: ['CostDetailsScreen'] },
      { uri: 'screens/cost_form_screen.dart', show: ['CostFormScreen'] },
      {
        uri: 'screens/cost_payment_screens.dart',
        show: [
          'CostPaymentDetailsScreen',
          'PayPaymentScheduleScreen',
          'RecordCostPaymentScreen',
        ],
      },
      { uri: 'screens/money_budget_screen.dart', show: ['MoneyBudgetScreen'] },
      {
        uri: 'screens/money_receipts_screen.dart',
        show: ['MoneyReceiptsScreen'],
      },
      {
        uri: 'screens/money_overview_screen.dart',
        show: ['MoneyOverviewScreen'],
      },
      {
        uri: 'widgets/money_cost_action_picker.dart',
        show: ['MoneyCostActionIntent', 'openMoneyCostAction'],
      },
      {
        uri: 'widgets/money_input_formatter.dart',
        show: ['MoneyInputFormatter', 'formatMoneyInputValue'],
      },
    ],
  },
  {
    area: 'features/guests',
    path: 'mobile/lib/features/guests/guests_api.dart',
    exports: [
      { uri: 'data/guests_api.dart', show: ['GuestsApi'] },
      { uri: 'models/guest.dart', show: ['GuestSummary'] },
      { uri: 'providers/guests_provider.dart', show: ['GuestsProvider'] },
      {
        uri: 'screens/guest_attendance_screen.dart',
        show: ['GuestAttendanceScreen'],
      },
      {
        uri: 'screens/guest_details_screen.dart',
        show: ['GuestDetailsScreen'],
      },
      {
        uri: 'screens/guest_import_screen.dart',
        show: ['GuestImportScreen', 'GuestImportSource'],
      },
      {
        uri: 'screens/guest_invite_screen.dart',
        show: ['GuestInviteScreen'],
      },
      { uri: 'screens/guest_list_screen.dart', show: ['GuestListScreen'] },
    ],
  },
  {
    area: 'features/home',
    path: 'mobile/lib/features/home/home_api.dart',
    exports: [
      {
        uri: 'data/dashboard_summary_sources.dart',
        show: ['LocalGuestDashboardSummary', 'LocalGuestDashboardSummarySource'],
      },
      {
        uri: 'providers/home_dashboard_provider.dart',
        show: ['HomeDashboardProvider'],
      },
      { uri: 'screens/dashboard_entry_screen.dart', show: ['DashboardEntryScreen'] },
    ],
  },
  {
    area: 'features/marketplace',
    path: 'mobile/lib/features/marketplace/marketplace_api.dart',
    exports: [
      {
        uri: 'data/marketplace_api.dart',
        show: ['MarketplaceApi', 'ProviderDashboardApi'],
      },
      // V1 checklist 4.6: the provider portal reads and decides bookings.
      {
        uri: 'models/marketplace_booking.dart',
        show: ['MarketplaceBooking', 'bookingErrorMessage', 'bookingStatusLabel'],
      },
      {
        uri: 'models/marketplace_models.dart',
        show: [
          'MarketplaceProvider',
          'MarketplaceService',
          // V1 checklist 4.18: the provider portal offers the admin's listing.
          'ProviderClaimableListing',
          'ProviderDashboardProfile',
          'ProviderDashboardSummary',
          'ProviderPackage',
          'ProviderReview',
          'ProviderServiceImage',
          'QuoteRequest',
        ],
      },
      {
        uri: 'models/provider_budget_match_intent.dart',
        show: ['ProviderBudgetMatchIntent', 'ProviderQuoteInitialContext'],
      },
      {
        uri: 'providers/marketplace_provider.dart',
        show: [
          'ProviderMarketplaceProvider',
          'marketplaceErrorMessage',
          'providerDirectoryErrorMessage',
          'providerReferenceDataErrorMessage',
        ],
      },
      {
        uri: 'screens/booking_moment_screen.dart',
        show: ['BookingMomentScreen'],
      },
      {
        uri: 'screens/favorite_providers_screen.dart',
        show: ['FavoriteProvidersScreen'],
      },
      { uri: 'screens/plan_bookings_screen.dart', show: ['PlanBookingsScreen'] },
      { uri: 'screens/provider_details_screen.dart', show: ['ProviderDetailsScreen'] },
      {
        uri: 'screens/provider_marketplace_screen.dart',
        show: ['ProviderMarketplaceScreen'],
      },
      {
        uri: 'screens/provider_requests_screen.dart',
        show: ['ProviderRequestsScreen'],
      },
      {
        uri: 'screens/provider_reviews_screen.dart',
        show: ['ProviderReviewsScreen'],
      },
      { uri: 'screens/quote_request_screen.dart', show: ['QuoteRequestScreen'] },
      { uri: 'widgets/provider_auth_gate.dart', show: ['ProviderAuthGate'] },
      {
        uri: 'widgets/provider_trust_signals.dart',
        show: ['providerRespondsLine'],
      },
      { uri: 'widgets/quote_status_chip.dart', show: ['QuoteStatusChip'] },
    ],
  },
  {
    area: 'features/more',
    path: 'mobile/lib/features/more/more_api.dart',
    exports: [{ uri: 'screens/more_screen.dart', show: ['MoreScreen'] }],
  },
  {
    area: 'features/notifications',
    path: 'mobile/lib/features/notifications/notifications_api.dart',
    exports: [
      { uri: 'data/notifications_api.dart', show: ['NotificationsApi'] },
      {
        uri: 'providers/notifications_provider.dart',
        show: ['NotificationsProvider'],
      },
      { uri: 'screens/notifications_screen.dart', show: ['NotificationsScreen'] },
    ],
  },
  {
    area: 'features/onboarding',
    path: 'mobile/lib/features/onboarding/onboarding_api.dart',
    exports: [
      {
        uri: 'data/guest_onboarding_storage.dart',
        show: ['GuestOnboardingStorage'],
      },
      {
        uri: 'data/local_plan_migration.dart',
        show: ['LocalPlanMigrationService', 'LocalPlanSnapshot'],
      },
      {
        uri: 'data/yemen_administrative_api.dart',
        show: ['YemenAdministrativeApi'],
      },
      { uri: 'models/generated_dashboard_seed.dart', show: ['GeneratedDashboardSeed'] },
      {
        uri: 'models/guest_onboarding_draft.dart',
        show: ['GuestOnboardingDraft', 'GuestOnboardingPath', 'GuestPersona'],
      },
      {
        uri: 'models/persona_copy.dart',
        show: ['appRoleLabel', 'personaCopyForGuest'],
      },
      {
        uri: 'models/wedding_location_draft.dart',
        show: ['WeddingLocationDraft'],
      },
      {
        uri: 'providers/yemen_administrative_provider.dart',
        show: ['YemenAdministrativeProvider'],
      },
      {
        uri: 'screens/local_plan_migration_screen.dart',
        show: ['LocalPlanMigrationScreen'],
      },
    ],
  },
  {
    area: 'features/provider_portal',
    path: 'mobile/lib/features/provider_portal/provider_portal_api.dart',
    exports: [
      {
        uri: 'providers/provider_dashboard_provider.dart',
        show: ['ProviderDashboardProvider'],
      },
      {
        uri: 'screens/add_provider_package_screen.dart',
        show: ['AddProviderPackageScreen'],
      },
      {
        uri: 'screens/add_provider_service_screen.dart',
        show: ['AddProviderServiceScreen'],
      },
      {
        uri: 'screens/edit_provider_profile_screen.dart',
        show: ['EditProviderProfileScreen'],
      },
      {
        uri: 'screens/provider_apply_screen.dart',
        show: ['ProviderApplyScreen', 'ProviderApplyStatusScreen'],
      },
      { uri: 'screens/provider_portal_screen.dart', show: ['ProviderPortalScreen'] },
    ],
  },
  {
    area: 'features/settings',
    path: 'mobile/lib/features/settings/settings_api.dart',
    exports: [
      { uri: 'data/settings_api.dart', show: ['SettingsApi'] },
      { uri: 'providers/settings_provider.dart', show: ['SettingsProvider'] },
      {
        uri: 'screens/lock_settings_screen.dart',
        show: ['LockSettingsScreen'],
      },
      { uri: 'screens/settings_screen.dart', show: ['SettingsScreen'] },
      {
        uri: 'widgets/change_phone_sheet.dart',
        show: ['showChangePhoneSheet'],
      },
    ],
  },
  {
    area: 'features/sharing',
    path: 'mobile/lib/features/sharing/sharing_api.dart',
    exports: [
      { uri: 'data/sharing_api.dart', show: ['SharingApi'] },
      {
        uri: 'models/participant_access.dart',
        show: ['participantPhone', 'participantRoleLabel', 'participantRoleTag'],
      },
      {
        uri: 'models/plan_access_permissions.dart',
        show: ['PlanAccessPermissions'],
      },
      {
        uri: 'models/shared_member.dart',
        show: ['SharedMember', 'sharedMemberRoleLabel'],
      },
      { uri: 'models/shared_wedding_plan.dart', show: ['SharedWeddingPlan'] },
      {
        uri: 'providers/contribution_history_provider.dart',
        show: ['ContributionHistoryProvider'],
      },
      { uri: 'providers/sharing_provider.dart', show: ['SharingProvider'] },
      {
        uri: 'screens/contribution_history_screen.dart',
        show: ['ContributionHistoryScreen'],
      },
      {
        uri: 'screens/edit_shared_member_screen.dart',
        show: ['EditSharedMemberScreen'],
      },
      { uri: 'screens/from_family_screen.dart', show: ['FromFamilyScreen'] },
      { uri: 'screens/invite_decision_screen.dart', show: ['InviteDecisionScreen'] },
      {
        uri: 'screens/participant_plan_state_screen.dart',
        show: ['ParticipantPlanStateScreen'],
      },
      { uri: 'screens/sharing_screen.dart', show: ['SharingScreen'] },
      {
        uri: 'services/plan_leave_coordinator.dart',
        show: ['PlanLeaveCoordinator'],
      },
    ],
  },
  {
    area: 'features/shell',
    path: 'mobile/lib/features/shell/shell_api.dart',
    exports: [
      { uri: 'main_shell.dart', show: ['MainShell'] },
      {
        uri: 'screens/participant_plan_shell.dart',
        show: ['participantPlanTab'],
      },
      { uri: 'screens/wedding_plan_shell.dart', show: ['WeddingPlanShell'] },
      {
        uri: 'widgets/aarast_plan_chrome.dart',
        show: ['AarastNavigationItem', 'AarastPlanNavigationBar'],
      },
      { uri: 'widgets/plan_quick_add.dart', show: ['PlanQuickAddSignals'] },
      {
        uri: 'widgets/plan_quick_add_sheet.dart',
        show: ['PlanQuickAddFlow'],
      },
      { uri: 'widgets/plan_shell_chrome.dart', show: ['PlanShellChrome'] },
    ],
  },
  {
    area: 'features/support',
    path: 'mobile/lib/features/support/support_api.dart',
    exports: [{ uri: 'screens/support_screen.dart', show: ['SupportScreen'] }],
  },
  {
    area: 'features/tasks',
    path: 'mobile/lib/features/tasks/tasks_api.dart',
    exports: [
      { uri: 'data/task_timeline_api.dart', show: ['TaskTimelineApi'] },
      {
        uri: 'models/task_starter_catalog.dart',
        show: ['taskStarterCountFor'],
      },
      { uri: 'models/task_summary.dart', show: ['TaskSummary'] },
      { uri: 'models/wedding_task.dart', show: ['WeddingTask'] },
      {
        uri: 'providers/task_timeline_provider.dart',
        show: ['TaskTimelineProvider'],
      },
      { uri: 'screens/create_task_screen.dart', show: ['CreateTaskScreen'] },
      {
        uri: 'screens/participant_tasks_screen.dart',
        show: ['ParticipantTasksScreen'],
      },
      { uri: 'screens/task_details_screen.dart', show: ['TaskDetailsScreen'] },
      { uri: 'screens/task_timeline_screen.dart', show: ['TaskTimelineScreen'] },
      { uri: 'utils/task_display.dart', show: ['taskCategoryIcon'] },
      { uri: 'widgets/task_row.dart', show: ['taskWhenLabel'] },
    ],
  },
  {
    area: 'features/wedding_day',
    path: 'mobile/lib/features/wedding_day/wedding_day_api.dart',
    exports: [
      {
        uri: 'models/wedding_day_mode.dart',
        show: ['WeddingDayModeStatus', 'WeddingDayPhase', 'resolveWeddingDayMode'],
      },
      {
        uri: 'screens/wedding_day_mode_screen.dart',
        show: ['WeddingDayModeScreen'],
      },
    ],
  },
  {
    area: 'features/wedding_plans',
    path: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    exports: [
      { uri: 'data/wedding_plans_api.dart', show: ['WeddingPlansApi'] },
      {
        uri: 'models/dashboard_summary.dart',
        show: [
          'DashboardFinancialWarning',
          'DashboardImportantItem',
          'DashboardMoneySummary',
          'DashboardNextPaymentSchedule',
          'DashboardPermissionSummary',
          'DashboardProviderPreview',
          'DashboardSummary',
        ],
      },
      {
        uri: 'models/onboarding_complete.dart',
        show: ['OnboardingCompleteRequest', 'OnboardingCompleteResponse'],
      },
      {
        uri: 'models/wedding_plan_stage.dart',
        show: ['WeddingPlanStage', 'WeddingPlanStageState', 'resolveWeddingPlanStage'],
      },
      { uri: 'models/wedding_plan.dart', show: ['WeddingPlan'] },
      {
        uri: 'providers/dashboard_summary_provider.dart',
        show: ['DashboardSummaryProvider'],
      },
      {
        uri: 'providers/wedding_plans_provider.dart',
        show: ['WeddingPlansProvider'],
      },
      {
        uri: 'screens/my_wedding_plans_screen.dart',
        show: ['MyWeddingPlansScreen', 'showPlanSwitcherSheet'],
      },
      {
        uri: 'screens/participant_home_screen.dart',
        show: ['ParticipantHomeScreen'],
      },
      {
        uri: 'screens/plan_assistant_screen.dart',
        show: ['PlanAssistantScreen'],
      },
      {
        uri: 'screens/plan_management_screen.dart',
        show: ['PlanCenterScreen'],
      },
      {
        uri: 'screens/wedding_plan_dashboard_screen.dart',
        show: ['WeddingPlanDashboardScreen'],
      },
      {
        uri: 'utils/plan_pulse_sync.dart',
        show: ['publishGuestPlanPulse', 'publishTaskPlanPulse'],
      },
      {
        uri: 'widgets/dashboard/aarast_dashboard_view.dart',
        show: ['AarastDashboardView'],
      },
      {
        uri: 'widgets/postpone_sheet.dart',
        show: ['showPostponeSheet'],
      },
    ],
  },
  {
    area: 'features/welcome_gateway',
    path: 'mobile/lib/features/welcome_gateway/welcome_gateway_api.dart',
    exports: [
      { uri: 'screens/smart_welcome_screen.dart', show: ['SmartWelcomeScreen'] },
    ],
  },
];

function renderOwnerApiContractFile(contract) {
  return [
    ownerApiComment,
    ...contract.exports.map(({ uri, show }) => `export '${uri}' show ${show.join(', ')};`),
    '',
  ].join('\n');
}

const trackedIdentityBatchContracts = [
  {
    source: 'mobile/lib/features/account_contexts/widgets/account_context_entry_gate.dart',
    target: 'mobile/lib/features/shell/shell_api.dart',
    show: ['MainShell'],
  },
  {
    source: 'mobile/lib/features/account_contexts/widgets/account_context_entry_gate.dart',
    target: 'mobile/lib/features/welcome_gateway/welcome_gateway_api.dart',
    show: ['SmartWelcomeScreen'],
  },
  {
    source: 'mobile/lib/features/account_contexts/widgets/wedding_plan_context_gate.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/auth/providers/auth_controller.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingStorage'],
  },
  {
    source: 'mobile/lib/features/auth/screens/otp_screen.dart',
    target: 'mobile/lib/features/provider_portal/provider_portal_api.dart',
    show: ['ProviderDashboardProvider'],
  },
  {
    source: 'mobile/lib/features/auth/screens/register_screen.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: [
      'ProviderMarketplaceProvider',
      'providerReferenceDataErrorMessage',
    ],
  },
  {
    source: 'mobile/lib/features/auth/screens/register_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingDraft', 'GuestOnboardingStorage'],
  },
  {
    source: 'mobile/lib/features/auth/screens/splash_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingStorage'],
  },
  {
    source: 'mobile/lib/features/onboarding/data/local_plan_migration.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceApi'],
  },
  {
    source: 'mobile/lib/features/onboarding/data/local_plan_migration.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['OnboardingCompleteResponse', 'WeddingPlansApi'],
  },
];

const trackedCollaborationBatchContracts = [
  {
    source: 'mobile/lib/features/marketplace/models/marketplace_models.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['WeddingLocationDraft'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_apply_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_apply_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_details_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContext', 'AccountContextController'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_details_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_details_screen.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceProvider'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart',
    target: 'mobile/lib/features/chat/chat_api.dart',
    show: ['ChatProvider', 'ConversationListView'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['CostDraftIntent', 'FinanceProvider'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingStorage', 'GuestPersona', 'WeddingLocationDraft'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['WeddingPlansProvider'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_requests_screen.dart',
    target: 'mobile/lib/features/chat/chat_api.dart',
    show: ['ChatApi'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_requests_screen.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceProvider'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/provider_requests_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummaryProvider'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_portal_screen.dart',
    target: 'mobile/lib/features/chat/chat_api.dart',
    show: ['ChatProvider', 'ConversationListView'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_profile_tab.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_profile_tab.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthController'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_profile_tab.dart',
    target: 'mobile/lib/features/chat/chat_api.dart',
    show: ['ChatProvider'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/quote_request_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/quote_request_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/quote_request_screen.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceProvider'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/quote_request_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingStorage', 'WeddingLocationDraft'],
  },
  {
    source: 'mobile/lib/features/marketplace/screens/quote_request_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummaryProvider', 'WeddingPlansProvider'],
  },
  {
    source: 'mobile/lib/features/provider_portal/widgets/provider_account_actions.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['confirmAccountDeletion'],
  },
  {
    source: 'mobile/lib/features/marketplace/widgets/provider_auth_gate.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/marketplace/widgets/provider_auth_gate.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/provider_portal/widgets/provider_portal_bottom_nav.dart',
    target: 'mobile/lib/features/shell/shell_api.dart',
    show: ['AarastNavigationItem', 'AarastPlanNavigationBar'],
  },
  // V1 checklist 4.6: the provider's booking panel and calendar.
  {
    source: 'mobile/lib/features/provider_portal/widgets/provider_bookings.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: ['MarketplaceBooking', 'bookingStatusLabel'],
  },
  {
    source: 'mobile/lib/features/more/screens/more_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController', 'AccountContextRole'],
  },
  {
    source: 'mobile/lib/features/more/screens/more_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/more/screens/more_screen.dart',
    target: 'mobile/lib/features/settings/settings_api.dart',
    show: ['showChangePhoneSheet'],
  },
  {
    source: 'mobile/lib/features/more/screens/more_screen.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['participantPhone', 'participantRoleLabel'],
  },
  {
    source: 'mobile/lib/features/more/screens/more_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummaryProvider', 'showPlanSwitcherSheet', 'showPostponeSheet'],
  },
  {
    source: 'mobile/lib/features/more/widgets/participant_account_sections.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: [
      'AccountContext',
      'AccountContextController',
      'AccountContextPermissions',
      'AccountContextPersona',
      'AccountContextRole',
    ],
  },
  {
    source: 'mobile/lib/features/more/widgets/participant_account_sections.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthController'],
  },
  {
    source: 'mobile/lib/features/more/widgets/participant_account_sections.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['PlanLeaveCoordinator'],
  },
  {
    source: 'mobile/lib/features/notifications/screens/notifications_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController', 'AccountContextRole'],
  },
  {
    source: 'mobile/lib/features/notifications/screens/notifications_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthGatePanel'],
  },
  {
    source: 'mobile/lib/features/settings/screens/settings_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthGatePanel'],
  },
  {
    source: 'mobile/lib/features/sharing/screens/edit_shared_member_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthGatePanel'],
  },
  {
    source: 'mobile/lib/features/sharing/screens/invite_decision_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/sharing/screens/from_family_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/sharing/screens/invite_decision_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/sharing/screens/participant_plan_state_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContext', 'AccountContextController', 'AccountContextRole'],
  },
  {
    source: 'mobile/lib/features/sharing/screens/sharing_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthGatePanel'],
  },
  // R19 provider_portal split: the provider-persona files moved out of
  // marketplace now read marketplace's models and discovery provider through
  // its owner API.
  {
    source: 'mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: ['ProviderDashboardProfile', 'ProviderMarketplaceProvider'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_apply_screen.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: ['ProviderMarketplaceProvider'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_portal_screen.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: ['ProviderDashboardProfile'],
  },
  {
    source: 'mobile/lib/features/provider_portal/screens/provider_profile_tab.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: ['MarketplaceService', 'ProviderDashboardProfile', 'ProviderReview'],
  },
];

const trackedPlanningBatchContracts = [
  {
    source: 'mobile/lib/features/finance/models/money_starter_catalog.dart',
    target: 'mobile/lib/features/catalogs/catalogs_api.dart',
    show: ['ManagedReferenceCatalog', 'ManagedReferenceCatalogItem'],
  },
  {
    source: 'mobile/lib/features/finance/providers/finance_provider.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['PlanAccessPermissions', 'SharingApi'],
  },
  {
    source: 'mobile/lib/features/finance/screens/cost_form_screen.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: ['MarketplaceProvider', 'ProviderMarketplaceProvider'],
  },
  {
    source: 'mobile/lib/features/finance/screens/cost_form_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummaryProvider'],
  },
  {
    source: 'mobile/lib/features/finance/screens/money_overview_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/finance/screens/money_overview_screen.dart',
    target: 'mobile/lib/features/catalogs/catalogs_api.dart',
    show: ['ReferenceCatalogProvider'],
  },
  {
    source: 'mobile/lib/features/finance/screens/money_overview_screen.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['SharedMember'],
  },
  {
    source: 'mobile/lib/features/finance/screens/money_overview_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummaryProvider', 'WeddingPlansProvider'],
  },
  {
    source: 'mobile/lib/features/finance/widgets/finance_write_access_block.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/guests/screens/guest_attendance_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/guests/screens/guest_list_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/guests/screens/guest_list_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['publishGuestPlanPulse'],
  },
  {
    source: 'mobile/lib/features/guests/screens/guest_details_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/guests/screens/guest_details_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['publishGuestPlanPulse'],
  },
  {
    source: 'mobile/lib/features/guests/screens/guest_import_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/guests/screens/guest_import_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['publishGuestPlanPulse'],
  },
  {
    source: 'mobile/lib/features/guests/screens/guest_invite_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummaryProvider'],
  },
  {
    source: 'mobile/lib/features/tasks/screens/create_task_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthController'],
  },
  {
    source: 'mobile/lib/features/tasks/screens/create_task_screen.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['SharedMember', 'SharingProvider'],
  },
  {
    source: 'mobile/lib/features/tasks/screens/create_task_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['publishTaskPlanPulse'],
  },
  {
    source: 'mobile/lib/features/tasks/screens/task_timeline_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthController'],
  },
  {
    source: 'mobile/lib/features/tasks/screens/task_timeline_screen.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['SharedMember', 'SharingProvider'],
  },
  // V1 checklist 4.9: the suggested tasks are the managed `tasks.starter`
  // catalog, read with the plan's persona and wedding date.
  {
    source: 'mobile/lib/features/tasks/screens/task_timeline_screen.dart',
    target: 'mobile/lib/features/catalogs/catalogs_api.dart',
    show: ['ReferenceCatalogProvider'],
  },
  {
    source: 'mobile/lib/features/tasks/models/task_starter_catalog.dart',
    target: 'mobile/lib/features/catalogs/catalogs_api.dart',
    show: ['ManagedReferenceCatalog'],
  },
  // The plan's persona comes from the selected account context, or from the
  // guest draft before sign-in — the same sources the money starter reads.
  {
    source: 'mobile/lib/features/tasks/screens/task_timeline_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/tasks/screens/task_timeline_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: [
      'DashboardSummaryProvider',
      'WeddingPlansProvider',
      'publishTaskPlanPulse',
    ],
  },
  {
    source: 'mobile/lib/features/tasks/screens/task_details_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['publishTaskPlanPulse'],
  },
  {
    source: 'mobile/lib/features/tasks/widgets/create_task_components.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['SharedMember'],
  },
  {
    source: 'mobile/lib/features/wedding_day/models/wedding_day_mode.dart',
    target: 'mobile/lib/features/tasks/tasks_api.dart',
    show: ['WeddingTask'],
  },
  {
    source: 'mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart',
    target: 'mobile/lib/features/home/home_api.dart',
    show: ['LocalGuestDashboardSummarySource'],
  },
  {
    source: 'mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingStorage'],
  },
  {
    source: 'mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart',
    target: 'mobile/lib/features/tasks/tasks_api.dart',
    show: ['TaskTimelineProvider', 'WeddingTask'],
  },
  {
    source: 'mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummary', 'DashboardSummaryProvider', 'publishTaskPlanPulse'],
  },
  {
    source: 'mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart',
    target: 'mobile/lib/features/tasks/tasks_api.dart',
    show: ['WeddingTask'],
  },
  {
    source: 'mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardProviderPreview', 'DashboardSummary'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/models/active_wedding_plan.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['WeddingLocationDraft'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/models/onboarding_complete.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['BudgetCategory'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/models/wedding_plan.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['WeddingLocationDraft'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/providers/dashboard_summary_provider.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['SharedMember'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/my_wedding_plans_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController', 'AccountContextRole'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/plan_management_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController', 'AccountContextRole'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/plan_management_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthController'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/plan_management_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingDraft', 'GuestOnboardingStorage'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/plan_management_screen.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['SharedMember'],
  },
  // w10 saves the wedding budget through the plan's money (D27).
  {
    source: 'mobile/lib/features/wedding_plans/screens/plan_management_screen.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceProvider'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/widgets/plan_details_view.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['MoneyInputFormatter', 'formatMoneyInputValue'],
  },
  // g03: after the wedding moves, the open tasks move by the same days.
  {
    source: 'mobile/lib/features/wedding_plans/widgets/postpone_sheet.dart',
    target: 'mobile/lib/features/tasks/tasks_api.dart',
    show: ['TaskTimelineApi'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard', 'AuthController'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceProvider'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
    target: 'mobile/lib/features/home/home_api.dart',
    show: ['LocalGuestDashboardSummary', 'LocalGuestDashboardSummarySource'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingStorage'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['SharedMember'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/utils/plan_pulse_sync.dart',
    target: 'mobile/lib/features/guests/guests_api.dart',
    show: ['GuestSummary'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/utils/plan_pulse_sync.dart',
    target: 'mobile/lib/features/tasks/tasks_api.dart',
    show: ['TaskSummary'],
  },
  {
    source: 'mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart',
    target: 'mobile/lib/features/wedding_day/wedding_day_api.dart',
    show: ['WeddingDayModeStatus', 'WeddingDayPhase', 'resolveWeddingDayMode'],
  },
];

const trackedShellEntryBatchContracts = [
  {
    source: 'mobile/lib/features/home/data/dashboard_summary_sources.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: [
      'GeneratedDashboardSeed',
      'GuestOnboardingDraft',
      'GuestOnboardingStorage',
      'GuestPersona',
    ],
  },
  {
    source: 'mobile/lib/features/home/data/dashboard_summary_sources.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: [
      'DashboardFinancialWarning',
      'DashboardImportantItem',
      'DashboardMoneySummary',
      'DashboardNextPaymentSchedule',
      'DashboardPermissionSummary',
      'DashboardSummary',
    ],
  },
  {
    source: 'mobile/lib/features/home/providers/home_dashboard_provider.dart',
    target: 'mobile/lib/features/sharing/sharing_api.dart',
    show: ['SharedWeddingPlan', 'SharingApi'],
  },
  {
    source: 'mobile/lib/features/home/providers/home_dashboard_provider.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['WeddingPlan', 'WeddingPlansApi'],
  },
  {
    source: 'mobile/lib/features/home/screens/dashboard_entry_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController', 'AccountContextEntryGate'],
  },
  {
    source: 'mobile/lib/features/home/screens/dashboard_entry_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/home/screens/dashboard_entry_screen.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceApi'],
  },
  {
    source: 'mobile/lib/features/home/screens/dashboard_entry_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: [
      'GuestOnboardingStorage',
      'LocalPlanMigrationScreen',
      'LocalPlanMigrationService',
      'LocalPlanSnapshot',
    ],
  },
  {
    source: 'mobile/lib/features/home/screens/dashboard_entry_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['WeddingPlansApi'],
  },
  {
    source: 'mobile/lib/features/home/screens/home_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthController'],
  },
  {
    source: 'mobile/lib/features/home/screens/home_screen.dart',
    target: 'mobile/lib/features/notifications/notifications_api.dart',
    show: ['NotificationsProvider'],
  },
  {
    source: 'mobile/lib/features/home/screens/local_guest_dashboard_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/home/screens/local_guest_dashboard_screen.dart',
    target: 'mobile/lib/features/shell/shell_api.dart',
    show: ['PlanQuickAddFlow', 'PlanQuickAddSignals', 'PlanShellChrome'],
  },
  {
    source: 'mobile/lib/features/home/screens/local_guest_dashboard_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: [
      'AarastDashboardView',
      'DashboardImportantItem',
      'DashboardSummary',
      'DashboardSummaryProvider',
    ],
  },
  {
    source: 'mobile/lib/features/shell/main_shell.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContext', 'AccountContextController', 'AccountContextRole'],
  },
  {
    source: 'mobile/lib/features/shell/main_shell.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceProvider', 'MoneyOverviewScreen'],
  },
  {
    source: 'mobile/lib/features/shell/main_shell.dart',
    target: 'mobile/lib/features/guests/guests_api.dart',
    show: ['GuestListScreen'],
  },
  {
    source: 'mobile/lib/features/shell/main_shell.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: ['ProviderMarketplaceScreen'],
  },
  {
    source: 'mobile/lib/features/shell/main_shell.dart',
    target: 'mobile/lib/features/tasks/tasks_api.dart',
    show: ['TaskTimelineScreen'],
  },
  {
    source: 'mobile/lib/features/shell/main_shell.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummaryProvider', 'WeddingPlanDashboardScreen'],
  },
  {
    source: 'mobile/lib/features/shell/screens/wedding_plan_shell.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController', 'AccountContextRole'],
  },
  {
    source: 'mobile/lib/features/shell/screens/wedding_plan_shell.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthActionGuard'],
  },
  {
    source: 'mobile/lib/features/shell/screens/wedding_plan_shell.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['FinanceProvider'],
  },
  {
    source: 'mobile/lib/features/shell/screens/wedding_plan_shell.dart',
    target: 'mobile/lib/features/home/home_api.dart',
    show: ['LocalGuestDashboardSummarySource'],
  },
  {
    source: 'mobile/lib/features/shell/screens/wedding_plan_shell.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: ['GuestOnboardingStorage'],
  },
  {
    source: 'mobile/lib/features/shell/screens/wedding_plan_shell.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummary', 'DashboardSummaryProvider'],
  },
  {
    source: 'mobile/lib/features/shell/widgets/plan_quick_add.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: ['MoneyCostActionIntent', 'openMoneyCostAction'],
  },
  {
    source: 'mobile/lib/features/shell/widgets/plan_quick_add.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['DashboardSummary', 'WeddingPlanStage', 'resolveWeddingPlanStage'],
  },
  {
    source: 'mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
    target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
    show: ['AccountContextController'],
  },
  {
    source: 'mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
    target: 'mobile/lib/features/auth/auth_api.dart',
    show: ['AuthController', 'AuthStatus'],
  },
  {
    source: 'mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
    target: 'mobile/lib/features/catalogs/catalogs_api.dart',
    show: ['ReferenceCatalogProvider'],
  },
  {
    source: 'mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
    target: 'mobile/lib/features/finance/finance_api.dart',
    show: [
      'FinanceApi',
      'MoneyInputFormatter',
      'formatMoneyInputValue',
      'moneyStarterPlanItemNames',
    ],
  },
  {
    source: 'mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
    target: 'mobile/lib/features/marketplace/marketplace_api.dart',
    show: ['MarketplaceApi'],
  },
  {
    source: 'mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
    target: 'mobile/lib/features/onboarding/onboarding_api.dart',
    show: [
      'GuestOnboardingDraft',
      'GuestOnboardingPath',
      'GuestOnboardingStorage',
      'GuestPersona',
      'WeddingLocationDraft',
    ],
  },
  {
    source: 'mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
    target: 'mobile/lib/features/tasks/tasks_api.dart',
    show: ['taskStarterCountFor'],
  },
  {
    source: 'mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
    target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
    show: ['OnboardingCompleteRequest', 'WeddingPlansProvider'],
  },
];

const trackedCompositionRootContracts = [
  {
    source: 'mobile/lib/app.dart',
    imports: [
      {
        target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
        show: ['AccountContextController'],
      },
      {
        target: 'mobile/lib/features/auth/auth_api.dart',
        show: ['AuthController', 'AuthStatus'],
      },
    ],
  },
  {
    source: 'mobile/lib/core/routing/app_router.dart',
    imports: [
      {
        target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
        show: [
          'AccountContextController',
          'AccountContextRole',
          'SelectedWeddingPlanContextGate',
          'WeddingPlanContextGate',
          'WeddingPlanRouteAccess',
        ],
      },
      {
        target: 'mobile/lib/features/auth/auth_api.dart',
        show: [
          'LoginScreen',
          'OtpScreen',
          'OtpScreenArgs',
          'RegisterScreen',
          'ResetPasswordScreen',
          'SplashScreen',
        ],
      },
      {
        target: 'mobile/lib/features/chat/chat_api.dart',
        show: ['ChatScreen', 'ConversationListView', 'QuoteConversationEntryScreen'],
      },
      {
        target: 'mobile/lib/features/finance/finance_api.dart',
        show: [
          'BudgetCategory',
          'BudgetCategoryDetailsScreen',
          'BudgetCategoryFormScreen',
          'CostDetailsScreen',
          'CostDraftIntent',
          'CostFormScreen',
          'CostPaymentDetailsScreen',
          'FinanceProvider',
          'FundingSourcesScreen',
          'MoneyBudgetScreen',
          'MoneyOverviewScreen',
          'MoneyReceiptsScreen',
          'PayPaymentScheduleScreen',
          'RecordCostPaymentScreen',
          'WeddingCost',
        ],
      },
      {
        target: 'mobile/lib/features/guests/guests_api.dart',
        show: [
          'GuestAttendanceScreen',
          'GuestDetailsScreen',
          'GuestImportScreen',
          'GuestImportSource',
          'GuestInviteScreen',
          'GuestListScreen',
        ],
      },
      {
        target: 'mobile/lib/features/home/home_api.dart',
        show: ['DashboardEntryScreen'],
      },
      {
        target: 'mobile/lib/features/marketplace/marketplace_api.dart',
        show: [
          'BookingMomentScreen',
          'FavoriteProvidersScreen',
          'PlanBookingsScreen',
          'ProviderAuthGate',
          'ProviderBudgetMatchIntent',
          'ProviderDetailsScreen',
          'ProviderMarketplaceScreen',
          'ProviderQuoteInitialContext',
          'ProviderRequestsScreen',
          'ProviderReviewsScreen',
          'QuoteRequestScreen',
          'providerRespondsLine',
        ],
      },
      {
        target: 'mobile/lib/features/more/more_api.dart',
        show: ['MoreScreen'],
      },
      {
        target: 'mobile/lib/features/notifications/notifications_api.dart',
        show: ['NotificationsScreen'],
      },
      {
        target: 'mobile/lib/features/provider_portal/provider_portal_api.dart',
        show: [
          'AddProviderPackageScreen',
          'AddProviderServiceScreen',
          'EditProviderProfileScreen',
          'ProviderApplyScreen',
          'ProviderApplyStatusScreen',
          'ProviderPortalScreen',
        ],
      },
      {
        target: 'mobile/lib/features/settings/settings_api.dart',
        show: ['LockSettingsScreen', 'SettingsScreen'],
      },
      {
        target: 'mobile/lib/features/sharing/sharing_api.dart',
        show: [
          'ContributionHistoryScreen',
          'EditSharedMemberScreen',
          'FromFamilyScreen',
          'InviteDecisionScreen',
          'ParticipantPlanStateScreen',
          'SharedMember',
          'SharingScreen',
        ],
      },
      {
        target: 'mobile/lib/features/shell/shell_api.dart',
        show: ['WeddingPlanShell', 'participantPlanTab'],
      },
      {
        target: 'mobile/lib/features/support/support_api.dart',
        show: ['SupportScreen'],
      },
      {
        target: 'mobile/lib/features/tasks/tasks_api.dart',
        show: [
          'CreateTaskScreen',
          'TaskDetailsScreen',
          'TaskTimelineScreen',
          'WeddingTask',
        ],
      },
      {
        target: 'mobile/lib/features/wedding_day/wedding_day_api.dart',
        show: ['WeddingDayModeScreen'],
      },
      {
        target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
        show: [
          'DashboardSummary',
          'MyWeddingPlansScreen',
          'PlanAssistantScreen',
          'PlanCenterScreen',
          'WeddingPlanDashboardScreen',
        ],
      },
      {
        target: 'mobile/lib/features/welcome_gateway/welcome_gateway_api.dart',
        show: ['SmartWelcomeScreen'],
      },
    ],
  },
  {
    source: 'mobile/lib/main.dart',
    imports: [
      {
        target: 'mobile/lib/features/account_contexts/account_contexts_api.dart',
        show: ['AccountContextsApi', 'AccountContextController'],
      },
      {
        target: 'mobile/lib/features/auth/auth_api.dart',
        show: ['AuthController', 'AuthRepository'],
      },
      {
        target: 'mobile/lib/features/catalogs/catalogs_api.dart',
        show: ['ReferenceCatalogApi', 'ReferenceCatalogProvider'],
      },
      {
        target: 'mobile/lib/features/chat/chat_api.dart',
        show: ['ChatApi', 'ChatProvider', 'ChatRealtimeClient'],
      },
      {
        target: 'mobile/lib/features/finance/finance_api.dart',
        show: [
          'FinanceApi',
          'FinanceProvider',
          'FundingApi',
          'FundingProvider',
          'LocalFinancePlanContext',
        ],
      },
      {
        target: 'mobile/lib/features/guests/guests_api.dart',
        show: ['GuestsApi', 'GuestsProvider'],
      },
      {
        target: 'mobile/lib/features/home/home_api.dart',
        show: ['HomeDashboardProvider'],
      },
      {
        target: 'mobile/lib/features/marketplace/marketplace_api.dart',
        show: [
          'MarketplaceApi',
          'ProviderDashboardApi',
          'ProviderMarketplaceProvider',
        ],
      },
      {
        target: 'mobile/lib/features/notifications/notifications_api.dart',
        show: ['NotificationsApi', 'NotificationsProvider'],
      },
      {
        target: 'mobile/lib/features/onboarding/onboarding_api.dart',
        show: [
          'GuestOnboardingStorage',
          'YemenAdministrativeApi',
          'YemenAdministrativeProvider',
        ],
      },
      {
        target: 'mobile/lib/features/provider_portal/provider_portal_api.dart',
        show: ['ProviderDashboardProvider'],
      },
      {
        target: 'mobile/lib/features/settings/settings_api.dart',
        show: ['SettingsApi', 'SettingsProvider'],
      },
      {
        target: 'mobile/lib/features/sharing/sharing_api.dart',
        show: [
          'ContributionHistoryProvider',
          'PlanLeaveCoordinator',
          'SharingApi',
          'SharingProvider',
        ],
      },
      {
        target: 'mobile/lib/features/tasks/tasks_api.dart',
        show: ['TaskTimelineApi', 'TaskTimelineProvider'],
      },
      {
        target: 'mobile/lib/features/wedding_plans/wedding_plans_api.dart',
        show: ['DashboardSummaryProvider', 'WeddingPlansApi', 'WeddingPlansProvider'],
      },
    ],
  },
];

function trackedOwnerApiFixture(overrides = {}) {
  const files = {};
  for (const contract of trackedOwnerApiContracts) {
    const relativePath = contract.path.replace('mobile/lib/', '');
    files[relativePath] = overrides[contract.path] ?? renderOwnerApiContractFile(contract);
  }
  return files;
}

function relativeFixtureImportUri(source, target) {
  const sourceRelative = source.replace('mobile/lib/', '');
  const targetRelative = target.replace('mobile/lib/', '');
  const relative = path.posix.relative(
    path.posix.dirname(sourceRelative),
    targetRelative,
  );
  return relative.startsWith('.') ? relative : `./${relative}`;
}

function trackedBatchFixture(contracts, overrides = {}) {
  const files = trackedOwnerApiFixture();
  for (const contract of trackedOwnerApiContracts) {
    const ownerDir = path.posix.dirname(contract.path.replace('mobile/lib/', ''));
    for (const { uri } of contract.exports) {
      files[path.posix.join(ownerDir, uri)] ??= '';
    }
  }
  const grouped = new Map();
  for (const contract of contracts) {
    const entries = grouped.get(contract.source) || [];
    entries.push(contract);
    grouped.set(contract.source, entries);
  }
  for (const [source, entries] of grouped) {
    const body = entries
      .map(({ target, show }) => (
        `import '${relativeFixtureImportUri(source, target)}' show ${show.join(', ')};`
      ))
      .join('\n');
    files[source.replace('mobile/lib/', '')] = `${body}\n`;
  }
  for (const [key, value] of Object.entries(overrides)) {
    files[key.replace('mobile/lib/', '')] = value;
  }
  return files;
}

function readTrackedOwnerApi(repoRootPath, repositoryPath) {
  const absolutePath = path.join(repoRootPath, ...repositoryPath.split('/'));
  if (!existsSync(absolutePath)) {
    throw new Error(`missing tracked owner API: ${repositoryPath}`);
  }
  return readFileSync(absolutePath, 'utf8').replace(/\r\n/g, '\n');
}

function assertTrackedOwnerApiContracts({
  repoRoot: repositoryRoot,
  manifest = loadR9Manifest(),
}) {
  // The R9 manifest is the closed R9 record (19 feature areas). R19 split
  // features/provider_portal out of marketplace (spec M6, C9), so the live
  // owner-API inventory is the R9 inventory plus that one area.
  assert.deepEqual(
    [...manifest.featureApis, r19ProviderPortalApi].sort((left, right) => (
      left.area < right.area ? -1 : left.area > right.area ? 1 : 0
    )),
    trackedOwnerApiContracts.map(({ area, path: apiPath }) => ({ area, path: apiPath })),
  );

  for (const contract of trackedOwnerApiContracts) {
    const text = readTrackedOwnerApi(repositoryRoot, contract.path);
    assert.ok(
      text.startsWith(`${ownerApiComment}\n`),
      `owner API comment mismatch: ${contract.path}`,
    );
    const directives = mobileBoundaries.parseR9DartDirectives(text);
    assert.deepEqual(
      directives.map((directive) => ({
        directiveKind: directive.directiveKind,
        uri: directive.uri,
        show: directive.show,
        hide: directive.hide,
        conditional: directive.conditional,
      })),
      contract.exports.map(({ uri, show }) => ({
        directiveKind: 'export',
        uri,
        show,
        hide: [],
        conditional: false,
      })),
      `owner API exports mismatch: ${contract.path}`,
    );
  }
}

function normalizeR9Record(record) {
  return {
    source: record.source,
    target: record.target,
    directiveKind: record.directiveKind,
    show: record.show,
    hide: record.hide,
    conditional: record.conditional,
    count: record.count,
  };
}

function assertTrackedIdentityBatch({
  repoRoot: repositoryRoot,
  manifest = loadR9Manifest(),
}) {
  const mobileLib = path.join(repositoryRoot, 'mobile', 'lib');
  const scan = mobileBoundaries.scanR9MobileBoundaries({
    mobileLib,
    manifest,
  });
  const trackedSources = new Set(
    trackedIdentityBatchContracts.map(({ source }) => source),
  );
  const expected = trackedIdentityBatchContracts.map((contract) => ({
    source: contract.source,
    target: contract.target,
    directiveKind: 'import',
    show: contract.show,
    hide: [],
    conditional: false,
    count: 1,
  }));
  const sortBySourceTarget = (left, right) => (
    left.source.localeCompare(right.source)
    || left.target.localeCompare(right.target)
  );
  const actualLegal = scan.legalRecords
    .filter(({ source }) => trackedSources.has(source))
    .map(normalizeR9Record)
    .sort(sortBySourceTarget);
  const expectedLegal = expected
    .map((record) => ({ ...record }))
    .sort(sortBySourceTarget);
  assert.deepEqual(
    actualLegal,
    expectedLegal,
    'tracked Identity batch legal owner API imports mismatch',
  );
  assert.deepEqual(
    scan.legacyRecords.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Identity batch still has internal cross-feature directives',
  );
  assert.deepEqual(
    scan.strictViolations.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Identity batch still has strict R9 violations',
  );
  assert.deepEqual(
    scan.errors.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Identity batch still has scanner errors',
  );
}

function assertTrackedCollaborationBatch({
  repoRoot: repositoryRoot,
  manifest = loadR9Manifest(),
}) {
  const mobileLib = path.join(repositoryRoot, 'mobile', 'lib');
  const scan = mobileBoundaries.scanR9MobileBoundaries({
    mobileLib,
    manifest,
  });
  const trackedSources = new Set(
    trackedCollaborationBatchContracts.map(({ source }) => source),
  );
  const expected = trackedCollaborationBatchContracts.map((contract) => ({
    source: contract.source,
    target: contract.target,
    directiveKind: 'import',
    show: contract.show,
    hide: [],
    conditional: false,
    count: 1,
  }));
  const sortBySourceTarget = (left, right) => (
    left.source.localeCompare(right.source)
    || left.target.localeCompare(right.target)
  );
  const actualLegal = scan.legalRecords
    .filter(({ source }) => trackedSources.has(source))
    .map(normalizeR9Record)
    .sort(sortBySourceTarget);
  const expectedLegal = expected
    .map((record) => ({ ...record }))
    .sort(sortBySourceTarget);
  assert.deepEqual(
    actualLegal,
    expectedLegal,
    'tracked Collaboration batch legal owner API imports mismatch',
  );
  assert.deepEqual(
    scan.legacyRecords.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Collaboration batch still has internal cross-feature directives',
  );
  assert.deepEqual(
    scan.strictViolations.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Collaboration batch still has strict R9 violations',
  );
  assert.deepEqual(
    scan.errors.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Collaboration batch still has scanner errors',
  );
}

function assertTrackedPlanningBatch({
  repoRoot: repositoryRoot,
  manifest = loadR9Manifest(),
}) {
  const mobileLib = path.join(repositoryRoot, 'mobile', 'lib');
  const scan = mobileBoundaries.scanR9MobileBoundaries({
    mobileLib,
    manifest,
  });
  const trackedSources = new Set(
    trackedPlanningBatchContracts.map(({ source }) => source),
  );
  const expected = trackedPlanningBatchContracts.map((contract) => ({
    source: contract.source,
    target: contract.target,
    directiveKind: 'import',
    show: contract.show,
    hide: [],
    conditional: false,
    count: 1,
  }));
  const sortBySourceTarget = (left, right) => (
    left.source.localeCompare(right.source)
    || left.target.localeCompare(right.target)
  );
  const actualLegal = scan.legalRecords
    .filter(({ source }) => trackedSources.has(source))
    .map(normalizeR9Record)
    .sort(sortBySourceTarget);
  const expectedLegal = expected
    .map((record) => ({ ...record }))
    .sort(sortBySourceTarget);
  assert.deepEqual(
    actualLegal,
    expectedLegal,
    'tracked Planning batch legal owner API imports mismatch',
  );
  assert.deepEqual(
    scan.legacyRecords.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Planning batch still has internal cross-feature directives',
  );
  assert.deepEqual(
    scan.strictViolations.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Planning batch still has strict R9 violations',
  );
  assert.deepEqual(
    scan.errors.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Planning batch still has scanner errors',
  );

  const coreFormatterPath = path.join(
    repositoryRoot,
    'mobile',
    'lib',
    'core',
    'utils',
    'money_formatters.dart',
  );
  assert.equal(
    existsSync(coreFormatterPath),
    true,
    'Planning batch Core money formatter is missing',
  );
  assert.equal(
    existsSync(path.join(
      repositoryRoot,
      'mobile',
      'lib',
      'features',
      'finance',
      'models',
      'money_formatters.dart',
    )),
    false,
    'Planning batch old Finance money formatter still exists',
  );

  const coreFormatterText = readFileSync(coreFormatterPath, 'utf8')
    .replace(/\r\n/g, '\n');
  assert.equal(
    createHash('sha256').update(coreFormatterText).digest('hex'),
    '34515407d93a1733b80253561d22d3751deeac6321f85b2bf737304b10a4c37d',
    'Planning batch Core money formatter normalized hash mismatch',
  );
  const restoredFinanceFormatterText = coreFormatterText.replace(
    "import 'currency_label.dart';",
    "import '../../../core/utils/currency_label.dart';",
  );
  assert.notEqual(restoredFinanceFormatterText, coreFormatterText);
  assert.equal(
    createHash('sha256').update(restoredFinanceFormatterText).digest('hex'),
    'a9998b46f98f28f3d1bf52643459fa97a23accb685fd684569150d04446b7133',
    'Planning batch original Finance money formatter hash mismatch',
  );

  const formatterConsumerContracts = [
    {
      source: 'mobile/lib/features/finance/screens/money_overview_screen.dart',
      uri: '../../../core/utils/money_formatters.dart',
      show: [],
    },
    {
      source: 'mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart',
      uri: '../../../../core/utils/money_formatters.dart',
      show: ['compactMoneyParts'],
    },
    {
      source: 'mobile/test/features/finance/money_summary_contract_test.dart',
      uri: 'package:aarast_mobile/core/utils/money_formatters.dart',
      show: [],
    },
  ];
  for (const contract of formatterConsumerContracts) {
    const directives = mobileBoundaries.parseR9DartDirectives(
      readTrackedOwnerApi(repositoryRoot, contract.source),
    );
    assert.deepEqual(
      directives
        .filter(({ directiveKind, uri }) => (
          directiveKind === 'import' && uri.endsWith('money_formatters.dart')
        ))
        .map(({ directiveKind, uri, show, hide, conditional }) => ({
          directiveKind,
          uri,
          show,
          hide,
          conditional,
        })),
      [{
        directiveKind: 'import',
        uri: contract.uri,
        show: contract.show,
        hide: [],
        conditional: false,
      }],
      `Planning batch money formatter consumer mismatch: ${contract.source}`,
    );
  }

  const financeContractText = readTrackedOwnerApi(
    repositoryRoot,
    'mobile/test/features/finance/money_summary_contract_test.dart',
  );
  assert.equal(
    createHash('sha256').update(financeContractText).digest('hex'),
    'a5432241e822c42614dfc3496e0361cab127456158576c7795fd4916e4989e66',
    'Planning batch Finance contract assertions changed',
  );

  const financeApiDirectives = mobileBoundaries.parseR9DartDirectives(
    readTrackedOwnerApi(repositoryRoot, 'mobile/lib/features/finance/finance_api.dart'),
  );
  assert.equal(
    financeApiDirectives.some(({ directiveKind, uri }) => (
      directiveKind === 'export' && uri.endsWith('/money_formatters.dart')
    )),
    false,
    'finance_api.dart must not export money_formatters.dart',
  );
}

function assertTrackedShellEntryBatch({
  repoRoot: repositoryRoot,
  manifest = loadR9Manifest(),
}) {
  const mobileLib = path.join(repositoryRoot, 'mobile', 'lib');
  const scan = mobileBoundaries.scanR9MobileBoundaries({
    mobileLib,
    manifest,
  });
  const trackedSources = new Set(
    trackedShellEntryBatchContracts.map(({ source }) => source),
  );
  const expected = trackedShellEntryBatchContracts.map((contract) => ({
    source: contract.source,
    target: contract.target,
    directiveKind: 'import',
    show: contract.show,
    hide: [],
    conditional: false,
    count: 1,
  }));
  const sortBySourceTarget = (left, right) => (
    left.source.localeCompare(right.source)
    || left.target.localeCompare(right.target)
  );
  const actualLegal = scan.legalRecords
    .filter(({ source }) => trackedSources.has(source))
    .map(normalizeR9Record)
    .sort(sortBySourceTarget);
  const expectedLegal = expected
    .map((record) => ({ ...record }))
    .sort(sortBySourceTarget);
  assert.deepEqual(
    actualLegal,
    expectedLegal,
    'tracked Shell Entry batch legal owner API imports mismatch',
  );
  assert.deepEqual(
    scan.legacyRecords.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Shell Entry batch still has internal cross-feature directives',
  );
  assert.deepEqual(
    scan.strictViolations.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Shell Entry batch still has strict R9 violations',
  );
  assert.deepEqual(
    scan.errors.filter(({ source }) => trackedSources.has(source)),
    [],
    'tracked Shell Entry batch still has scanner errors',
  );

  const exactCompositionRoots = new Set([
    'mobile/lib/app.dart',
    'mobile/lib/main.dart',
    'mobile/lib/core/routing/app_router.dart',
  ]);
  assert.deepEqual(
    scan.legacyRecords.filter(({ source }) => !exactCompositionRoots.has(source)),
    [],
    'internal cross-feature directives remain outside exact composition roots',
  );
}

function assertTrackedCompositionRoots({
  repoRoot: repositoryRoot,
  manifest = loadR9Manifest(),
}) {
  const mobileLib = path.join(repositoryRoot, 'mobile', 'lib');
  const scan = mobileBoundaries.scanR9MobileBoundaries({
    mobileLib,
    manifest,
  });
  const compositionSources = new Set(
    trackedCompositionRootContracts.map(({ source }) => source),
  );
  const expected = trackedCompositionRootContracts.flatMap(({ source, imports }) => (
    imports.map(({ target, show }) => ({
      source,
      target,
      directiveKind: 'import',
      show: [...show].sort(),
      hide: [],
      conditional: false,
      count: 1,
    }))
  ));
  const sortBySourceTarget = (left, right) => (
    left.source.localeCompare(right.source)
    || left.target.localeCompare(right.target)
  );

  for (const { source, imports } of trackedCompositionRootContracts) {
    for (const { show } of imports) {
      assert.equal(new Set(show).size, show.length, `${source} show list must be unique`);
    }
    const text = readTrackedOwnerApi(repositoryRoot, source);
    const actualFeatureDirectives = mobileBoundaries.parseR9DartDirectives(text)
      .filter(({ uri }) => typeof uri === 'string' && uri.split('/').includes('features'))
      .map(({ directiveKind, uri, show, hide, conditional }) => ({
        directiveKind,
        uri,
        show,
        hide,
        conditional,
      }));
    const expectedFeatureDirectives = imports.map(({ target, show }) => ({
      directiveKind: 'import',
      uri: path.posix.relative(path.posix.dirname(source), target),
      show: [...show].sort(),
      hide: [],
      conditional: false,
    }));
    assert.deepEqual(
      actualFeatureDirectives,
      expectedFeatureDirectives,
      `${source} composition directives mismatch`,
    );
  }

  assert.deepEqual(
    scan.legalRecords
      .filter(({ source }) => compositionSources.has(source))
      .map(normalizeR9Record)
      .sort(sortBySourceTarget),
    expected.map((record) => ({ ...record })).sort(sortBySourceTarget),
    'composition root legal owner API imports mismatch',
  );
  assert.deepEqual(scan.errors, [], 'composition scan has structural errors');
  assert.deepEqual(scan.legacyRecords, [], 'historical cross-feature debt remains');
  assert.deepEqual(scan.rootRecords, [], 'root composition debt remains');
  assert.deepEqual(scan.strictViolations, [], 'strict R9 violations remain');
  // R9 closed at manifest.finalLegalRecordCount (159). The R19 provider-portal
  // split moved the persona's imports behind two owner APIs; the live
  // projection is pinned here, the closed manifest stays unchanged.
  assert.equal(manifest.finalLegalRecordCount, 159);
  assert.equal(
    scan.legalRecords.length,
    r19LegalRecordCount,
    'final legal owner API projection mismatch',
  );
}

function scanR9Fixture(files) {
  assert.equal(typeof mobileBoundaries.scanR9MobileBoundaries, 'function');
  return withMobileFixture(files, ({ mobileLib }) => (
    mobileBoundaries.scanR9MobileBoundaries({
      mobileLib,
      manifest: loadR9Manifest(),
    })
  ));
}

function r9Record(overrides = {}) {
  return {
    source: 'mobile/lib/features/alpha/source.dart',
    target: 'mobile/lib/features/beta/internal.dart',
    sourceArea: 'features/alpha',
    targetArea: 'features/beta',
    directiveKind: 'import',
    show: [],
    hide: [],
    conditional: false,
    count: 1,
    ...overrides,
  };
}

test('tracked owner APIs exist and match the exact Appendix A export contracts', () => {
  assertTrackedOwnerApiContracts({ repoRoot });
});

test('Identity batch imports consume only exact owner APIs from Appendix B', () => {
  assertTrackedIdentityBatch({ repoRoot });
});

test('Collaboration batch imports consume only exact owner APIs from Appendix B', () => {
  assertTrackedCollaborationBatch({ repoRoot });
});

test('Planning batch imports consume exact owner APIs and the Core formatter contract', () => {
  assertTrackedPlanningBatch({ repoRoot });
});

test('Shell Entry batch imports consume only exact owner APIs from Appendix B', () => {
  assertTrackedShellEntryBatch({ repoRoot });
});

test('composition roots consume exact owner APIs with zero debt and final legal projection', () => {
  assertTrackedCompositionRoots({ repoRoot });
});

test('tracked owner API contract rejects an absent manifest API path', () => {
  const files = trackedOwnerApiFixture();
  delete files['features/auth/auth_api.dart'];

  withMobileFixture(files, ({ root }) => {
    assert.throws(
      () => assertTrackedOwnerApiContracts({ repoRoot: root }),
      /missing tracked owner API: mobile\/lib\/features\/auth\/auth_api\.dart/,
    );
  });
});

test('tracked owner API contract rejects one additional public symbol', () => {
  const authContract = trackedOwnerApiContracts.find(({ path: apiPath }) => (
    apiPath === 'mobile/lib/features/auth/auth_api.dart'
  ));
  assert.ok(authContract);
  const files = trackedOwnerApiFixture({
    'mobile/lib/features/auth/auth_api.dart': [
      ownerApiComment,
      ...authContract.exports.map(({ uri, show }) => {
        if (uri !== 'providers/auth_controller.dart') {
          return `export '${uri}' show ${show.join(', ')};`;
        }
        return `export '${uri}' show ${[...show, 'SafeUser'].join(', ')};`;
      }),
      '',
    ].join('\n'),
  });

  withMobileFixture(files, ({ root }) => {
    assert.throws(
      () => assertTrackedOwnerApiContracts({ repoRoot: root }),
      /owner API exports mismatch: mobile\/lib\/features\/auth\/auth_api\.dart/,
    );
  });
});

test('tracked Collaboration batch rejects one unchanged internal import', () => {
  const files = trackedBatchFixture(trackedCollaborationBatchContracts, {
    'mobile/lib/features/provider_portal/screens/provider_apply_screen.dart': [
      "import '../../account_contexts/account_contexts_api.dart' show AccountContextController;",
      "import '../../marketplace/marketplace_api.dart' show ProviderMarketplaceProvider;",
      "import '../../auth/auth_api.dart' show AuthActionGuard, AuthController, AuthStatus;",
      "import '../../auth/providers/auth_controller.dart';",
      '',
    ].join('\n'),
  });

  withMobileFixture(files, ({ root }) => {
    assert.throws(
      () => assertTrackedCollaborationBatch({ repoRoot: root }),
      /tracked Collaboration batch still has internal cross-feature directives/,
    );
  });
});

test('tracked Collaboration batch rejects one duplicate owner import', () => {
  const files = trackedBatchFixture(trackedCollaborationBatchContracts, {
    'mobile/lib/features/provider_portal/screens/provider_apply_screen.dart': [
      "import '../../account_contexts/account_contexts_api.dart' show AccountContextController;",
      "import '../../marketplace/marketplace_api.dart' show ProviderMarketplaceProvider;",
      "import '../../auth/auth_api.dart' show AuthActionGuard;",
      "import '../../auth/auth_api.dart' show AuthController, AuthStatus;",
      '',
    ].join('\n'),
  });

  withMobileFixture(files, ({ root }) => {
    assert.throws(
      () => assertTrackedCollaborationBatch({ repoRoot: root }),
      /tracked Collaboration batch legal owner API imports mismatch/,
    );
  });
});

test('tracked Collaboration batch rejects one missing symbol', () => {
  const files = trackedBatchFixture(trackedCollaborationBatchContracts, {
    'mobile/lib/features/provider_portal/screens/provider_apply_screen.dart': [
      "import '../../account_contexts/account_contexts_api.dart' show AccountContextController;",
      "import '../../marketplace/marketplace_api.dart' show ProviderMarketplaceProvider;",
      "import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;",
      '',
    ].join('\n'),
  });

  withMobileFixture(files, ({ root }) => {
    assert.throws(
      () => assertTrackedCollaborationBatch({ repoRoot: root }),
      /tracked Collaboration batch legal owner API imports mismatch/,
    );
  });
});

test('R9 parser preserves directive metadata and scan ownership metadata', () => {
  assert.equal(typeof mobileBoundaries.parseR9DartDirectives, 'function');
  const parsed = mobileBoundaries.parseR9DartDirectives([
    '// ignored',
    "import 'first.dart' if (dart.library.io) 'second.dart' show Beta, Alpha hide Hidden;",
    "export 'third.dart' show Public;",
    "part 'child.dart';",
    "part of 'library.dart';",
  ].join('\n'));
  assert.deepEqual(parsed, [
    {
      directiveKind: 'import',
      uri: 'first.dart',
      show: ['Alpha', 'Beta'],
      hide: ['Hidden'],
      conditional: true,
      line: 2,
    },
    {
      directiveKind: 'import',
      uri: 'second.dart',
      show: ['Alpha', 'Beta'],
      hide: ['Hidden'],
      conditional: true,
      line: 2,
    },
    {
      directiveKind: 'export',
      uri: 'third.dart',
      show: ['Public'],
      hide: [],
      conditional: false,
      line: 3,
    },
    {
      directiveKind: 'part',
      uri: 'child.dart',
      show: [],
      hide: [],
      conditional: false,
      line: 4,
    },
    {
      directiveKind: 'part-of',
      uri: 'library.dart',
      show: [],
      hide: [],
      conditional: false,
      line: 5,
    },
  ]);

  const scan = scanR9Fixture({
    'features/alpha/source.dart': "import '../beta/internal.dart';\n",
    'features/beta/internal.dart': '',
  });
  assert.deepEqual(scan.legacyRecords, [r9Record()]);
});

test('accepts internal import redirected to exact owner API as debt reduction', () => {
  const scan = scanR9Fixture({
    'features/alpha/source.dart': "import '../beta/beta_api.dart' show Beta;\n",
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta;\n",
    'features/beta/internal.dart': 'class Beta {}\n',
  });
  const oldDebt = r9Record();
  const comparison = mobileBoundaries.compareR9MobileDebt({
    scan,
    baseline: baseline([{
      source: oldDebt.source,
      target: oldDebt.target,
      sourceArea: oldDebt.sourceArea,
      targetArea: oldDebt.targetArea,
      kind: 'direct-cross-feature',
      count: 1,
    }]),
    manifest: loadR9Manifest(),
  });
  assert.equal(comparison.ok, true);
  assert.deepEqual(comparison.additions, []);
  assert.equal(comparison.legacyViolationCount, 0);
  assert.equal(scan.legalRecords.length, 1);
  assert.deepEqual(scan.strictViolations, []);
});

test('rejects a new or increased internal cross-feature edge', () => {
  const scan = scanR9Fixture({
    'features/alpha/source.dart': [
      "import '../beta/internal.dart';",
      "export '../beta/internal.dart';",
    ].join('\n'),
    'features/beta/internal.dart': '',
  });
  const comparison = mobileBoundaries.compareR9MobileDebt({
    scan,
    baseline: baseline([{
      source: 'mobile/lib/features/alpha/source.dart',
      target: 'mobile/lib/features/beta/internal.dart',
      sourceArea: 'features/alpha',
      targetArea: 'features/beta',
      kind: 'direct-cross-feature',
      count: 1,
    }]),
    manifest: loadR9Manifest(),
  });
  assert.equal(comparison.ok, false);
  assert.equal(comparison.additions.length > 0, true);
});

test('rejects a non-routing Core import of a feature API', () => {
  const scan = scanR9Fixture({
    'core/push/bridge.dart': "import '../../features/beta/beta_api.dart' show Beta;\n",
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta;\n",
    'features/beta/internal.dart': 'class Beta {}\n',
  });
  assert.equal(scan.legalRecords.length, 0);
  assert.equal(scan.strictViolations.length, 1);
  assert.ok(scan.errors.some(({ kind }) => kind === 'invalid-feature-importer'));
});

test('rejects owner export without a non-empty show list', () => {
  const scan = scanR9Fixture({
    'features/beta/beta_api.dart': "export 'internal.dart';\n",
    'features/beta/internal.dart': 'class Beta {}\n',
  });
  assert.ok(scan.errors.some(({ kind }) => kind === 'owner-export-empty-show'));
});

test('rejects owner API import declaration part part-of conditional hide cross-owner and API-to-API export', () => {
  const scan = scanR9Fixture({
    'features/alpha/alpha_api.dart': [
      "import 'internal.dart';",
      'const forbidden = 1;',
      "part 'child.dart';",
      "export 'internal.dart' if (dart.library.io) 'other.dart' show Alpha;",
      "export 'other.dart' show Alpha hide Hidden;",
      "export '../beta/internal.dart' show Beta;",
      "export '../beta/beta_api.dart' show Beta;",
    ].join('\n'),
    'features/alpha/internal.dart': 'class Alpha {}\n',
    'features/alpha/other.dart': 'class Hidden {}\n',
    'features/alpha/child.dart': "part of 'alpha_api.dart';\n",
    'features/beta/internal.dart': 'class Beta {}\n',
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta;\n",
  });
  const kinds = new Set(scan.errors.map(({ kind }) => kind));
  for (const kind of [
    'owner-api-forbidden-directive',
    'owner-api-declaration',
    'owner-export-conditional',
    'owner-export-hide',
    'owner-export-cross-owner',
    'owner-export-api-target',
  ]) assert.equal(kinds.has(kind), true, kind);
});

test('rejects cross-area owner import without a non-empty show list', () => {
  const scan = scanR9Fixture({
    'features/alpha/source.dart': "import '../beta/beta_api.dart';\n",
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta;\n",
    'features/beta/internal.dart': 'class Beta {}\n',
  });
  assert.ok(scan.errors.some(({ kind }) => kind === 'owner-import-empty-show'));
  assert.equal(scan.strictViolations.length, 1);
});

test('rejects mixed internal and API imports for one target owner', () => {
  const scan = scanR9Fixture({
    'features/alpha/source.dart': [
      "import '../beta/beta_api.dart' show Beta;",
      "import '../beta/internal.dart';",
    ].join('\n'),
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta;\n",
    'features/beta/internal.dart': 'class Beta {}\n',
  });
  assert.ok(scan.errors.some(({ kind }) => kind === 'mixed-owner-imports'));
});

test('rejects multiple owner API directives for one source-target owner pair', () => {
  const scan = scanR9Fixture({
    'features/alpha/source.dart': [
      "import '../beta/beta_api.dart' show Beta;",
      "import '../beta/beta_api.dart' show OtherBeta;",
    ].join('\n'),
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta, OtherBeta;\n",
    'features/beta/internal.dart': 'class Beta {} class OtherBeta {}\n',
  });
  assert.ok(scan.errors.some(({ kind }) => kind === 'duplicate-owner-api-import'));
});

test('accepts exact main app and app_router owner API imports', () => {
  const scan = scanR9Fixture({
    'main.dart': "import 'features/beta/beta_api.dart' show Beta;\n",
    'app.dart': "import 'features/beta/beta_api.dart' show Beta;\n",
    'core/routing/app_router.dart': "import '../../features/beta/beta_api.dart' show Beta;\n",
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta;\n",
    'features/beta/internal.dart': 'class Beta {}\n',
  });
  assert.deepEqual(scan.errors, []);
  assert.equal(scan.legalRecords.length, 3);
  assert.deepEqual(scan.strictViolations, []);
});

test('rejects any other root or core-routing feature importer', () => {
  const scan = scanR9Fixture({
    'bootstrap.dart': "import 'features/beta/beta_api.dart' show Beta;\n",
    'core/routing/helper.dart': "import '../../features/beta/beta_api.dart' show Beta;\n",
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta;\n",
    'features/beta/internal.dart': 'class Beta {}\n',
  });
  assert.equal(
    scan.errors.filter(({ kind }) => kind === 'invalid-feature-importer').length,
    2,
  );
});

test('permits legal records when final strict violations are zero', () => {
  const scan = scanR9Fixture({
    'features/alpha/source.dart': "import '../beta/beta_api.dart' show Beta;\n",
    'features/beta/beta_api.dart': "export 'internal.dart' show Beta;\n",
    'features/beta/internal.dart': 'class Beta {}\n',
  });
  assert.equal(scan.legalRecords.length, 1);
  assert.deepEqual(scan.strictViolations, []);
  assert.deepEqual(scan.errors, []);
});

test('R9 CLI checks manifest baseline hash debt counts and legal strict records', () => {
  const manifest = loadR9Manifest();
  const savedText = readFileSync(baselinePath, 'utf8');
  const legalRecord = r9Record({
    target: 'mobile/lib/features/beta/beta_api.dart',
    show: ['Beta'],
  });
  const r9Scan = {
    errors: [],
    legacyRecords: [],
    rootRecords: [],
    legalRecords: [legalRecord],
    strictViolations: [],
  };
  const dependencies = {
    scanR9: () => r9Scan,
    readManifest: () => manifest,
    readBaselineText: () => savedText,
  };
  const baselineResult = captureCli(dependencies);
  assert.equal(baselineResult.exitCode, 0);
  assert.deepEqual(baselineResult.stdout, [
    'R9 mobile boundary baseline check passed (legacy=0, root=0, legal=1)',
  ]);

  const strictResult = captureCli({
    ...dependencies,
    argv: ['--strict'],
  });
  assert.equal(strictResult.exitCode, 0);
  assert.deepEqual(strictResult.stdout, [
    'strict R9 mobile boundary check passed (legal=1)',
  ]);

  assertConfigurationFailure(captureCli({
    ...dependencies,
    readBaselineText: () => '{}\n',
  }));
});

test('root debt comparison preserves the exact frozen directive metadata', () => {
  const manifest = loadR9Manifest();
  const changed = {
    ...manifest.rootInventory.records[0],
    show: ['Unexpected'],
  };
  const comparison = mobileBoundaries.compareR9MobileDebt({
    scan: {
      errors: [],
      legacyRecords: [],
      rootRecords: [changed],
      legalRecords: [],
      strictViolations: [changed],
    },
    baseline: JSON.parse(readFileSync(baselinePath, 'utf8')),
    manifest,
  });
  assert.equal(comparison.ok, false);
  assert.deepEqual(comparison.additions, [changed]);
});
