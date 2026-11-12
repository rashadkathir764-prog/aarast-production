import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// D85: every feature's data layer reads through the phone's copy and
// writes through the queue (OfflineReads / OfflineWrites), or says why it
// needs the server (serverOnly). A raw API call in a data file is a screen
// that will spin or fail when the server is slow, so the count of raw
// calls per file may only shrink, down to zero.

// Any receiver: the client is not always named `apiClient` (the assistant's
// `_client` went uncounted until 2026-11-12).
final _rawCall = RegExp(
  r'\b\w+\.(getJson|getJsonList|postJson|postJsonWithReceiveTimeout|postJsonWithBearer|patchJson|putJson|deleteJson|deleteJsonWithData)\(|\.dio\.(get|post|patch|put|delete|request)<',
);

/// Raw calls still allowed per data file. Shrink only; never add a file.
/// Sign-in, codes and the account itself are the server's by nature
/// (features/auth is not under this contract).
const _baseline = <String, int>{
  'finance/data/finance_api.costs.dart': 2,
  'finance/data/finance_api.dart': 3,
  'finance/data/finance_api.payments.dart': 2,
  // Own queue for favourites; the rest are provider-side actions that
  // reach another person and plan-side requests, each said so.
  'marketplace/data/marketplace_api.dart': 35,
  'tasks/data/task_timeline_api.dart': 6,
  // Found, not added: the pattern above missed this file. A question needs
  // the model now, with its own long wait; the status is asked fresh for
  // what is left today, and kept on the phone for the home's door.
  'wedding_plans/data/plan_assistant_api.dart': 2,
  'wedding_plans/data/wedding_plans_api.dart': 10,
};

void main() {
  test('raw API calls in feature data files only shrink (D85)', () {
    final root = Directory('lib/features');
    final counts = <String, int>{};
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path
          .replaceAll('\\', '/')
          .replaceFirst('lib/features/', '');
      if (!relative.contains('/data/')) continue;
      if (relative.startsWith('auth/')) continue;
      final hits = _rawCall.allMatches(entity.readAsStringSync()).length;
      if (hits > 0) counts[relative] = hits;
    }

    final problems = <String>[];
    for (final entry in counts.entries) {
      final allowed = _baseline[entry.key];
      if (allowed == null) {
        problems.add(
          '${entry.key}: ${entry.value} raw API call(s) in a new file; use OfflineReads/OfflineWrites',
        );
      } else if (entry.value > allowed) {
        problems.add(
          '${entry.key}: ${entry.value} raw API calls, baseline $allowed; use OfflineReads/OfflineWrites',
        );
      }
    }
    for (final entry in _baseline.entries) {
      final actual = counts[entry.key] ?? 0;
      if (actual < entry.value) {
        problems.add(
          '${entry.key}: now $actual raw calls; lower its baseline from ${entry.value}',
        );
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
