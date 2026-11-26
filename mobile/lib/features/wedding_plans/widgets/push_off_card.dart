import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/push/push_notifications_controller.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/widgets/aarast_toast.dart';

/// w39 «التنبيهات مقفلة»: the phone has this app's notifications off, so
/// payment reminders and providers' answers would never arrive. Shown on
/// the home until they are on again or «لاحقًا» puts it away for a week.
///
/// RA-MO-359: a phone with no Google services cannot get phone alerts at
/// all, whatever the settings say; the card says so and that the alerts
/// stay in the app, with no settings to open.
class PushOffCard extends StatefulWidget {
  const PushOffCard({this.now, super.key});

  /// Fixed in tests.
  final DateTime? now;

  @override
  State<PushOffCard> createState() => _PushOffCardState();
}

class _PushOffCardState extends State<PushOffCard>
    with WidgetsBindingObserver {
  bool _off = false;

  /// The phone's settings were opened from here: coming back, the card
  /// reads the phone again and goes once they are on.
  bool _sentToSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  PushNotificationsController? get _push {
    try {
      return context.read<PushNotificationsController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _check() async {
    final push = _push;
    final off = await push?.isTurnedOff() ?? false;
    if (!mounted) return;
    if (_sentToSettings && !off) {
      _sentToSettings = false;
      await push?.turnedOnInPhoneSettings();
      if (!mounted) return;
      AarastToast.showSuccess(context, 'انفتحت التنبيهات.');
    }
    if (off != _off) setState(() => _off = off);
  }

  Future<void> _open() async {
    final opened = await _push?.openPhoneSettings() ?? false;
    if (!mounted) return;
    if (opened) {
      _sentToSettings = true;
    } else {
      AarastToast.showInfo(
        context,
        '${context.say('افتحها', 'افتحيها')} من إعدادات الجوال › التطبيقات › '
        'اعّرست › الإشعارات.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<DevicePreferences?>();
    final now = widget.now ?? appNow();
    final hiddenUntil = preferences?.pushCardHiddenUntil;
    final unavailable = context.select<PushNotificationsController?, bool>(
      (push) => push?.unavailableOnThisPhone ?? false,
    );
    if (!(_off || unavailable) ||
        (hiddenUntil != null && now.isBefore(hiddenUntil))) {
      return const SizedBox.shrink();
    }
    return JourneyBox(
      key: const ValueKey('push-off-card'),
      borderColor: AarastV3Color.saffron,
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JourneyIconTile(
            icon: LucideIcons.bellOff,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
            size: AarastV3Size.mark,
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unavailable
                      ? 'تنبيهات الجوال ما تشتغل هنا'
                      : 'التنبيهات مقفلة',
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
                  ),
                ),
                const SizedBox(height: AarastV3Space.half),
                Text(
                  unavailable
                      ? 'جوالك ما يدعم تنبيهات الجوال (خدمات جوجل)، '
                            'فتنبيهاتك تظهر داخل اعّرست.'
                      : 'ما راح يوصلك موعد دفعة ولا رد مزود. '
                            '${context.say('افتحها', 'افتحيها')} من إعدادات الجوال.',
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: AarastV3Space.x3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!unavailable)
                      JourneyButton(
                        key: const ValueKey('push-off-open'),
                        label: context.say('افتح الإعدادات', 'افتحي الإعدادات'),
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
