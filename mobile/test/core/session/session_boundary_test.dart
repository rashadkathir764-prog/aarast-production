import 'package:aarast_mobile/core/session/session_boundary.dart';
import 'package:aarast_mobile/core/session/session_scoped_change_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('account identity change disposes all old in-memory state', (
    tester,
  ) async {
    final account = ValueNotifier<String>('user-a');
    final created = <_SecretNotifier>[];
    addTearDown(account.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<String>(
          valueListenable: account,
          builder: (_, userId, _) => AarastSessionBoundary(
            identity: 'account:$userId',
            builder: (_) => ChangeNotifierProvider(
              create: (_) {
                final notifier = _SecretNotifier(userId);
                created.add(notifier);
                return notifier;
              },
              child: const _SecretView(),
            ),
          ),
        ),
      ),
    );

    created.single.setSecret('private-user-a');
    await tester.pump();
    expect(find.text('user-a:private-user-a'), findsOneWidget);

    account.value = 'user-b';
    await tester.pump();

    expect(created, hasLength(2));
    expect(created.first.disposed, isTrue);
    expect(find.text('user-b:empty'), findsOneWidget);
    expect(find.textContaining('private-user-a'), findsNothing);

    created.first.setSecret('late-user-a-response');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('late-user-a-response'), findsNothing);
  });

  testWidgets('plan provider replacement preserves the application subtree', (
    tester,
  ) async {
    final plan = _PlanIdentity('plan-a');
    final created = <_SecretNotifier>[];
    final lifecycle = _LifecycleCounts();
    addTearDown(plan.dispose);

    _SecretNotifier createFor(String planId) {
      final notifier = _SecretNotifier(planId)
        ..bindSessionIdentity('plan:$planId');
      created.add(notifier);
      return notifier;
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<_PlanIdentity>.value(value: plan),
          ChangeNotifierProxyProvider<_PlanIdentity, _SecretNotifier>(
            create: (_) => createFor(plan.id),
            update: (_, identity, current) {
              final scope = 'plan:${identity.id}';
              if (current?.belongsToSession(scope) == true) return current!;
              return createFor(identity.id);
            },
          ),
        ],
        child: MaterialApp(
          home: Column(
            children: [const _SecretView(), _LifecycleMarkerProbe(lifecycle)],
          ),
        ),
      ),
    );

    created.single.setSecret('plan-a-private');
    await tester.pump();
    expect(find.text('plan-a:plan-a-private'), findsOneWidget);
    expect(lifecycle.initCount, 1);

    plan.switchTo('plan-b');
    await tester.pump();

    expect(created, hasLength(2));
    expect(created.first.disposed, isTrue);
    expect(find.text('plan-b:empty'), findsOneWidget);
    expect(find.textContaining('plan-a-private'), findsNothing);
    expect(lifecycle.initCount, 1);
    expect(lifecycle.disposeCount, 0);
  });
}

class _SecretNotifier extends ChangeNotifier with SessionScopedNotifier {
  _SecretNotifier(this.owner);

  final String owner;
  String secret = 'empty';
  bool disposed = false;

  void setSecret(String value) {
    secret = value;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _PlanIdentity extends ChangeNotifier {
  _PlanIdentity(this.id);

  String id;

  void switchTo(String value) {
    id = value;
    notifyListeners();
  }
}

class _SecretView extends StatelessWidget {
  const _SecretView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<_SecretNotifier>();
    return Text('${state.owner}:${state.secret}');
  }
}

class _LifecycleCounts {
  int initCount = 0;
  int disposeCount = 0;
}

class _LifecycleMarkerProbe extends StatefulWidget {
  const _LifecycleMarkerProbe(this.counts);

  final _LifecycleCounts counts;

  @override
  State<_LifecycleMarkerProbe> createState() => _LifecycleMarkerProbeState();
}

class _LifecycleMarkerProbeState extends State<_LifecycleMarkerProbe> {
  @override
  void initState() {
    super.initState();
    widget.counts.initCount += 1;
  }

  @override
  void dispose() {
    widget.counts.disposeCount += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
