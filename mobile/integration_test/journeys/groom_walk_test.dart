// The groom محمد's journey in the real app against the local API.
// Run: see docs/qa/JOURNEY_WALKS.md («إعادة التشغيل»).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/owner_walk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'groom walk: home, money, tasks, guests, providers, account',
    (tester) => runOwnerWalk(tester, groomPersona),
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
