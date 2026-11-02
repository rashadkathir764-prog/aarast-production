import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../widgets/provider_join_parts.dart';

/// p02 «لقينا ملف بنفس رقمك»: the team listed this business under the
/// account's phone (F4). «إيه، هذا ملفي» asks the review team for it
/// (B-12, D41); it becomes this account's once they approve, so «بعد ما
/// تستلمه تعدّل كل شيء فيه» is true.
///
/// The listing reads with its category and city («تصوير · صنعاء»); the
/// waiting requests and the views the design draws are not shown (an
/// unclaimed listing cannot receive requests). «مو أنا، أشتي ملف جديد» cannot
/// work (apply refuses a phone with a listing, B-13), so the other way out
/// is support. After a refused claim, the team's reason shows and the claim
/// can be sent again.
class ProviderClaimScreen extends StatelessWidget {
  const ProviderClaimScreen({
    required this.businessName,
    required this.submitting,
    required this.onBack,
    required this.onClaim,
    required this.onSupport,
    this.kind = '',
    this.errorMessage,
    this.refusal,
    super.key,
  });

  final String businessName;

  /// The listing's category and city, under its name (p02).
  final String kind;
  final bool submitting;
  final String? errorMessage;

  /// The team's reason when they refused this account's last claim; empty
  /// when they gave none, null when nothing was refused.
  final String? refusal;
  final VoidCallback onBack;
  final VoidCallback onClaim;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final refusal = this.refusal;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              children: [
                JourneySubHeader(title: '', onBack: onBack),
                const Center(
                  child: JourneyIconTile(
                    icon: LucideIcons.store,
                    color: AarastV3Color.primary,
                    soft: AarastV3Color.primarySoft,
                    size: 64,
                    radius: 24,
                  ),
                ),
                const SizedBox(height: AarastV3Space.x3),
                Semantics(
                  header: true,
                  child: Text(
                    'لقينا ملف بنفس رقمك',
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.display,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AarastV3Space.x1),
                Text(
                  'فريق اعّرست أضافه من الدليل. استلمه وكمّله.',
                  textAlign: TextAlign.center,
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: AarastV3Space.x4),
                if (refusal != null) ...[
                  JourneyNote(
                    key: const Key('provider-claim-refusal'),
                    text: refusal.trim().isEmpty
                        ? 'ما قبلنا طلب الاستلام اللي قبل. تقدر ترسله من جديد.'
                        : 'ما قبلنا الاستلام: ${refusal.trim()}',
                    icon: LucideIcons.messageSquare,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                  const SizedBox(height: AarastV3Space.x3),
                ],
                JourneyBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProviderIdentityRow(name: businessName, kind: kind),
                      const SizedBox(height: AarastV3Space.x3),
                      const ProviderFactRow(
                        icon: LucideIcons.pencil,
                        text: 'بعد ما تستلمه تعدّل كل شيء فيه',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AarastV3Space.x3),
                JourneyButton(
                  key: const Key('provider-claim-support'),
                  label: 'مو أنا؟ تواصل مع الدعم',
                  background: AarastV3Color.paper,
                  foreground: AarastV3Color.textMuted,
                  expand: true,
                  onPressed: submitting ? null : onSupport,
                ),
                if (errorMessage case final message?) ...[
                  const SizedBox(height: AarastV3Space.x3),
                  JourneyNote(
                    key: const Key('provider-claim-error'),
                    text: message,
                    icon: LucideIcons.alertCircle,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const Key('provider-claim-confirm'),
              label: 'إيه، هذا ملفي',
              icon: LucideIcons.check,
              expand: true,
              large: true,
              loading: submitting,
              onPressed: onClaim,
            ),
          ),
        ],
      ),
    );
  }
}

/// p08 for a claim (B-12, D41): «طلب الاستلام قيد المراجعة». The listing
/// stays unclaimed and takes no requests until the team hands it over, and
/// the answer comes as a notice here.
class ProviderClaimPendingScreen extends StatelessWidget {
  const ProviderClaimPendingScreen({
    required this.businessName,
    required this.sentAt,
    required this.onRefresh,
    required this.onBack,
    required this.onSupport,
    super.key,
  });

  /// The listing asked for.
  final String businessName;

  /// When the claim was sent; null when the server did not say.
  final DateTime? sentAt;
  final Future<void> Function() onRefresh;
  final VoidCallback onBack;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final sentAt = this.sentAt;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AarastV3Color.primary,
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AarastV3Density.pageInsets,
                children: [
                  ProviderStateHeading(
                    name: businessName,
                    kind: '',
                    icon: LucideIcons.hourglass,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                    title: 'طلب الاستلام قيد المراجعة',
                    message: sentAt == null
                        ? 'وصلنا طلبك. نبلغك هنا.'
                        : 'أرسلته ${providerMomentLabel(sentAt)}. نبلغك هنا.',
                    trailing: JourneyRoundButton(
                      key: const Key('provider-claim-pending-back'),
                      icon: LucideIcons.arrowRight,
                      tooltip: 'رجوع',
                      onPressed: onBack,
                    ),
                  ),
                  const JourneyBox(
                    child: Column(
                      children: [
                        ProviderFactRow(
                          icon: LucideIcons.eyeOff,
                          text: 'الملف ما يستقبل طلبات لين نسلّمك إياه',
                        ),
                        ProviderFactRow(
                          icon: LucideIcons.phone,
                          text: 'ممكن يتصل بك فريق اعّرست يتأكد إنك صاحبه',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const Key('provider-claim-pending-support'),
              label: 'التواصل مع الدعم',
              icon: LucideIcons.messageCircle,
              background: AarastV3Color.paper,
              foreground: AarastV3Color.primary,
              expand: true,
              large: true,
              onPressed: onSupport,
            ),
          ),
        ],
      ),
    );
  }
}
