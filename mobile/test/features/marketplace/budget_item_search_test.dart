import 'package:aarast_mobile/core/experience_v3/aarast_journey_profile.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_board.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_budget_match_intent.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

// G40: «ابحث» searches the directory categories the server lists for a money
// item (acceptance's own rule); the phone keeps no copy of the groups.

void main() {
  test('the money summary carries each item\'s directory categories', () {
    final item = MoneyCategorySummary.fromJson({
      'categoryId': 'artist',
      'name': 'الفنان والفرقة',
      'providerCategoryIds': ['male-singer', 'mabra'],
    });
    expect(item.providerCategoryIds, ['male-singer', 'mabra']);
    final none = MoneyCategorySummary.fromJson({
      'categoryId': 'subhia',
      'name': 'الصبحية',
    });
    expect(none.providerCategoryIds, isEmpty);
  });

  test('a search from an item asks for all of its categories', () async {
    final api = _RecordingApi();
    final marketplace = ProviderMarketplaceProvider(api);
    await marketplace.applyBudgetMatchIntent(
      const ProviderBudgetMatchIntent(
        budgetCategoryName: 'الفنان والفرقة',
        allocatedAmount: '500000',
        providerCategoryIds: ['male-singer', 'mabra'],
      ),
    );
    expect(api.asked.last, ['male-singer', 'mabra']);
    expect(marketplace.categoryId, isNull);

    // Choosing one chip leaves the item's search.
    await marketplace.setCategory('mabra');
    expect(api.asked.last, isNull);
    expect(marketplace.budgetMatchIntent, isNull);
  });

  testWidgets('«ابحث» shows only where the server lists categories', (
    tester,
  ) async {
    final rows = buildProviderBoard(
      items: const [
        (id: 'artist', name: 'الفنان والفرقة', providerCategoryIds: ['mabra']),
      ],
      costs: const [
        // Someone recorded under the mahr: a row, but nothing to search.
        (budgetCategoryId: 'mahr', providerId: 'p-1', partyName: null),
      ],
      costItemById: const {},
      quotes: const [],
    );
    final searched = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Scaffold(
            body: ProviderBoardView(
              rows: [
                ...rows,
                const ProviderBoardRow(
                  key: 'mahr',
                  title: 'المهر',
                  stage: 0,
                  detail: 'ما بدأت',
                ),
              ],
              onOpen: (_) {},
              onSearch: (row) => searched.add(row.key),
            ),
          ),
        ),
      ),
    );
    expect(find.text('ابحث'), findsOneWidget);
    await tester.tap(find.text('ابحث'));
    expect(searched, ['artist']);
  });

  test('the row icons are pictures only, for the bride\'s items too', () {
    expect(providerServiceIcon('البخور'), LucideIcons.flame);
    expect(providerServiceIcon('المزينة والنقاشة'), LucideIcons.sparkles);
    expect(providerServiceIcon('الفنان والفرقة'), LucideIcons.music);
    expect(providerServiceIcon('شي ثاني'), LucideIcons.store);
  });
}

class _RecordingApi extends MarketplaceApi {
  _RecordingApi() : super(ApiClient(tokenProvider: () async => null));

  final asked = <List<String>?>[];

  @override
  Future<List<MarketplaceCity>> getCities() async => const [];

  @override
  Future<List<ProviderCategory>> getCategories() async => const [];

  @override
  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    asked.add(categoryIds);
    return const MarketplaceProviderPage(
      items: [],
      currentPage: 1,
      total: 0,
      totalPages: 1,
      hasMore: false,
    );
  }
}
