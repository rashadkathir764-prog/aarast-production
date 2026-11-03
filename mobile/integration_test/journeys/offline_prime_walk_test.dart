// D85: fills the phone's copy for the offline walks: the groom signs in
// and opens every tab, and stays signed in (the groom walk signs out).
// Run: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the groom opens every tab and stays signed in', (tester) async {
    final walk = JourneyWalk(tester, 'offline_prime');
    await walk.boot();
    await walk.signIn('+967777000101', pickContext: 'عرس محمد');

    for (final tab in ['المال', 'المهام', 'الضيوف', 'المزودين', 'الرئيسية']) {
      await walk.step('p_$tab', 'فتح $tab', () async {
        await walk.tab(tab, wait: 4);
      });
    }
    await walk.finish();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
