import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/security/app_lock_gate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';

/// Turns the account's app lock on or off, or changes its code (V1
/// checklist 4.15). It takes effect at once; it is not part of the saved
/// notification preferences.
class AppLockSettingsSection extends StatelessWidget {
  const AppLockSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    AppLockController? lock;
    try {
      lock = context.watch<AppLockController>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    if (lock.userId == null) return const SizedBox.shrink();
    final controller = lock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AarastV3SectionHeader(
          title: 'الأمان',
          subtitle: 'لمن يتشارك الجوال مع العائلة',
        ),
        const SizedBox(height: AarastV3Space.x2),
        AarastV3ContinuousSurface(
          children: [
            SwitchListTile(
              key: const Key('settings-app-lock-switch'),
              secondary: const Icon(LucideIcons.lock, color: AppTheme.brand),
              title: const Text('قفل التطبيق برمز'),
              subtitle: const Text(
                'يُطلب الرمز عند فتح التطبيق، وبعد دقيقة خارجه.',
              ),
              value: controller.isEnabled,
              onChanged: (enable) async {
                if (enable) {
                  await _chooseCode(context, controller);
                } else {
                  await controller.disable();
                  if (context.mounted) {
                    AarastToast.showInfo(context, 'أُلغي قفل التطبيق.');
                  }
                }
              },
            ),
            if (controller.isEnabled)
              ListTile(
                key: const Key('settings-app-lock-change'),
                leading: const Icon(LucideIcons.keyRound, color: AppTheme.brand),
                title: const Text('تغيير الرمز'),
                onTap: () => _chooseCode(context, controller),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _chooseCode(BuildContext context, AppLockController lock) async {
    final chosen = await showAarastBottomSheet<bool>(
      context: context,
      builder: (_) => _ChooseCodeSheet(lock: lock),
    );
    if (chosen == true && context.mounted) {
      AarastToast.showSuccess(context, 'فُعّل قفل التطبيق.');
    }
  }
}

class _ChooseCodeSheet extends StatefulWidget {
  const _ChooseCodeSheet({required this.lock});

  final AppLockController lock;

  @override
  State<_ChooseCodeSheet> createState() => _ChooseCodeSheetState();
}

class _ChooseCodeSheetState extends State<_ChooseCodeSheet> {
  String? _first;
  String? _error;

  Future<void> _entered(String code) async {
    final first = _first;
    if (first == null) {
      setState(() {
        _first = code;
        _error = null;
      });
      return;
    }
    if (first != code) {
      setState(() {
        _first = null;
        _error = 'الرمزان مختلفان. ابدأ من جديد.';
      });
      return;
    }
    await widget.lock.setCode(code);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _first == null ? 'اختر رمزًا من 4 أرقام' : 'أعد كتابة الرمز للتأكيد',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'لا تستخدم تاريخ ميلاد أو رقمًا يعرفه غيرك.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppLockCodePad(
              key: ValueKey(_first == null ? 'first' : 'confirm'),
              error: _error,
              onCompleted: _entered,
            ),
          ],
        ),
      ),
    );
  }
}
