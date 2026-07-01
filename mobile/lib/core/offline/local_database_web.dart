import 'package:shared_preferences/shared_preferences.dart';

import 'local_database_contract.dart';
import 'local_database_json.dart';

Future<LocalDatabase> createPlatformLocalDatabase(
  SharedPreferences preferences,
) async {
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  return database;
}
