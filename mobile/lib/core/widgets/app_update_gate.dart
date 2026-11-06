import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../experience_v3/aarast_v3.dart';
import '../network/api_contract.dart';
import 'aarast_ui.dart' show AarastScreenFrame;

/// D93 (RA-BE-01): once the server says this app is older than it serves,
/// «حدّث التطبيق» stands over everything. Nothing on the phone is lost: the
/// changes waiting to be sent stay, and the updated app sends them.
class AppUpdateGate extends StatelessWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appUpdateRequired,
      builder: (context, required, _) =>
          required ? const AppUpdateRequiredScreen() : child,
    );
  }
}

class AppUpdateRequiredScreen extends StatelessWidget {
  const AppUpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      key: const Key('app-update-required'),
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AarastV3Space.x4,
          AarastV3Space.x8,
          AarastV3Space.x4,
          AarastV3Space.x6,
        ),
        children: [
          Center(
            child: JourneyIconTile(
              icon: LucideIcons.download,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              size: 64,
              radius: 26,
            ),
          ),
          const SizedBox(height: AarastV3Space.x4),
          Text(
            'حدّث اعّرست',
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.pageTitle,
              weight: JourneyType.bold,
            ),
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            'النسخة اللي عندك صارت قديمة على الخادم. حدّثها من المتجر، '
            'واللي محفوظ في جوالك يبقى وينرسل بعد التحديث.',
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: AarastV3Space.x5),
          JourneyButton(
            key: const Key('app-update-open-store'),
            label: 'افتح المتجر',
            expand: true,
            large: true,
            onPressed: () => launchUrl(
              Uri.parse(appStoreUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}
