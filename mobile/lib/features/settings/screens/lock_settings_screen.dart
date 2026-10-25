import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/security/app_lock_gate.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';

/// g08 «قفل التطبيق», drawn as the lock's settings (C50): with no code, the
/// pad chooses one and asks it again; with a code, change it or take the
/// lock off. The fingerprint key is left out (no biometric support in this
/// build, D24).
class LockSettingsScreen extends StatefulWidget {
  const LockSettingsScreen({super.key});

  @override
  State<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends State<LockSettingsScreen> {
  /// Choosing a code: null before the first entry, then the first entry.
  bool _choosing = false;
  String? _first;
  bool _mismatch = false;

  @override
  Widget build(BuildContext context) {
    AppLockController? lock;
    try {
      lock = context.watch<AppLockController>();
    } on ProviderNotFoundException {
      lock = null;
    }
    final controller = lock;
    final choosing = _choosing || (controller != null && !controller.isEnabled);

    final Widget body;
    if (controller == null || controller.userId == null) {
      body = Text(
        context.say(
          'ادخل حسابك أول عشان تقفل التطبيق برمز.',
          'ادخلي حسابك أول عشان تقفلين التطبيق برمز.',
        ),
        textAlign: TextAlign.center,
        style: JourneyType.of(
          JourneyType.bodyLarge,
          color: AarastV3Color.onPrimary,
        ),
      );
    } else if (choosing) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _mismatch
                ? context.say(
                    'الرمزين مختلفين، ابدأ من جديد',
                    'الرمزين مختلفين، ابدئي من جديد',
                  )
                : _first == null
                ? context.say('اختر رمز من 4 أرقام', 'اختاري رمز من 4 أرقام')
                : context.say('اكتبه مرة ثانية', 'اكتبيه مرة ثانية'),
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.title,
              weight: JourneyType.bold,
              color: AarastV3Color.onPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.say(
              'لا تستخدم تاريخ ميلاد أو رقم يعرفه غيرك.',
              // «لا» forbids: the jussive, «لا تستخدمي».
              'لا تستخدمي تاريخ ميلاد أو رقم يعرفه غيرك.',
            ),
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.small,
              color: context.accent.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 24),
          AppLockCodePad(
            key: ValueKey(_first == null ? 'first' : 'confirm'),
            dark: true,
            onCompleted: (code) => _entered(controller, code),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            LucideIcons.lock,
            size: 44,
            color: AarastV3Color.onPrimary,
          ),
          const SizedBox(height: 12),
          Text(
            'التطبيق مقفول برمزك',
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.title,
              weight: JourneyType.bold,
              color: AarastV3Color.onPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.say(
              'نطلبه لما تفتح التطبيق، وبعد دقيقة برّاه.',
              'نطلبه لما تفتحين التطبيق، وبعد دقيقة برّاه.',
            ),
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.body,
              color: context.accent.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 24),
          JourneyButton(
            key: const Key('lock-change-code'),
            label: context.say('غيّر الرمز', 'غيّري الرمز'),
            background: AarastV3Color.paper,
            foreground: context.accent.primary,
            expand: true,
            onPressed: () => setState(() {
              _choosing = true;
              _first = null;
              _mismatch = false;
            }),
          ),
          const SizedBox(height: 10),
          Center(
            child: JourneyTextAction(
              key: const Key('lock-turn-off'),
              label: context.say('شيل القفل', 'شيلي القفل'),
              color: AarastV3Color.onPrimary,
              onPressed: () => _turnOff(controller),
            ),
          ),
        ],
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: context.accent.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyRoundButton(
                icon: LucideIcons.arrowRight,
                tooltip: 'رجوع',
                size: 42,
                onPressed: _close,
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: JourneyWordmark(color: AarastV3Color.onPrimary),
            ),
            const SizedBox(height: 28),
            body,
          ],
        ),
      ),
    );
  }

  Future<void> _entered(AppLockController lock, String code) async {
    final first = _first;
    if (first == null) {
      setState(() {
        _first = code;
        _mismatch = false;
      });
      return;
    }
    if (first != code) {
      setState(() {
        _first = null;
        _mismatch = true;
      });
      return;
    }
    await lock.setCode(code);
    if (!mounted) return;
    setState(() {
      _choosing = false;
      _first = null;
    });
    AarastToast.showSuccess(context, 'انقفل التطبيق برمزك.');
  }

  Future<void> _turnOff(AppLockController lock) async {
    await lock.disable();
    if (!mounted) return;
    AarastToast.showInfo(context, 'شلنا قفل التطبيق.');
    _close();
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go(AppRouter.more);
    }
  }
}
