import 'package:aarast_mobile/core/routing/root_tab_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// RA-MO-04: in a tab shell every tab stays mounted on one route. Android back
/// must ask the active tab's own step first, then return to the first tab,
/// then leave; a hidden tab's step is never asked.
void main() {
  testWidgets('a nested active tab undoes its own step and stays', (
    tester,
  ) async {
    final shell = _ShellProbe();
    await tester.pumpWidget(shell.app());
    shell.select(1);
    shell.nested[1] = true;
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(shell.backs[1], 1, reason: 'the money sub-tab is undone');
    expect(shell.index, 1, reason: 'the same press must not also go home');
  });

  testWidgets('an active tab at its root returns to the first tab', (
    tester,
  ) async {
    final shell = _ShellProbe();
    await tester.pumpWidget(shell.app());
    shell.select(3);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(shell.index, 0);
    expect(shell.backs[3], 0);
  });

  testWidgets('a hidden nested tab does not swallow the press on the home', (
    tester,
  ) async {
    final shell = _ShellProbe();
    await tester.pumpWidget(shell.app());
    // Open a guest group, then go home with the bottom bar.
    shell.select(3);
    shell.nested[3] = true;
    await tester.pumpAndSettle();
    shell.select(0);
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(shell.backs[3], 0, reason: 'the hidden group is left as it was');
    expect(
      handled,
      isFalse,
      reason: 'on the home the press leaves the app on the first press',
    );
  });

  testWidgets('on a route of its own the step is a plain PopScope', (
    tester,
  ) async {
    var backs = 0;
    var nested = true;
    late StateSetter setOuter;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return TabBackStep(
              nested: nested,
              onBack: () => setState(() {
                backs++;
                nested = false;
              }),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(backs, 1);

    setOuter(() {});
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(backs, 1);
  });
}

class _ShellProbe {
  final Map<int, bool> nested = {for (var i = 0; i < 5; i++) i: false};
  final Map<int, int> backs = {for (var i = 0; i < 5; i++) i: 0};
  int index = 0;
  StateSetter? _setState;

  void select(int value) => _setState?.call(() => index = value);

  Widget app() {
    return MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          _setState = setState;
          return RootTabBackScope(
            activeIndex: index,
            onReturnToRoot: () => setState(() => index = 0),
            child: IndexedStack(
              index: index,
              children: [
                for (var i = 0; i < 5; i++)
                  RootTabBackScope.tab(
                    index: i,
                    child: TabBackStep(
                      nested: nested[i]!,
                      onBack: () => setState(() {
                        backs[i] = backs[i]! + 1;
                        nested[i] = false;
                      }),
                      child: Text('tab $i'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
