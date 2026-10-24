import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show ProviderDashboardProfile;
import '../widgets/provider_join_parts.dart';

/// p11 «ما قدرنا نوافق الآن»: the review team refused the profile.
///
/// The server keeps a refused profile read-only and refuses a second
/// application (F2, F3), so there is no «صلّح وقدّم من جديد» until B-02:
/// the screen shows the reason the team wrote and support, and does not say
/// «مو نهاية الطريق».
class ProviderRejectedScreen extends StatelessWidget {
  const ProviderRejectedScreen({
    required this.profile,
    required this.onRefresh,
    required this.onSupport,
    required this.onAccount,
    super.key,
  });

  final ProviderDashboardProfile profile;
  final Future<void> Function() onRefresh;
  final VoidCallback onSupport;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final reason = profile.reviewNote?.trim() ?? '';
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
                    message: 'لو عندك سؤال عن القرار، كلّم الدعم.',
                    trailing: ProviderAccountButton(onPressed: onAccount),
                  ),
                  if (reason.isNotEmpty)
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
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: JourneyButton(
              key: const Key('provider-rejected-support'),
              label: 'تكلّم مع الدعم',
              icon: LucideIcons.messageCircle,
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
