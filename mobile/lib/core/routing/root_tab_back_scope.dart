import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Makes Android back return an in-route tab shell to its first tab before
/// allowing the route itself to pop or the app root to exit.
///
/// A tab may have a back step of its own (an open group, a sub-tab, a search
/// box), declared with [TabBackStep]. Every tab of the shell stays mounted in
/// one IndexedStack on one route, so a PopScope per tab would register on that
/// route next to this one: Flutter refuses the pop when any of them refuses and
/// then calls every handler, so one press both undid the money sub-tab and
/// jumped to the home, and a hidden tab swallowed a press (RA-MO-04). Here the
/// steps register with the shell instead, and a press asks the active tab only:
/// its own step first, then the first tab, then the route.
class RootTabBackScope extends StatefulWidget {
  const RootTabBackScope({
    required this.activeIndex,
    required this.onReturnToRoot,
    required this.child,
    super.key,
  });

  final int activeIndex;
  final VoidCallback onReturnToRoot;
  final Widget child;

  /// Marks [child] as the content of tab [index], so a [TabBackStep] inside it
  /// is asked only while that tab is the active one.
  static Widget tab({required int index, required Widget child}) =>
      _TabBackSlot(index: index, child: child);

  @override
  State<RootTabBackScope> createState() => _RootTabBackScopeState();
}

class _RootTabBackScopeState extends State<RootTabBackScope> {
  final Map<int, _TabBackStepState> _steps = {};
  bool _rebuildScheduled = false;

  _TabBackStepState? get _activeStep => _steps[widget.activeIndex];

  bool get _activeTabIsNested => _activeStep?.widget.nested ?? false;

  void _register(int index, _TabBackStepState step) {
    _steps[index] = step;
    _stepChanged();
  }

  void _unregister(int index, _TabBackStepState step) {
    if (identical(_steps[index], step)) _steps.remove(index);
    _stepChanged();
  }

  /// A step's nested state decides whether the route may pop. It changes while
  /// the tab builds, when this widget may not rebuild, so the rebuild runs
  /// once after the frame.
  void _stepChanged() {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final nested = _activeTabIsNested;
    return _RootTabBackRegistry(
      state: this,
      child: PopScope<Object?>(
        canPop: widget.activeIndex == 0 && !nested,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final step = _activeStep;
          if (step != null && step.widget.nested) {
            step.widget.onBack();
          } else if (widget.activeIndex != 0) {
            widget.onReturnToRoot();
          }
        },
        child: widget.child,
      ),
    );
  }
}

class _RootTabBackRegistry extends InheritedWidget {
  const _RootTabBackRegistry({required this.state, required super.child});

  final _RootTabBackScopeState state;

  @override
  bool updateShouldNotify(_RootTabBackRegistry oldWidget) =>
      !identical(state, oldWidget.state);
}

class _TabBackSlot extends InheritedWidget {
  const _TabBackSlot({required this.index, required super.child});

  final int index;

  @override
  bool updateShouldNotify(_TabBackSlot oldWidget) => index != oldWidget.index;
}

/// A screen's own back step: while [nested] is true, Android back calls
/// [onBack] instead of leaving. Inside a [RootTabBackScope] tab it is asked
/// only while its tab is active; on a route of its own it is a PopScope.
class TabBackStep extends StatefulWidget {
  const TabBackStep({
    required this.nested,
    required this.onBack,
    required this.child,
    super.key,
  });

  final bool nested;
  final VoidCallback onBack;
  final Widget child;

  @override
  State<TabBackStep> createState() => _TabBackStepState();
}

class _TabBackStepState extends State<TabBackStep> {
  _RootTabBackScopeState? _scope;
  int? _index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RootTabBackRegistry>()
        ?.state;
    final slot = context.dependOnInheritedWidgetOfExactType<_TabBackSlot>();
    assert(
      scope == null || slot != null,
      'A TabBackStep inside a RootTabBackScope must sit in a '
      'RootTabBackScope.tab, or it would be asked for every tab.',
    );
    final index = scope == null ? null : slot?.index;
    if (identical(scope, _scope) && index == _index) return;
    if (_scope != null && _index != null) _scope!._unregister(_index!, this);
    _scope = scope;
    _index = index;
    if (_scope != null && _index != null) _scope!._register(_index!, this);
  }

  @override
  void didUpdateWidget(TabBackStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nested != widget.nested) _scope?._stepChanged();
  }

  @override
  void dispose() {
    if (_scope != null && _index != null) _scope!._unregister(_index!, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scope != null && _index != null) return widget.child;
    return PopScope<Object?>(
      canPop: !widget.nested,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.nested) widget.onBack();
      },
      child: widget.child,
    );
  }
}
