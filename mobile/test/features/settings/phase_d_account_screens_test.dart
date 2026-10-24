import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase D account and settings screens contract', () {
    final screenPaths = <String>[
      'lib/features/more/screens/more_screen.dart',
      'lib/features/auth/screens/register_screen.dart',
      'lib/features/settings/screens/settings_screen.dart',
      'lib/features/support/screens/support_screen.dart',
      'lib/features/auth/screens/splash_screen.dart',
    ];

    test('phase D screens avoid stale Material icons and placeholders', () {
      for (final path in screenPaths) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(matches(RegExp(r'(?<!Lucide)Icons\.'))),
          reason: path,
        );
        expect(source, isNot(contains('AarastComingSoonScreen')), reason: path);
        expect(source, isNot(contains('PLANNING')), reason: path);
        expect(source, isNot(contains('placeholder')), reason: path);
        expect(source, isNot(contains('Mock progress')), reason: path);
      }
    });

    test('interactive account screens use Lucide where icons are visible', () {
      for (final path in screenPaths.where(
        (path) => !path.endsWith('splash_screen.dart'),
      )) {
        final source = File(path).readAsStringSync();
        expect(source, contains('LucideIcons.'), reason: path);
      }
    });
  });
}
