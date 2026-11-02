import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show ProviderDashboardProfile;
import '../widgets/provider_join_parts.dart';

/// p08 «طلبك قيد المراجعة»: what happens while the team reviews.
///
/// Only in-app notices exist, so the line says «نبلغك هنا» (no WhatsApp and
/// no review time the server does not keep). Photos need approval (F2), so
/// the provider can edit his profile's details while he waits.
class ProviderPendingScreen extends StatelessWidget {
  const ProviderPendingScreen({
    required this.profile,
    required this.onRefresh,
    required this.onEdit,
    required this.onAccount,
    super.key,
  });

  final ProviderDashboardProfile profile;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    // After «أرسلت التعديل» it is the latest send, not the application.
    final sentAt = profile.sentForReviewAt;
    final kind = providerKindLine(
      category: profile.primaryCategory?.nameAr,
      city: profile.city?.nameAr,
    );
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
                    name: profile.businessName,
                    kind: kind,
                    icon: LucideIcons.hourglass,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                    title: 'طلبك قيد المراجعة',
                    message: sentAt == null
                        ? 'وصلنا طلبك. نبلغك هنا.'
                        : 'أرسلته ${providerMomentLabel(sentAt)}. نبلغك هنا.',
                    trailing: ProviderAccountButton(onPressed: onAccount),
                  ),
                  const JourneyBox(
                    child: Column(
                      children: [
                        ProviderFactRow(
                          icon: LucideIcons.eyeOff,
                          text: 'ملفك مخفي عن العرسان لين نوافق',
                        ),
                        ProviderFactRow(
                          icon: LucideIcons.pencil,
                          text: 'تقدر تعدّل بيانات ملفك وأنت تنتظر',
                        ),
                        ProviderFactRow(
                          icon: LucideIcons.phone,
                          text: 'ممكن يتصل بك فريق اعّرست يتأكد من البيانات',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  JourneyButton(
                    key: const Key('provider-pending-preview'),
                    label: 'شوف ملفك مثل العرسان',
                    icon: LucideIcons.eye,
                    background: AarastV3Color.paper,
                    foreground: AarastV3Color.primary,
                    expand: true,
                    onPressed: () => _preview(context, kind),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const Key('provider-pending-edit'),
              label: 'عدّل طلبك',
              icon: LucideIcons.pencil,
              background: AarastV3Color.paper,
              foreground: AarastV3Color.primary,
              expand: true,
              large: true,
              onPressed: onEdit,
            ),
          ),
        ],
      ),
    );
  }

  /// The profile as the couples will see it, built from what was sent.
  Future<void> _preview(BuildContext context, String kind) {
    return showJourneySheet<void>(
      context: context,
      builder: (_) => JourneySheetBody(
        title: 'كذا بيشوفك العرسان',
        subtitle: 'بعد الموافقة',
        children: [ProviderPreviewCard(name: profile.businessName, kind: kind)],
      ),
    );
  }
}
