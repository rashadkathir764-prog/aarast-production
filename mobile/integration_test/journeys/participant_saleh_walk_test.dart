// The helper صالح (the groom's brother) in «عرس محمد».
// Run: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/participant_walk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'participant walk: helper صالح, limited views and no private money',
    (tester) => runParticipantWalk(tester, helperSaleh),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
