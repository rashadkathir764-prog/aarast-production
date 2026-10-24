import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../experience_v3/aarast_v3.dart';
import '../widgets/aarast_pressable.dart';
import 'app_lock_controller.dart';

/// Covers the app with the lock screen while the account's app lock is
/// closed (V1 checklist 4.15). The app underneath keeps its navigation, so
/// unlocking returns exactly where the user was.
class AppLockGate extends StatelessWidget {
  const AppLockGate({
    required this.child,
    required this.onForgotCode,
    this.name,
    super.key,
  });

  final Widget child;

  /// Signs the account out after its code was cleared.
  final Future<void> Function() onForgotCode;

  /// The account's name, for the letter on the lock (w07).
  final String? name;

  @override
  Widget build(BuildContext context) {
    AppLockController? lock;
    try {
      lock = context.watch<AppLockController>();
    } on ProviderNotFoundException {
      return child;
    }
    final covered = lock.isPending || lock.isLocked;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hidden content cannot be read by accessibility services either.
        ExcludeSemantics(excluding: covered, child: child),
        if (lock.isPending)
          const ColoredBox(color: AarastV3Color.canvas)
        else if (lock.isLocked)
          AppLockScreen(lock: lock, onForgotCode: onForgotCode, name: name),
      ],
    );
  }
}

/// w07 «أدخل رمز القفل», and w08 once codes go wrong.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    required this.lock,
    required this.onForgotCode,
    this.name,
    super.key,
  });

  final AppLockController lock;
  final Future<void> Function() onForgotCode;
  final String? name;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _wrong = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.lock.waitRemaining > Duration.zero) _tick();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _submit(String code) async {
    final opened = await widget.lock.unlock(code);
    if (!mounted || opened) return;
    setState(() => _wrong = true);
    if (widget.lock.waitRemaining > Duration.zero) _tick();
  }

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (widget.lock.waitRemaining == Duration.zero) timer.cancel();
    });
  }

  /// The lock covers the app's navigator, so a sheet or dialog would open
  /// under it; the forgotten-code question is asked on the lock itself.
  bool _confirmingForgot = false;

  Future<void> _forget() async {
    await widget.lock.forgetForSignOut();
    await widget.onForgotCode();
  }

  @override
  Widget build(BuildContext context) {
    final wait = widget.lock.waitRemaining;
    final waiting = wait > Duration.zero;
    final failures = widget.lock.failedAttempts;
    final name = widget.name?.trim() ?? '';
    final String title;
    final String? line;
    if (waiting) {
      title = failures >= AppLockController.freeAttempts
          ? 'الرمز غلط $failures مرات'
          : 'الرمز غلط';
      line = 'جرّب مرة ثانية بعد ${_clock(wait)}';
    } else if (_wrong) {
      title = 'الرمز غلط';
      line = 'جرّب مرة ثانية';
    } else {
      title = 'أدخل رمز القفل';
      line = null;
    }
    final error = waiting || _wrong;
    return Material(
      key: const Key('app-lock-screen'),
      color: AarastV3Color.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const JourneyWordmark(),
                  const SizedBox(height: 22),
                  JourneyAvatar(
                    letter: name.isEmpty ? 'ا' : name.characters.first,
                    color: AarastV3Color.saffron,
                    size: 60,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.display,
                      weight: JourneyType.bold,
                      color: error ? AarastV3Color.danger : AarastV3Color.text,
                    ),
                  ),
                  if (line != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      line,
                      textAlign: TextAlign.center,
                      style: JourneyType.of(
                        JourneyType.body,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_confirmingForgot)
                    _ForgotConfirm(
                      onForget: _forget,
                      onBack: () => setState(() => _confirmingForgot = false),
                    )
                  else
                    AppLockCodePad(
                      enabled: !waiting,
                      failed: waiting,
                      onCompleted: _submit,
                    ),
                  const SizedBox(height: 16),
                  if (waiting)
                    const JourneyNote(
                      icon: LucideIcons.keyRound,
                      text:
                          'نسيت الرمز؟ ادخل برقم جوالك ورمز واتساب، والقفل ينشال '
                          'وتختار رمز جديد.',
                    ),
                  if (!_confirmingForgot)
                    JourneyTextAction(
                      key: const Key('app-lock-forgot'),
                      label: 'نسيت الرمز؟',
                      color: AarastV3Color.primary,
                      onPressed: () => setState(() => _confirmingForgot = true),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «نسيت الرمز؟» answered on the lock: sign out and clear the code.
class _ForgotConfirm extends StatelessWidget {
  const _ForgotConfirm({required this.onForget, required this.onBack});

  final VoidCallback onForget;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'نسيت الرمز؟',
            style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'نطلعك من الحساب وينشال الرمز. ادخل من جديد برقم جوالك '
            'ورمز واتساب، وبياناتك محفوظة في حسابك.',
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          JourneyButton(
            key: const Key('app-lock-forgot-confirm'),
            label: 'اطلع وشيل الرمز',
            expand: true,
            onPressed: onForget,
          ),
          const SizedBox(height: 8),
          JourneyButton.quiet(label: 'ارجع', expand: true, onPressed: onBack),
        ],
      ),
    );
  }
}

/// «0:30».
String _clock(Duration wait) {
  final seconds = wait.inSeconds + (wait.inMilliseconds % 1000 > 0 ? 1 : 0);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Four dots and a digit pad (no system keyboard, so nothing is predicted
/// or remembered). Calls [onCompleted] with the full code and clears. On
/// the teal of g08 [dark] draws it in white.
class AppLockCodePad extends StatefulWidget {
  const AppLockCodePad({
    required this.onCompleted,
    this.enabled = true,
    this.failed = false,
    this.dark = false,
    super.key,
  });

  final FutureOr<void> Function(String code) onCompleted;
  final bool enabled;

  /// w08: the dots turn red while the pad waits.
  final bool failed;
  final bool dark;

  @override
  State<AppLockCodePad> createState() => _AppLockCodePadState();
}

class _AppLockCodePadState extends State<AppLockCodePad> {
  String _code = '';

  Future<void> _press(String digit) async {
    if (!widget.enabled || _code.length >= AppLockController.codeLength) return;
    setState(() => _code += digit);
    if (_code.length == AppLockController.codeLength) {
      final code = _code;
      await widget.onCompleted(code);
      if (mounted) setState(() => _code = '');
    }
  }

  void _erase() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.dark
        ? AarastV3Color.onPrimary
        : widget.failed
        ? AarastV3Color.danger
        : AarastV3Color.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'أُدخل ${_code.length} من ${AppLockController.codeLength}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < AppLockController.codeLength; index++)
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _code.length || widget.failed
                        ? dot
                        : Colors.transparent,
                    border: Border.all(color: dot, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        // Digits read left to right like a phone pad, even in Arabic.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final digit in row) _key(digit)],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tile(null),
                  _key('0'),
                  _tile(
                    Semantics(
                      button: true,
                      label: 'مسح',
                      child: Tooltip(
                        message: 'مسح',
                        child: AarastPressable(
                          onTap: widget.enabled ? _erase : null,
                          borderRadius: BorderRadius.circular(22),
                          child: Center(
                            child: Icon(
                              LucideIcons.delete,
                              size: 26,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color get _ink {
    if (widget.dark) return AarastV3Color.onPrimary;
    return widget.enabled ? AarastV3Color.text : AarastV3Color.textFaint;
  }

  Widget _tile(Widget? child) {
    final Color fill;
    if (widget.dark) {
      fill = child == null
          ? Colors.transparent
          : AarastV3Color.paper.withValues(alpha: 0.14);
    } else {
      fill = widget.enabled ? AarastV3Color.paper : AarastV3Color.line;
    }
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        width: 74,
        height: 62,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(widget.dark ? 31 : 22),
        ),
        child: child,
      ),
    );
  }

  Widget _key(String digit) {
    return _tile(
      AarastPressable(
        key: Key('app-lock-key-$digit'),
        onTap: widget.enabled ? () => _press(digit) : null,
        semanticLabel: digit,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Text(
            digit,
            style: JourneyType.of(
              JourneyType.figure,
              weight: JourneyType.bold,
              color: _ink,
            ),
          ),
        ),
      ),
    );
  }
}
