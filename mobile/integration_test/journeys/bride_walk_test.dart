// The bride سلمى's journey in the real app against the local API, in her
// profile's colour and words. Run: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/owner_walk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'bride walk: home, money, tasks, guests, providers, account',
    (tester) => runOwnerWalk(tester, bridePersona),
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
