import 'package:shared_preferences/shared_preferences.dart';

import 'local_database_contract.dart';
// Platforms without dart:io (web) use the JSON-backed stub factory directly;
// the former web-specific factory was byte-identical to it.
import 'local_database_factory_stub.dart'
    if (dart.library.io) 'local_database_mobile.dart';

export 'local_database_contract.dart';

Future<LocalDatabase> createLocalDatabase(SharedPreferences preferences) {
  return createPlatformLocalDatabase(preferences);
}
