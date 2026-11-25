import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/app_route_table.dart';

// RA-TS-25: 72 test files built a GoRouter of their own, 36 of them with the
// plan paths written out again, and nothing said the paths were still the
// app's. This keeps them honest: every absolute path a test gives a
// `GoRoute` that lives under one of the app's own roots (`/wedding-plans`,
// `/providers`, `/provider`, `/quotes`, `/conversations`, `/invites`,
// `/settings`, ...) must be a route in `AppRouter.create`, whatever the
// name of its parameters. A path under a root the app does not have
// (`/x`, `/portal`) is a stub's own and is not the app's to answer for.
//
// Relative child paths (`'send'`) and paths built from a variable are not
// literals; they are read as part of the parent's literal below.

final _goRoutePath = RegExp(
  r'''GoRoute\(\s*(?:name:\s*[^,]+,\s*)?path:\s*(?:appRoute\(\s*)?(['"])(/[^'"$]*)\1''',
);

void main() {
  test(
    'a route a test stubs under the app\'s roots is a route of AppRouter.create',
    () {
      final table = appRoutePatterns();
      final roots = appRouteRoots();
      expect(
        table,
        contains('/wedding-plans/:/money'),
        reason: 'the table was read',
      );
      expect(
        roots,
        containsAll(['wedding-plans', 'providers', 'provider', 'quotes']),
      );

      final unknown = <String>[];
      var checked = 0;
      for (final file in Directory('test').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('test_router_paths_test.dart')) continue;
        final source = file.readAsStringSync();
        for (final match in _goRoutePath.allMatches(source)) {
          final path = match.group(2)!;
          final root = path.split('/').where((s) => s.isNotEmpty).firstOrNull;
          if (root == null || !roots.contains(root)) continue;
          checked++;
          if (!isAppRoute(path)) unknown.add('${file.path}: $path');
        }
      }
      expect(
        checked,
        greaterThan(40),
        reason: 'the scan found the tests\' stubs',
      );
      expect(unknown, isEmpty, reason: 'paths no AppRouter route answers');
    },
  );

  test(
    'appRoute accepts the app\'s own paths whatever the parameter\'s name',
    () {
      expect(appRoute('/wedding-plans/:id/money'), '/wedding-plans/:id/money');
      expect(
        appRoute('/wedding-plans/:planId/money'),
        '/wedding-plans/:planId/money',
      );
      expect(appRoute('/providers/:id'), '/providers/:id');
    },
  );

  test('appRoute refuses a path the app does not have', () {
    expect(() => appRoute('/wedding-plans/:id/moneyy'), throwsStateError);
    expect(() => appRoute('/wedding-plans/:id'), throwsStateError);
    expect(() => appRoute('/wedding-plans/:id/budget'), throwsStateError);
  });
}
