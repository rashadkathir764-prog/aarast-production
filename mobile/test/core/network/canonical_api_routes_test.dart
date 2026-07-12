import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile network layer uses only canonical versioned product APIs', () {
    final mobileRoot = _mobileRoot();
    final roots = <Directory>[
      Directory('${mobileRoot}lib/features'),
      Directory('${mobileRoot}lib/core/media'),
      Directory('${mobileRoot}lib/core/network'),
    ];
    final forbidden = RegExp(
      r'''["']/((?:auth|users|media/uploads|conversations|wedding-plans|'''
      r'''budget-categories|expenses|financial-commitments|'''
      r'''financial-installments|financial-payment-records|tasks|guests|'''
      r'''guest-groups|notifications|onboarding|provider-categories|providers|'''
      r'''services|reviews|provider|shared|me)(?:/|["']))''',
    );
    final offenders = <String>[];

    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalizedPath = entity.path.replaceAll('\\', '/');
        if (normalizedPath.contains('/features/') &&
            !normalizedPath.contains('/data/')) {
          continue;
        }
        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          if (forbidden.hasMatch(lines[index])) {
            offenders.add(
              '${entity.path}:${index + 1}: ${lines[index].trim()}',
            );
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Every product API must use /api/v1. Unversioned routes were deleted '
          'from the backend and must not return through mobile clients.',
    );
  });
}

String _mobileRoot() {
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
