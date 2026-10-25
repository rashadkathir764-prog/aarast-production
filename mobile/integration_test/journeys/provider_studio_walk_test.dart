// The provider «استوديو ضوء صنعاء» (علي الشامي) in the real app.
// Run: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/provider_walk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'provider walk: studio home, requests, offer, calendar, profile',
    runStudioWalk,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
