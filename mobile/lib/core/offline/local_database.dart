import 'package:shared_preferences/shared_preferences.dart';

import 'local_database_contract.dart';
import 'local_database_factory_stub.dart'
    if (dart.library.io) 'local_database_mobile.dart'
    if (dart.library.html) 'local_database_web.dart';

export 'local_database_contract.dart';

Future<LocalDatabase> createLocalDatabase(SharedPreferences preferences) {
  return createPlatformLocalDatabase(preferences);
}
