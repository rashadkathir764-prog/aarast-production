import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show ProviderDashboardProfile;
import '../widgets/provider_join_parts.dart';

/// p11 «ما قدرنا نوافق الآن»: the review team refused the profile.
///
/// The profile stays read-only while refused; «تعديل الملف وإعادة التقديم»
/// reopens it for fixing (B-02), with the reason as its note on p09, and the
/// fixed profile goes back to review from there (B-01). Support stays one tap
/// away for a question about the decision. No gender is kept for a provider,
/// so these words never address one.
class ProviderRejectedScreen extends StatelessWidget {
  const ProviderRejectedScreen({
    required this.profile,
    required this.submitting,
    required this.onRefresh,
    required this.onReopen,
    required this.onSupport,
    required this.onAccount,
    this.errorMessage,
    super.key,
  });

  final ProviderDashboardProfile profile;
  final bool submitting;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onReopen;
  final VoidCallback onSupport;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final reason = profile.reviewNote?.trim() ?? '';
    final error = errorMessage;
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  ProviderStateHeading(
                    name: profile.businessName,
                    kind: providerKindLine(
                      category: profile.primaryCategory?.nameAr,
                      city: profile.city?.nameAr,
                    ),
                    icon: LucideIcons.fileX,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                    title: 'ما قدرنا نوافق الآن',
                    message:
                        'مو نهاية الطريق. بعد التعديل يرجع الطلب للمراجعة.',
                    trailing: ProviderAccountButton(onPressed: onAccount),
                  ),
                  if (reason.isNotEmpty) ...[
                    JourneyBox(
                      key: const Key('provider-rejected-reason'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السبب',
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: JourneyType.of(
                              JourneyType.bodyLarge,
                              weight: JourneyType.bold,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  JourneyButton(
                    key: const Key('provider-rejected-support'),
                    label: 'التواصل مع الدعم',
                    icon: LucideIcons.messageCircle,
                    background: AarastV3Color.paper,
                    foreground: AarastV3Color.primary,
                    expand: true,
                    onPressed: submitting ? null : onSupport,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    JourneyNote(
                      key: const Key('provider-rejected-error'),
                      text: error,
                      icon: LucideIcons.alertCircle,
                      color: AarastV3Color.danger,
                      soft: AarastV3Color.dangerSoft,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: JourneyButton(
              key: const Key('provider-rejected-reopen'),
              label: 'تعديل الملف وإعادة التقديم',
              expand: true,
              large: true,
              loading: submitting,
              onPressed: onReopen,
            ),
          ),
        ],
      ),
    );
  }
}
