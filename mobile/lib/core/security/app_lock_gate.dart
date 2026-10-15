import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import 'app_lock_controller.dart';

/// Covers the app with the lock screen while the account's app lock is
/// closed (V1 checklist 4.15). The app underneath keeps its navigation, so
/// unlocking returns exactly where the user was.
class AppLockGate extends StatelessWidget {
  const AppLockGate({required this.child, required this.onForgotCode, super.key});

  final Widget child;

  /// Signs the account out after its code was cleared.
  final Future<void> Function() onForgotCode;

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
          const ColoredBox(color: AppTheme.canvas)
        else if (lock.isLocked)
          AppLockScreen(lock: lock, onForgotCode: onForgotCode),
      ],
    );
  }
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({required this.lock, required this.onForgotCode, super.key});

  final AppLockController lock;
  final Future<void> Function() onForgotCode;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String? _error;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _submit(String code) async {
    final opened = await widget.lock.unlock(code);
    if (!mounted || opened) return;
    final wait = widget.lock.waitRemaining;
    setState(() {
      _error = wait > Duration.zero
          ? 'محاولات كثيرة. انتظر ${_waitLabel(wait)} ثم حاول.'
          : 'الرمز غير صحيح.';
    });
    if (wait > Duration.zero) {
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return timer.cancel();
        final left = widget.lock.waitRemaining;
        setState(() {
          _error = left > Duration.zero
              ? 'محاولات كثيرة. انتظر ${_waitLabel(left)} ثم حاول.'
              : null;
        });
        if (left == Duration.zero) timer.cancel();
      });
    }
  }

  Future<void> _forgot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نسيت الرمز؟'),
        content: const Text(
          'سنخرجك من الحساب ويُلغى الرمز. ادخل مرة أخرى برقم جوالك ورمز واتساب، '
          'وبياناتك محفوظة في حسابك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('خروج وإلغاء الرمز'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.lock.forgetForSignOut();
    await widget.onForgotCode();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = widget.lock.waitRemaining > Duration.zero;
    return Material(
      key: const Key('app-lock-screen'),
      color: AppTheme.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.lock, size: 40, color: AppTheme.brand),
                const SizedBox(height: 12),
                Text(
                  'أدخل رمز القفل',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                AppLockCodePad(
                  enabled: !waiting,
                  error: _error,
                  onCompleted: _submit,
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: _forgot, child: const Text('نسيت الرمز؟')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _waitLabel(Duration wait) {
  final seconds = wait.inSeconds + (wait.inMilliseconds % 1000 > 0 ? 1 : 0);
  if (seconds < 60) return '$seconds ثانية';
  return '${(seconds / 60).ceil()} دقيقة';
}

/// Four dots and a digit pad (no system keyboard, so nothing is predicted
/// or remembered). Calls [onCompleted] with the full code and clears.
class AppLockCodePad extends StatefulWidget {
  const AppLockCodePad({
    required this.onCompleted,
    this.enabled = true,
    this.error,
    super.key,
  });

  final FutureOr<void> Function(String code) onCompleted;
  final bool enabled;
  final String? error;

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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'أُدخل ${_code.length} من ${AppLockController.codeLength}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < AppLockController.codeLength; index += 1)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _code.length ? AppTheme.brand : Colors.transparent,
                    border: Border.all(color: AppTheme.brand, width: 2),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: widget.error == null
                ? null
                : Text(
                    widget.error!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: AppTheme.danger),
                  ),
          ),
        ),
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
                  const SizedBox(width: 88, height: 72),
                  _key('0'),
                  SizedBox(
                    width: 88,
                    height: 72,
                    child: IconButton(
                      tooltip: 'مسح',
                      onPressed: widget.enabled ? _erase : null,
                      icon: const Icon(LucideIcons.delete),
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

  Widget _key(String digit) {
    return SizedBox(
      width: 88,
      height: 72,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: OutlinedButton(
          key: Key('app-lock-key-$digit'),
          onPressed: widget.enabled ? () => _press(digit) : null,
          style: OutlinedButton.styleFrom(shape: const CircleBorder()),
          child: Text(
            digit,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
