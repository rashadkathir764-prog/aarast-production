import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/whatsapp_share.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show ProviderDashboardProfile;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_join_parts.dart' show providerKindLine;
import '../widgets/provider_profile_parts.dart';

/// Opens WhatsApp with a text; tests replace it.
typedef ProviderShareLauncher = Future<bool> Function(String text);

/// p48 «شارك ملفك»: a card made from his profile, to post where people
/// already look. It holds only what the server keeps: name, category, city,
/// the rating once he has one and «موثّق» with `verifiedAt` (classification
/// p48). There is no public link to his page yet (B-27), so no QR, link or
/// «ليالي فاضية»; the card says to find him in the app by name. The app has
/// no image sharing, so the card is for a screenshot and the WhatsApp
/// button sends its words.
class ProviderShareScreen extends StatelessWidget {
  const ProviderShareScreen({this.share, super.key});

  final ProviderShareLauncher? share;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProviderDashboardProvider>().profile;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const JourneySubHeader(title: 'شارك ملفك'),
                if (profile == null)
                  const JourneyListState(
                    phase: JourneyListPhase.loading,
                    section: JourneySection.home,
                  )
                else ...[
                  ProviderShareCard(profile: profile),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'صوّر البطاقة وحطها في حالتك، أو أرسل كلامها في واتساب.',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (profile != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: JourneyButton(
                key: const Key('provider-share-whatsapp'),
                label: 'أرسل في واتساب',
                icon: LucideIcons.messageCircle,
                background: AarastV3Color.mint,
                large: true,
                expand: true,
                onPressed: () => _send(context, profile),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _send(
    BuildContext context,
    ProviderDashboardProfile profile,
  ) async {
    final opened = await (share ?? shareOnWhatsApp)(providerShareText(profile));
    if (!opened && context.mounted) {
      AarastToast.showError(context, 'ما قدرنا نفتح واتساب في جوالك.');
    }
  }
}

/// The card's words, as WhatsApp sends them.
String providerShareText(ProviderDashboardProfile profile) {
  final name = profile.businessName.trim();
  final kind = providerKindLine(
    category: profile.primaryCategory?.nameAr,
    city: profile.city?.nameAr,
  );
  return [
    kind.isEmpty ? name : '$name · $kind',
    if (profile.ratingCount > 0)
      '★ ${providerRatingLabel(profile.ratingAverage, profile.ratingCount)}',
    if (profile.verifiedAt != null) 'موثّق في اعّرست',
    'اطلب عرضك من تطبيق اعّرست، ابحث باسم «$name».',
  ].join('\n');
}

/// The card (prototype p48): his cover or the dark teal on top with the
/// wordmark, then his name, kind and tags, and how to find him. One flat
/// colour where the design faded (no gradients in the kit).
class ProviderShareCard extends StatelessWidget {
  const ProviderShareCard({required this.profile, super.key});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.businessName.trim();
    final kind = providerKindLine(
      category: profile.primaryCategory?.nameAr,
      city: profile.city?.nameAr,
    );
    final cover = profile.coverUrl?.trim() ?? '';
    return Container(
      key: const Key('provider-share-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AarastV3Color.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 230,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover.isNotEmpty)
                  Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                const PositionedDirectional(
                  top: 16,
                  start: 18,
                  child: JourneyWordmark(
                    size: 20,
                    color: AarastV3Color.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: JourneyType.of(
                    JourneyType.hero,
                    weight: JourneyType.bold,
                    color: AarastV3Color.onPrimary,
                  ),
                ),
                if (kind.isNotEmpty)
                  Text(
                    kind,
                    style: JourneyType.of(
                      JourneyType.bodySmall,
                      color: AarastV3Color.onPrimaryMuted,
                    ),
                  ),
                if (profile.ratingCount > 0 || profile.verifiedAt != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (profile.ratingCount > 0)
                        JourneyTag(
                          label:
                              '★ ${providerRatingLabel(profile.ratingAverage, profile.ratingCount)}',
                          color: AarastV3Color.primaryDark,
                          soft: AarastV3Color.saffron,
                        ),
                      if (profile.verifiedAt != null)
                        const JourneyTag(
                          key: Key('provider-share-verified'),
                          label: 'موثّق في اعّرست',
                          color: AarastV3Color.primaryDark,
                          soft: AarastV3Color.paper,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AarastV3Color.paper,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const JourneyIconTile(
                        icon: LucideIcons.search,
                        color: AarastV3Color.primary,
                        soft: AarastV3Color.primarySoft,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اطلب عرضك من اعّرست',
                              style: JourneyType.of(
                                JourneyType.body,
                                weight: JourneyType.bold,
                              ),
                            ),
                            Text(
                              'ابحث باسم «$name»',
                              style: JourneyType.of(
                                JourneyType.label,
                                color: AarastV3Color.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
