import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../widgets/provider_join_parts.dart';

/// p02 «لقينا ملف بنفس رقمك»: the team listed this business under the
/// account's phone (F4). Claiming makes it this account's, already approved,
/// so «بعد ما تستلمه تعدّل كل شيء فيه» is true.
///
/// The server's claim lookup gives the name only, so the category, the city,
/// the waiting requests and the views the design draws are not shown (an
/// unclaimed listing cannot receive requests). «مو أنا، أشتي ملف جديد» cannot
/// work (apply refuses a phone with a listing), so the other way out is
/// support.
class ProviderClaimScreen extends StatelessWidget {
  const ProviderClaimScreen({
    required this.businessName,
    required this.submitting,
    required this.onBack,
    required this.onClaim,
    required this.onSupport,
    this.errorMessage,
    super.key,
  });

  final String businessName;
  final bool submitting;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onClaim;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                JourneySubHeader(title: '', onBack: onBack),
                const Center(
                  child: JourneyIconTile(
                    icon: LucideIcons.store,
                    color: AarastV3Color.primary,
                    soft: AarastV3Color.primarySoft,
                    size: 76,
                    radius: 24,
                  ),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 4),
                Text(
                  'فريق اعّرست أضافه من الدليل. استلمه وكمّله.',
                  textAlign: TextAlign.center,
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                JourneyBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProviderIdentityRow(name: businessName),
                      const SizedBox(height: 12),
                      const ProviderFactRow(
                        icon: LucideIcons.pencil,
                        text: 'بعد ما تستلمه تعدّل كل شيء فيه',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                JourneyButton(
                  key: const Key('provider-claim-support'),
                  label: 'مو أنا؟ تواصل مع الدعم',
                  background: AarastV3Color.paper,
                  foreground: AarastV3Color.textMuted,
                  expand: true,
                  onPressed: submitting ? null : onSupport,
                ),
                if (errorMessage case final message?) ...[
                  const SizedBox(height: 12),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
