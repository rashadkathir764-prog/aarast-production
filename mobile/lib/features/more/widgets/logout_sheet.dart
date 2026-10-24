import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';

/// g11 «الخروج»: one way out of this phone and «رجوع»; changes not yet sent
/// are named first (C59). Pops true to sign out.
class LogoutSheet extends StatelessWidget {
  const LogoutSheet({required this.sync, super.key});

  final OfflineSyncService? sync;

  @override
  Widget build(BuildContext context) {
    final service = sync;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: service == null
              ? _body(context, null)
              : ListenableBuilder(
                  listenable: service,
                  builder: (context, _) => _body(context, service),
                ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, OfflineSyncService? service) {
    final unsent = service?.unsyncedCount ?? 0;
    final sending = service?.state == SyncState.syncing;
    final offline = service?.state == SyncState.offline;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الخروج',
          style: JourneyType.of(JourneyType.display, weight: JourneyType.bold),
        ),
        const SizedBox(height: 16),
        if (unsent > 0) ...[
          JourneyNote(
            key: const ValueKey('account-logout-unsent'),
            icon: LucideIcons.cloudOff,
            color: AarastV3Color.amber,
            soft: AarastV3Color.amberSoft,
            text:
                'عندك ${arabicCount(unsent, one: 'تغيير واحد', two: 'تغييرين', few: 'تغييرات', many: 'تغيير')} '
                'ما وصل لحسابك. لو طلعت الحين يضيع من هذا الجوال.',
          ),
          if (!offline && service != null) ...[
            const SizedBox(height: 10),
            JourneyButton(
              key: const ValueKey('account-logout-send'),
              label: 'أرسلها الحين',
              expand: true,
              loading: sending,
              onPressed: sending ? null : service.syncPendingChanges,
            ),
          ],
          const SizedBox(height: 12),
        ],
        AarastPressable(
          key: const ValueKey('account-logout-confirm'),
          onTap: () => Navigator.of(context).pop(true),
          borderRadius: BorderRadius.circular(22),
          semanticLabel: 'اخرج من هذا الجوال',
          child: JourneyBox(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.logOut, color: AarastV3Color.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اخرج من هذا الجوال',
                        style: JourneyType.of(
                          JourneyType.bodyLarge,
                          weight: JourneyType.bold,
                        ),
                      ),
                      Text(
                        unsent > 0
                            ? 'خطتك تبقى، بس اللي ما وصل يضيع'
                            : 'خطتك تبقى، وترجع لها برقمك',
                        style: JourneyType.of(
                          JourneyType.small,
                          color: unsent > 0
                              ? AarastV3Color.danger
                              : AarastV3Color.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        JourneyButton(
          label: 'رجوع',
          background: AarastV3Color.paper,
          foreground: AarastV3Color.ink,
          expand: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
