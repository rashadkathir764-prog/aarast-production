import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart' show AarastScreenFrame;
import '../../auth/auth_api.dart' show AuthController;
import '../widgets/account_data_download.dart';

/// w06 «الحذف بعد 30 يوم» (D63, a01): an account waiting out its deletion
/// sees only this, from the moment it asks or signs in, on any phone. It
/// reads the day of the erasure and may take the request back, or sign out.
/// Nothing else is reachable: the server refuses every other route
/// (`ACCOUNT_DELETION_PENDING`), its plans are closed to their members and
/// nobody is reminded of anything.
class DeletionPendingScreen extends StatefulWidget {
  const DeletionPendingScreen({super.key, this.openDownload});

  /// Opens the data download link; the phone's browser unless a test says.
  final DownloadLinkOpener? openDownload;

  @override
  State<DeletionPendingScreen> createState() => _DeletionPendingScreenState();
}

class _DeletionPendingScreenState extends State<DeletionPendingScreen> {
  String? _error;

  Future<void> _restore() async {
    setState(() => _error = null);
    final error = await context.read<AuthController>().cancelAccountDeletion();
    if (mounted && error != null) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final requestedAt = user?.deletionRequestedAt?.toLocal();
    final scheduledFor = user?.deletionScheduledFor?.toLocal();
    final now = appNow();
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = scheduledFor == null
        ? 0
        : DateTime(
            scheduledFor.year,
            scheduledFor.month,
            scheduledFor.day,
          ).difference(today).inDays;
    return AarastScreenFrame(
      key: const Key('deletion-pending-screen'),
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
          const Center(
            child: JourneyIconTile(
              icon: LucideIcons.hourglass,
              color: AarastV3Color.amber,
              soft: AarastV3Color.amberSoft,
              size: 64,
              radius: 26,
            ),
          ),
          const SizedBox(height: AarastV3Space.x4),
          Text(
            daysLeft <= 0
                ? 'حسابك ينحذف اليوم'
                : 'حسابك ينحذف بعد ${arabicDays(daysLeft)}',
            key: const Key('deletion-pending-title'),
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.pageTitle,
              weight: JourneyType.bold,
            ),
          ),
          const SizedBox(height: AarastV3Space.x1),
          if (requestedAt != null && scheduledFor != null)
            Text(
              context.say(
                'طلبت الحذف ${formatArabicDayMonth(requestedAt)}. لين ${formatArabicDayMonth(scheduledFor)} تقدر ترجع وكل شيء كما هو.',
                'طلبتِ الحذف ${formatArabicDayMonth(requestedAt)}. لين ${formatArabicDayMonth(scheduledFor)} تقدرين ترجعين وكل شيء كما هو.',
              ),
              key: const Key('deletion-pending-dates'),
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          const SizedBox(height: AarastV3Space.x5),
          // L29: the person speaks to the app, the same for both.
          JourneyButton(
            key: const Key('deletion-pending-restore'),
            label: 'تراجعت، رجّع حسابي',
            expand: true,
            large: true,
            loading: auth.isSubmitting,
            onPressed: auth.isSubmitting ? null : _restore,
          ),
          const SizedBox(height: AarastV3Space.x2),
          // RA-BE-56: these days are when someone leaving wants their data;
          // the server took the download back only with the deletion.
          JourneyButton(
            key: const Key('deletion-pending-download'),
            label: context.say('نزّل بياناتك', 'نزّلي بياناتك'),
            background: AarastV3Color.paper,
            foreground: AarastV3Color.text,
            expand: true,
            onPressed: auth.isSubmitting
                ? null
                : () => widget.openDownload == null
                      ? downloadAccountData(context)
                      : downloadAccountData(
                          context,
                          open: widget.openDownload!,
                        ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton(
            key: const Key('deletion-pending-sign-out'),
            label: context.say('اطلع', 'اطلعي'),
            background: AarastV3Color.paper,
            foreground: AarastV3Color.textMuted,
            expand: true,
            onPressed: auth.isSubmitting ? null : auth.logout,
          ),
          if (_error != null) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyNote(
              key: const Key('deletion-pending-error'),
              icon: LucideIcons.alertTriangle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
              text: _error!,
            ),
          ],
          const SizedBox(height: AarastV3Space.x4),
          const JourneyNote(
            icon: LucideIcons.lock,
            text: 'ما أحد يقدر يدخل خطتك خلال هذي المدة، ولا توصلك تذكيرات.',
          ),
        ],
      ),
    );
  }
}
