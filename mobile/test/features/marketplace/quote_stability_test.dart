import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quote create sends the stable idempotency header on the plan route',
    () async {
      final adapter = _CaptureQuoteAdapter();
      final client = ApiClient(tokenProvider: () async => 'token');
      client.dio.httpClientAdapter = adapter;
      final api = MarketplaceApi(client);

      await api.createQuoteRequest(
        providerId: 'provider-1',
        weddingPlanId: 'plan-1',
        clientRequestId: '11111111-1111-4111-8111-111111111111',
        message: 'طلب',
      );

      expect(
        adapter.options?.path,
        '/api/v1/wedding-plans/plan-1/quote-requests',
      );
      expect(
        adapter.options?.headers[ApiClient.clientRequestIdHeader],
        '11111111-1111-4111-8111-111111111111',
      );
      final body = adapter.decodedBody;
      expect(body['providerId'], 'provider-1');
      expect(body.containsKey('weddingPlanId'), false);
    },
  );

  test(
    'one logical retry reuses its key and a new submission rotates it',
    () async {
      final api = _RetryQuoteApi();
      final provider = ProviderMarketplaceProvider(api);

      expect(
        await provider.createQuoteRequest(
          providerId: 'provider-1',
          message: 'same request',
        ),
        false,
      );
      expect(
        await provider.createQuoteRequest(
          providerId: 'provider-1',
          message: 'same request',
        ),
        true,
      );
      expect(api.keys[0], api.keys[1]);

      expect(
        await provider.createQuoteRequest(
          providerId: 'provider-1',
          message: 'new request',
        ),
        true,
      );
      expect(api.keys[2], isNot(api.keys[1]));
    },
  );

  test('active request conflict exposes the current request action', () async {
    final api = _ActiveConflictApi();
    final provider = ProviderMarketplaceProvider(api);

    final ok = await provider.createQuoteRequest(
      providerId: 'provider-1',
      weddingPlanId: 'plan-1',
    );

    expect(ok, false);
    expect(provider.existingActiveQuote?.id, 'quote-existing');
    expect(provider.quoteSubmitErrorMessage, contains('الطلب الحالي'));
  });

  test(
    'plan marketplace reads plan quotes rather than account quotes',
    () async {
      final api = _PlanScopeApi();
      final provider = ProviderMarketplaceProvider(api);

      await provider.loadMarketplace(
        includeAccountData: true,
        weddingPlanId: 'plan-1',
        updateQuoteScope: true,
      );

      expect(api.planReads, 1);
      expect(api.accountReads, 0);
      expect(provider.quoteRequests.single.id, 'plan-quote');
    },
  );

  test('provider pagination merges pages by id without duplicates', () async {
    final api = _PagedMarketplaceApi();
    final provider = ProviderMarketplaceProvider(api);

    await provider.loadMarketplace(includeAccountData: false);
    await provider.loadMoreProviders();

    expect(provider.currentPage, 2);
    expect(provider.totalProviders, 3);
    expect(provider.totalPages, 2);
    expect(provider.hasMoreProviders, false);
    expect(provider.providers.map((item) => item.id), ['p1', 'p2', 'p3']);
  });

  test(
    'a stale filter response is never merged into the current result',
    () async {
      final api = _StaleFilterApi();
      final provider = ProviderMarketplaceProvider(api);

      final oldLoad = provider.setSearch('old');
      await Future<void>.delayed(Duration.zero);
      await provider.setSearch('new');
      api.oldResult.complete(_page([_provider('old-provider')]));
      await oldLoad;

      expect(provider.providers.map((item) => item.id), ['new-provider']);
    },
  );
}

QuoteRequest _quote(String id, {String? planId}) => QuoteRequest(
  id: id,
  providerId: 'provider-1',
  weddingPlanId: planId,
  status: 'SENT',
  lifecycleStatus: 'PENDING_PROVIDER',
);

MarketplaceProvider _provider(String id) => MarketplaceProvider(
  id: id,
  businessName: id,
  ownerName: id,
  isFeatured: false,
  ratingAverage: 0,
  ratingCount: 0,
);

MarketplaceProviderPage _page(
  List<MarketplaceProvider> items, {
  int currentPage = 1,
  int total = 1,
  int totalPages = 1,
}) => MarketplaceProviderPage(
  items: items,
  currentPage: currentPage,
  total: total,
  totalPages: totalPages,
  hasMore: currentPage < totalPages,
);

class _CaptureQuoteAdapter implements HttpClientAdapter {
  RequestOptions? options;
  Map<String, dynamic> decodedBody = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    decodedBody = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'quote-1',
        'providerId': 'provider-1',
        'weddingPlanId': 'plan-1',
        'status': 'SENT',
        'lifecycleStatus': 'PENDING_PROVIDER',
      }),
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RetryQuoteApi extends MarketplaceApi {
  _RetryQuoteApi() : super(ApiClient(tokenProvider: () async => null));

  final keys = <String>[];

  @override
  Future<QuoteRequest> createQuoteRequest({
    required String providerId,
    required String clientRequestId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    Map<String, dynamic>? location,
    String? cityId,
    int? guestCount,
    String? contactName,
    String? contactPhone,
    String? message,
    String? budgetMin,
    String? budgetMax,
  }) async {
    keys.add(clientRequestId);
    if (keys.length == 1) {
      throw const ApiException('network', isNetworkFailure: true);
    }
    return _quote('quote-${keys.length}', planId: weddingPlanId);
  }
}

class _ActiveConflictApi extends _RetryQuoteApi {
  @override
  Future<QuoteRequest> createQuoteRequest({
    required String providerId,
    required String clientRequestId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    Map<String, dynamic>? location,
    String? cityId,
    int? guestCount,
    String? contactName,
    String? contactPhone,
    String? message,
    String? budgetMin,
    String? budgetMax,
  }) => throw const ApiException(
    'يوجد طلب عرض سعر نشط مطابق. تابع الطلب الحالي.',
    statusCode: 409,
    serverCode: 'ACTIVE_QUOTE_REQUEST_EXISTS',
  );

  @override
  Future<List<QuoteRequest>> getPlanQuoteRequests(String weddingPlanId) async =>
      [_quote('quote-existing', planId: weddingPlanId)];
}

class _PlanScopeApi extends MarketplaceApi {
  _PlanScopeApi() : super(ApiClient(tokenProvider: () async => null));

  int planReads = 0;
  int accountReads = 0;

  @override
  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async => _page(const []);

  @override
  Future<List<MarketplaceCity>> getCities() async => const [];

  @override
  Future<List<ProviderCategory>> getCategories() async => const [];

  @override
  Future<List<FavoriteProvider>> getFavoriteProviders() async => const [];

  @override
  Future<List<QuoteRequest>> getPlanQuoteRequests(String weddingPlanId) async {
    planReads += 1;
    return [_quote('plan-quote', planId: weddingPlanId)];
  }

  @override
  Future<List<QuoteRequest>> getMyQuoteRequests() async {
    accountReads += 1;
    return [_quote('account-quote')];
  }
}

class _PagedMarketplaceApi extends _PlanScopeApi {
  @override
  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    if (page == 1) {
      return _page([_provider('p1'), _provider('p2')], total: 3, totalPages: 2);
    }
    return _page(
      [_provider('p2'), _provider('p3')],
      currentPage: 2,
      total: 3,
      totalPages: 2,
    );
  }
}

class _StaleFilterApi extends _PlanScopeApi {
  final oldResult = Completer<MarketplaceProviderPage>();

  @override
  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) {
    if (search == 'old') return oldResult.future;
    return Future.value(_page([_provider('new-provider')]));
  }
}
