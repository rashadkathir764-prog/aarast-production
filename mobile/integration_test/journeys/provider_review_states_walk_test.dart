// The providers under review: PENDING (فرقة الأمجاد), NEEDS_CHANGES
// (محلات الأناقة) and REJECTED (كوافيرة أم ريان), one after the other.
// Run: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/provider_walk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'provider walk: pending, needs-changes and rejected accounts',
    runReviewStatesWalk,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
