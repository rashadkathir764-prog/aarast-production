import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/finance/data/finance_api_contracts.dart';
import 'package:aarast_mobile/features/finance/data/finance_local_data_source.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-89: on a plan kept on the phone the mahr lived in the plan's
// answers alone; «عليك» left out what remained of it, and the account said
// another figure once the plan was saved there.

Future<FinanceLocalDataSource> _local() async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final offline = OfflineSyncService(
    database: database,
    apiClient: ApiClient(tokenProvider: () async => null),
  );
  await offline.initialize();
  return FinanceLocalDataSource(offline);
}

void main() {
  const planId = 'local-guest-plan';
  const mahr = LocalFinancePlanContext(
    mahrTotal: '3000000',
    mahrSettled: '2000000',
  );

  test('the groom\'s mahr left to hand over is on him', () async {
    final local = await _local();
    final summary = await local.moneySummary(
      planId,
      persona: 'GROOM',
      draftMahr: mahr,
    );
    expect(moneyValue(summary.outstanding?.owner), 1000000);
    expect(moneyValue(summary.outstanding?.ownerMahr), 1000000);
  });

  test('the bride\'s mahr comes in: nothing on her from it', () async {
    final local = await _local();
    final summary = await local.moneySummary(
      planId,
      persona: 'BRIDE',
      draftMahr: mahr,
    );
    expect(moneyValue(summary.outstanding?.owner), 0);
  });
}
