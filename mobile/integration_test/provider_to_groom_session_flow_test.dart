import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/auth/provider_to_groom_session_flow_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'provider logout then same-user groom login never rebuilds provider dashboard',
    runProviderToGroomSessionScenario,
  );
}
