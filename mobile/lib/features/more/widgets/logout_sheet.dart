import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';

/// What the person chose on g11.
enum LogoutChoice { signOut, deleteAccount }

/// g11 «الخروج»: out of this phone, «احذف حسابي نهائيًا» (w05, D63: erased
/// after 30 days and can be taken back, C4) and «رجوع»; changes not yet sent
/// are named first (C59). Pops the [LogoutChoice], or null for «رجوع».
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
    final unsent = service?.unsyncedCount ?? 0;
    final sending = service?.state == SyncState.syncing;
    final offline = service?.state == SyncState.offline;
    return JourneySheetBody(
      title: 'الخروج',
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
            const SizedBox(height: 10),
            JourneyButton(
              key: const ValueKey('account-logout-send'),
              label: context.say('أرسلها الحين', 'أرسليها الحين'),
              expand: true,
              loading: sending,
              onPressed: sending ? null : service.syncPendingChanges,
            ),
          ],
          const SizedBox(height: 12),
        ],
        AarastPressable(
          key: const ValueKey('account-logout-confirm'),
          onTap: () => Navigator.of(context).pop(LogoutChoice.signOut),
          borderRadius: BorderRadius.circular(22),
          semanticLabel: context.say(
            'اخرج من هذا الجوال',
            'اخرجي من هذا الجوال',
          ),
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
                        context.say(
                          'اخرج من هذا الجوال',
                          'اخرجي من هذا الجوال',
                        ),
                        style: JourneyType.of(
                          JourneyType.bodyLarge,
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
        const SizedBox(height: 14),
        AarastPressable(
          key: const ValueKey('account-delete-account'),
          onTap: () => Navigator.of(context).pop(LogoutChoice.deleteAccount),
          borderRadius: BorderRadius.circular(22),
          semanticLabel: context.say(
            'احذف حسابي نهائيًا',
            'احذفي حسابي نهائيًا',
          ),
          child: JourneyBox(
            color: AarastV3Color.dangerSoft,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.trash2, color: AarastV3Color.danger),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.say(
                          'احذف حسابي نهائيًا',
                          'احذفي حسابي نهائيًا',
                        ),
                        style: JourneyType.of(
                          JourneyType.bodyLarge,
                          weight: JourneyType.bold,
                          color: AarastV3Color.danger,
                        ),
                      ),
                      Text(
                        // C4: the 30 days, not «وما ترجع».
                        context.say(
                          'تنحذف بعد 30 يوم، وتقدر تتراجع',
                          'تنحذف بعد 30 يوم، وتقدرين تتراجعين',
                        ),
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.danger,
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
