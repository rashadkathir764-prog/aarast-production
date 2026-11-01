import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/contribution_history.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/contribution_history_provider.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/contribution_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// x20 «وش سوّى المشاركين».

void main() {
  testWidgets(
    'the owner sees every participant\'s rows by name, newest first',
    (tester) async {
      final api = _Api(owner: true);
      await _pump(tester, api);

      expect(find.text('وش سوّى المشاركين'), findsOneWidget);
      expect(find.text('كل اللي سوّاه المشاركين في خطتك'), findsOneWidget);
      // One request per participant, asked by id.
      expect(api.requests.map((r) => r.contributorUserId).toSet(), {
        'user-saleh',
        'user-father',
      });
      expect(find.textContaining('خلّص "استلم البدلة"'), findsOneWidget);
      expect(find.textContaining('أضاف الضيف آل السقاف'), findsOneWidget);
      // The owner's actions are not recorded, so no «أنت» row.
      expect(find.textContaining('أنت'), findsNothing);
      expect(find.textContaining('انضمت للخطة'), findsNothing);
      final saleh = tester.getTopLeft(find.textContaining('استلم البدلة'));
      final father = tester.getTopLeft(find.textContaining('آل السقاف'));
      expect(saleh.dy, lessThan(father.dy), reason: 'newer row first');
    },
  );

  testWidgets('a filter asks the server for that section only', (tester) async {
    final api = _Api(owner: true);
    await _pump(tester, api);
    api.requests.clear();

    await tester.tap(find.text('المال'));
    await tester.pumpAndSettle();

    expect(api.requests, isNotEmpty);
    expect(api.requests.every((r) => r.section == 'MONEY'), isTrue);
  });

  testWidgets('a participant reads only their own history', (tester) async {
    final api = _Api(owner: false);
    await _pump(tester, api);

    expect(find.text('اللي سجّلته'), findsOneWidget);
    expect(api.membersCalls, 0);
    expect(api.requests.single.contributorUserId, isNull);
    expect(find.textContaining('خلّصت'), findsWidgets);
  });

  test('«أخفِ المبالغ» hides the amount in an activity row', () {
    final payment = _event(
      'p1',
      section: 'MONEY',
      entityType: 'COST_PAYMENT',
      action: 'PAYMENT_RECORDED',
      snapshot: {'title': 'الغداء', 'amount': 200000, 'currency': 'YER'},
    );
    final line = activityLine(payment, self: false, shownAmount: (_) => '••••');
    expect(line, startsWith('سجّل دفعة الغداء'));
    expect(line, contains('••••'));
    expect(line, isNot(contains('200')));
  });

  test('rows read like the design and never say «أقساط»', () {
    final payment = _event(
      'p1',
      section: 'MONEY',
      entityType: 'COST_PAYMENT',
      action: 'PAYMENT_RECORDED',
      snapshot: {'title': 'الغداء', 'amount': 200000, 'currency': 'YER'},
    );
    final line = activityLine(payment, self: false);
    expect(line, startsWith('سجّل دفعة الغداء'));
    expect(line, contains('200,000'));
    final schedule = _event(
      's1',
      section: 'MONEY',
      entityType: 'PAYMENT_SCHEDULE',
      action: 'CREATED',
      snapshot: {'title': 'القاعة'},
    );
    expect(activityLine(schedule, self: false), isNot(contains('أقساط')));
    expect(activityLine(schedule, self: true), startsWith('أضفت'));
  });

  test('merged lists hold back rows older than a list still paging', () async {
    final api = _PagingApi();
    final provider = ContributionHistoryProvider(api);
    addTearDown(provider.dispose);

    await provider.load(
      'plan-1',
      actors: const [
        ContributionActor(userId: 'a', name: 'صالح'),
        ContributionActor(userId: 'b', name: 'الوالد'),
      ],
    );
    // «a» has an older page; «b»'s old row waits for it.
    expect(provider.activities.map((row) => row.event.id), ['a1']);
    expect(provider.hasMore, isTrue);

    await provider.loadMore();
    expect(provider.activities.map((row) => row.event.id), ['a1', 'a2', 'b1']);
    expect(provider.activities.map((row) => row.actor?.name), [
      'صالح',
      'صالح',
      'الوالد',
    ]);
    expect(provider.hasMore, isFalse);
  });
}

Future<void> _pump(WidgetTester tester, _Api api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SharingProvider>.value(
          value: SharingProvider(api),
        ),
        ChangeNotifierProvider<ContributionHistoryProvider>.value(
          value: ContributionHistoryProvider(api),
        ),
      ],
      child: const MaterialApp(
        home: ContributionHistoryScreen(weddingPlanId: 'plan-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

typedef _Request = ({String? section, String? contributorUserId, int offset});

class _Api extends SharingApi {
  _Api({required this.owner})
    : super(ApiClient(tokenProvider: () async => null));

  final bool owner;
  final List<_Request> requests = [];
  int membersCalls = 0;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async => owner
      ? PlanAccessPermissions.owner(weddingPlanId: weddingPlanId)
      : PlanAccessPermissions(
          weddingPlanId: weddingPlanId,
          isOwner: false,
          canViewMoney: false,
          canManageMoney: false,
        );

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    membersCalls += 1;
    return [_member('saleh', 'صالح'), _member('father', 'الوالد')];
  }

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async =>
      const [];

  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
    String? section,
    String? contributorUserId,
  }) async {
    requests.add((
      section: section,
      contributorUserId: contributorUserId,
      offset: offset,
    ));
    final events = switch (contributorUserId) {
      'user-saleh' => [
        _json(
          'e-saleh',
          at: '2026-08-02T16:45:00.000Z',
          entityType: 'TASK',
          action: 'COMPLETED',
          snapshot: {'title': 'استلم البدلة'},
        ),
      ],
      'user-father' => [
        _json(
          'e-father',
          at: '2026-08-02T05:05:00.000Z',
          section: 'GUESTS',
          entityType: 'GUEST',
          action: 'CREATED',
          snapshot: {'displayName': 'آل السقاف'},
        ),
      ],
      _ => [
        _json(
          'e-self',
          at: '2026-08-02T08:00:00.000Z',
          entityType: 'TASK',
          action: 'COMPLETED',
          snapshot: {'title': 'اطبع الكروت'},
        ),
      ],
    };
    return ContributionHistoryResponse.fromJson({
      'historyCoverageStartsAt': '2026-08-01T00:00:00.000Z',
      'total': events.length,
      'events': events,
    });
  }
}

class _PagingApi extends SharingApi {
  _PagingApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
    String? section,
    String? contributorUserId,
  }) async {
    final events = switch ((contributorUserId, offset)) {
      ('a', 0) => [_json('a1', at: '2026-08-05T10:00:00.000Z')],
      ('a', _) => [_json('a2', at: '2026-08-03T10:00:00.000Z')],
      _ => [_json('b1', at: '2026-08-02T10:00:00.000Z')],
    };
    return ContributionHistoryResponse.fromJson({
      'historyCoverageStartsAt': '2026-08-01T00:00:00.000Z',
      'total': contributorUserId == 'a' ? 2 : 1,
      'events': events,
    });
  }
}

SharedMember _member(String id, String name) => SharedMember(
  id: 'member-$id',
  weddingPlanId: 'plan-1',
  userId: 'user-$id',
  user: SharedMemberUser(id: 'user-$id', name: name, phone: '+967771554220'),
  role: 'HELPER',
  canViewMoney: false,
  canManageTasks: true,
  canManageMoney: false,
  createdAt: DateTime(2026, 7, 16),
  updatedAt: DateTime(2026, 7, 16),
);

Map<String, dynamic> _json(
  String id, {
  required String at,
  String section = 'TASKS',
  String entityType = 'TASK',
  String action = 'CREATED',
  Map<String, dynamic> snapshot = const {'title': 'مهمة'},
}) => {
  'id': id,
  'section': section,
  'entityType': entityType,
  'action': action,
  'occurredAt': at,
  'capturedAt': at,
  'snapshot': snapshot,
};

ContributionHistoryEvent _event(
  String id, {
  required String section,
  required String entityType,
  required String action,
  required Map<String, dynamic> snapshot,
}) => ContributionHistoryEvent.fromJson(
  _json(
    id,
    at: '2026-08-02T10:00:00.000Z',
    section: section,
    entityType: entityType,
    action: action,
    snapshot: snapshot,
  ),
);
