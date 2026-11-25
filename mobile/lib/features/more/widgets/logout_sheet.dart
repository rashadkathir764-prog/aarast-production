import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/side_outboxes.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';

/// g11 «الخروج»: out of this phone, and «رجوع»; changes not yet sent are
/// named first (C59). Pops true to sign out, or null for «رجوع». The
/// account's deletion (w05, D63) is not here: leaving a phone and erasing an
/// account are not one sheet's choice (RA-MO-329); it is under «الخصوصية».
class LogoutSheet extends StatelessWidget {
  const LogoutSheet({required this.sync, super.key});

  final OfflineSyncService? sync;

  @override
  Widget build(BuildContext context) {
    final service = sync;
    return service == null
        ? _body(context, null)
        : ListenableBuilder(
            listenable: service,
            builder: (context, _) => _body(context, service),
          );
  }

  Widget _body(BuildContext context, OfflineSyncService? service) {
    // RA-MO-101: chat messages and offers wait outside the sync queue and
    // go with the sign-out too; they are named with the rest.
    final unsent = (service?.unsyncedCount ?? 0) + SideOutboxes.count();
    final sending = service?.state == SyncState.syncing;
    final offline = service?.state == SyncState.offline;
    return JourneySheetBody(
      title: context.say('تطلع من حسابك؟', 'تطلعين من حسابك؟'),
      children: [
        if (unsent > 0) ...[
          JourneyNote(
            key: const ValueKey('account-logout-unsent'),
            icon: LucideIcons.cloudOff,
            color: AarastV3Color.amber,
            soft: AarastV3Color.amberSoft,
            text:
                'عندك ${arabicCount(unsent, one: 'تغيير واحد', two: 'تغييرين', few: 'تغييرات', many: 'تغيير')} '
                'ما وصل لحسابك. ${context.say('لو طلعت', 'لو طلعتِ')} الحين يضيع من هذا الجوال.',
          ),
          if (!offline && service != null) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyButton(
              key: const ValueKey('account-logout-send'),
              label: context.say('أرسلها الحين', 'أرسليها الحين'),
              expand: true,
              loading: sending,
              onPressed: sending ? null : service.syncPendingChanges,
            ),
          ],
          const SizedBox(height: AarastV3Space.x3),
        ],
        AarastPressable(
          key: const ValueKey('account-logout-confirm'),
          onTap: () => Navigator.of(context).pop(true),
          borderRadius: BorderRadius.circular(AarastV3Radius.card),
          semanticLabel: context.say(
            'اخرج من هذا الجوال',
            'اخرجي من هذا الجوال',
          ),
          child: JourneyBox(
            padding: const EdgeInsets.all(AarastV3Space.x4),
            child: Row(
              children: [
                const Icon(LucideIcons.logOut, color: AarastV3Color.ink),
                const SizedBox(width: AarastV3Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.say(
                          'اخرج من هذا الجوال',
                          'اخرجي من هذا الجوال',
                        ),
                        style: JourneyType.of(
                          JourneyType.lead,
                          weight: JourneyType.bold,
                        ),
                      ),
                      Text(
                        unsent > 0
                            ? 'خطتك تبقى، بس اللي ما وصل يضيع'
                            : context.say(
                                'خطتك تبقى، وترجع لها برقمك',
                                'خطتك تبقى، وترجعين لها برقمك',
                              ),
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
        const SizedBox(height: AarastV3Space.x3),
        JourneyButton(
          label: 'رجوع',
          background: AarastV3Color.paper,
          foreground: AarastV3Color.ink,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
