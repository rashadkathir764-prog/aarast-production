import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/contribution_history.dart';
import 'package:aarast_mobile/features/sharing/providers/contribution_history_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/contribution_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'contribution history DTO keeps the frozen snapshot free of live IDs',
    () {
      final response = ContributionHistoryResponse.fromJson({
        'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
        'total': 1,
        'events': [
          {
            'id': 'event-1',
            'section': 'TASKS',
            'entityType': 'TASK',
            'action': 'CREATED',
            'occurredAt': '2026-08-02T10:00:00.000Z',
            'capturedAt': '2026-08-02T10:00:01.000Z',
            'snapshot': {
              'title': 'تأكيد القاعة',
              'status': 'TODO',
              'priority': 'HIGH',
            },
          },
        ],
      });

      expect(response.historyCoverageStartsAt, DateTime.utc(2026, 8, 2, 9));
      expect(response.events.single.snapshot['title'], 'تأكيد القاعة');
      expect(response.events.single.snapshot, isNot(contains('entityId')));
      expect(response.events.single.snapshot, isNot(contains('weddingPlanId')));
    },
  );

  test('contribution history DTO rejects every malformed event row', () {
    expect(
      () => ContributionHistoryResponse.fromJson({
        'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
        'total': 2,
        'events': [
          {
            'id': 'event-1',
            'section': 'TASKS',
            'entityType': 'TASK',
            'action': 'CREATED',
            'capturedAt': '2026-08-02T10:00:01.000Z',
            'snapshot': {'title': 'مهمة سليمة'},
          },
          'malformed-event-row',
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets(
    'revoked contribution history has no live entity route or write action',
    (tester) async {
      final provider = ContributionHistoryProvider(_EmptyHistoryApi());
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ContributionHistoryProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ContributionHistoryScreen(weddingPlanId: 'plan-shared'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('contribution-history-screen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('contribution-history-live-link')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('contribution-history-write-action')),
        findsNothing,
      );
    },
  );

  test('contribution history DTO rejects duplicate event ids', () {
    final event = _eventJson('event-1', 'مهمة');
    expect(
      () => ContributionHistoryResponse.fromJson({
        'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
        'total': 2,
        'events': [event, event],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'late history response cannot replace the newly selected plan',
    () async {
      final api = _ControlledHistoryApi();
      final provider = ContributionHistoryProvider(api);

      final first = provider.load('plan-a');
      final second = provider.load('plan-b');
      api.complete('plan-b', _historyJson('event-b', 'خطة ب'));
      await second;
      api.complete('plan-a', _historyJson('event-a', 'خطة أ'));
      await first;

      expect(provider.response?.events.single.id, 'event-b');
      provider.dispose();
    },
  );

  test(
    'starting a new plan load releases an older in-flight load-more gate',
    () async {
      final api = _PlanSwitchDuringLoadMoreApi();
      final provider = ContributionHistoryProvider(api);
      addTearDown(provider.dispose);

      await provider.load('plan-a');
      final staleLoadMore = provider.loadMore();
      expect(provider.isLoadingMore, isTrue);

      await provider.load('plan-b');

      expect(provider.isLoadingMore, isFalse);
      await provider.loadMore();
      expect(api.requests, ['plan-a:0', 'plan-a:1', 'plan-b:0', 'plan-b:1']);
      expect(provider.response?.events.map((event) => event.id), [
        'plan-b-event-1',
        'plan-b-event-2',
      ]);

      api.completeStalePlanALoadMore();
      await staleLoadMore;
      expect(provider.isLoadingMore, isFalse);
      expect(provider.response?.events.map((event) => event.id), [
        'plan-b-event-1',
        'plan-b-event-2',
      ]);
    },
  );

  testWidgets('history exposes and loads every page until total is reached', (
    tester,
  ) async {
    final api = _PagedHistoryApi();
    final provider = ContributionHistoryProvider(api);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ContributionHistoryProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: ContributionHistoryScreen(weddingPlanId: 'plan-paged'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.offsets, [0]);
    expect(find.byKey(const Key('contribution-history-load-more')), findsOne);

    await tester.tap(find.byKey(const Key('contribution-history-load-more')));
    await tester.pumpAndSettle();

    expect(api.offsets, [0, 2]);
    expect(provider.response?.events.map((event) => event.id), [
      'event-1',
      'event-2',
      'event-3',
    ]);
    expect(
      find.byKey(const Key('contribution-history-load-more')),
      findsNothing,
    );
  });

  test(
    'overlapping history pages fail visibly instead of truncating rows',
    () async {
      final provider = ContributionHistoryProvider(_OverlappingHistoryApi());
      addTearDown(provider.dispose);

      await provider.load('plan-changing');
      await provider.loadMore();

      expect(provider.response?.events.map((event) => event.id), [
        'event-1',
        'event-2',
      ]);
      expect(provider.requiresReload, isTrue);
      expect(provider.hasMore, isFalse);
      expect(provider.loadMoreError, contains('حدّث السجل'));
    },
  );
}

Map<String, dynamic> _historyJson(String id, String title) => {
  'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
  'total': 1,
  'events': [
    {
      'id': id,
      'section': 'TASKS',
      'entityType': 'TASK',
      'action': 'CREATED',
      'occurredAt': '2026-08-02T10:00:00.000Z',
      'capturedAt': '2026-08-02T10:00:01.000Z',
      'snapshot': {'title': title},
    },
  ],
};

class _ControlledHistoryApi extends SharingApi {
  _ControlledHistoryApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  final Map<String, Completer<ContributionHistoryResponse>> _requests = {};

  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
  }) {
    return (_requests[weddingPlanId] ??=
            Completer<ContributionHistoryResponse>())
        .future;
  }

  void complete(String weddingPlanId, Map<String, dynamic> json) {
    _requests[weddingPlanId]!.complete(
      ContributionHistoryResponse.fromJson(json),
    );
  }
}

class _PlanSwitchDuringLoadMoreApi extends SharingApi {
  _PlanSwitchDuringLoadMoreApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  final List<String> requests = [];
  final Completer<ContributionHistoryResponse> _stalePlanALoadMore =
      Completer<ContributionHistoryResponse>();

  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
  }) {
    requests.add('$weddingPlanId:$offset');
    if (weddingPlanId == 'plan-a' && offset == 1) {
      return _stalePlanALoadMore.future;
    }
    return Future.value(
      ContributionHistoryResponse.fromJson({
        'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
        'total': 2,
        'events': [
          _eventJson(
            '$weddingPlanId-event-${offset == 0 ? 1 : 2}',
            '$weddingPlanId-$offset',
          ),
        ],
      }),
    );
  }

  void completeStalePlanALoadMore() {
    _stalePlanALoadMore.complete(
      ContributionHistoryResponse.fromJson({
        'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
        'total': 2,
        'events': [_eventJson('plan-a-event-2', 'plan-a-1')],
      }),
    );
  }
}

class _PagedHistoryApi extends SharingApi {
  _PagedHistoryApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  final List<int> offsets = [];

  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
  }) async {
    offsets.add(offset);
    final rows = offset == 0
        ? [
            _eventJson('event-1', 'المساهمة الأولى'),
            _eventJson('event-2', 'المساهمة الثانية'),
          ]
        : [_eventJson('event-3', 'المساهمة الثالثة')];
    return ContributionHistoryResponse.fromJson({
      'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
      'total': 3,
      'events': rows,
    });
  }
}

class _EmptyHistoryApi extends SharingApi {
  _EmptyHistoryApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
  }) async {
    return ContributionHistoryResponse.fromJson({
      'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
      'total': 0,
      'events': const [],
    });
  }
}

class _OverlappingHistoryApi extends SharingApi {
  _OverlappingHistoryApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
  }) async {
    return ContributionHistoryResponse.fromJson({
      'historyCoverageStartsAt': '2026-08-02T09:00:00.000Z',
      'total': 3,
      'events': offset == 0
          ? [
              _eventJson('event-1', 'المساهمة الأولى'),
              _eventJson('event-2', 'المساهمة الثانية'),
            ]
          : [_eventJson('event-2', 'المساهمة الثانية')],
    });
  }
}

Map<String, dynamic> _eventJson(String id, String title) => {
  'id': id,
  'section': 'TASKS',
  'entityType': 'TASK',
  'action': 'CREATED',
  'occurredAt': '2026-08-02T10:00:00.000Z',
  'capturedAt': '2026-08-02T10:00:01.000Z',
  'snapshot': {'title': title},
};
