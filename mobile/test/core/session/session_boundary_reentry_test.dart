import 'package:aarast_mobile/core/session/session_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'user-a to guest to user-a creates a fresh account-scoped subtree',
    (tester) async {
      final accountId = ValueNotifier<String?>('user-a');
      final created = <_AccountScopedState>[];
      addTearDown(accountId.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<String?>(
            valueListenable: accountId,
            builder: (_, userId, _) {
              final owner = userId ?? 'guest';
              return AarastSessionBoundary(
                identity: userId == null ? 'guest' : 'account:$userId',
                builder: (_) => ChangeNotifierProvider(
                  create: (_) {
                    final state = _AccountScopedState(
                      owner: owner,
                      instanceNumber: created.length + 1,
                    );
                    created.add(state);
                    return state;
                  },
                  child: const _AccountScopedView(),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('user-a#1:empty'), findsOneWidget);
      created.single.setSecret('private-user-a');
      await tester.pump();
      expect(find.text('user-a#1:private-user-a'), findsOneWidget);

      accountId.value = null;
      await tester.pump();

      expect(created, hasLength(2));
      expect(created[0].disposed, isTrue);
      expect(find.text('guest#2:empty'), findsOneWidget);
      expect(find.textContaining('private-user-a'), findsNothing);

      accountId.value = 'user-a';
      await tester.pump();

      expect(created, hasLength(3));
      expect(created[1].disposed, isTrue);
      expect(created[2], isNot(same(created[0])));
      expect(find.text('user-a#3:empty'), findsOneWidget);
      expect(find.textContaining('private-user-a'), findsNothing);
    },
  );
}

class _AccountScopedState extends ChangeNotifier {
  _AccountScopedState({required this.owner, required this.instanceNumber});

  final String owner;
  final int instanceNumber;
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

class _AccountScopedView extends StatelessWidget {
  const _AccountScopedView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<_AccountScopedState>();
    return Text('${state.owner}#${state.instanceNumber}:${state.secret}');
  }
}
