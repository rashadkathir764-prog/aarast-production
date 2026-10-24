import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/push/push_notifications_controller.dart';
import '../../../core/widgets/aarast_toast.dart';

/// w39 «التنبيهات مقفلة»: the phone has this app's notifications off, so
/// payment reminders and providers' answers would never arrive. Shown on
/// the home until they are on again or «لاحقًا» puts it away for a week.
class PushOffCard extends StatefulWidget {
  const PushOffCard({this.now, super.key});

  /// Fixed in tests.
  final DateTime? now;

  @override
  State<PushOffCard> createState() => _PushOffCardState();
}

class _PushOffCardState extends State<PushOffCard> {
  bool _off = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  PushNotificationsController? get _push {
    try {
      return context.read<PushNotificationsController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _check() async {
    final off = await _push?.isTurnedOff() ?? false;
    if (mounted && off != _off) setState(() => _off = off);
  }

  Future<void> _open() async {
    final on = await _push?.askAgain() ?? false;
    if (!mounted) return;
    if (on) {
      setState(() => _off = false);
      AarastToast.showSuccess(context, 'انفتحت التنبيهات.');
    } else {
      AarastToast.showInfo(
        context,
        'افتحها من إعدادات الجوال › التطبيقات › اعّرست › الإشعارات.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<DevicePreferences?>();
    final now = widget.now ?? DateTime.now();
    final hiddenUntil = preferences?.pushCardHiddenUntil;
    if (!_off || (hiddenUntil != null && now.isBefore(hiddenUntil))) {
      return const SizedBox.shrink();
    }
    return JourneyBox(
      key: const ValueKey('push-off-card'),
      borderColor: AarastV3Color.saffron,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JourneyIconTile(
            icon: LucideIcons.bellOff,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التنبيهات مقفلة',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ما راح يوصلك موعد دفعة ولا رد مزود. افتحها من إعدادات '
                  'الجوال.',
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    JourneyButton(
                      key: const ValueKey('push-off-open'),
                      label: 'افتح الإعدادات',
                      background: AarastV3Color.brandAccentStrong,
                      onPressed: _open,
                    ),
                    JourneyButton.quiet(
                      key: const ValueKey('push-off-later'),
                      label: 'لاحقًا',
                      onPressed: preferences == null
                          ? null
                          : () => preferences.hidePushCard(now),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
