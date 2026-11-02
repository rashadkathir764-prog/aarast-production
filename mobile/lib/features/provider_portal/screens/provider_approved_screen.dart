import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show ProviderDashboardProfile;
import '../widgets/provider_join_parts.dart';

/// The first steps p10 offers, each opening its place.
enum ProviderFirstStep { calendar, services, notifications }

/// p10 «مبروك، صرت في اعّرست»: shown once, when a profile this phone waited
/// for is approved or a listing was claimed here.
///
/// «وثّق ملفك» is replaced by «أضف خدماتك وأسعارك», since there is no
/// verification request yet, and no line promises more requests or more
/// visibility: the directory order does not depend on them (F17).
class ProviderApprovedScreen extends StatelessWidget {
  const ProviderApprovedScreen({
    required this.profile,
    required this.onStart,
    required this.onStep,
    super.key,
  });

  final ProviderDashboardProfile profile;
  final VoidCallback onStart;
  final ValueChanged<ProviderFirstStep> onStep;

  @override
  Widget build(BuildContext context) {
    final city = profile.city?.nameAr.trim() ?? '';
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              children: [
                ProviderStateHeading(
                  name: profile.businessName,
                  kind: providerKindLine(
                    category: profile.primaryCategory?.nameAr,
                    city: city,
                  ),
                  icon: LucideIcons.partyPopper,
                  color: AarastV3Color.mint,
                  soft: AarastV3Color.mintSoft,
                  title: 'مبروك، صرت في اعّرست',
                  message: city.isEmpty
                      ? 'العرسان يشوفونك من الآن.'
                      : 'العرسان في $city يشوفونك من الآن.',
                ),
                const JourneySectionTitle('ثلاث خطوات أولى'),
                JourneyList(
                  children: [
                    JourneyListRow(
                      key: const Key('provider-first-step-calendar'),
                      icon: LucideIcons.calendarDays,
                      color: AarastV3Color.primary,
                      soft: AarastV3Color.primarySoft,
                      title: 'حدّث تقويمك',
                      subtitle:
                          'الليالي المحجوزة من برا، عشان ما ينحجز يوم مرتين',
                      onTap: () => onStep(ProviderFirstStep.calendar),
                    ),
                    JourneyListRow(
                      key: const Key('provider-first-step-services'),
                      icon: LucideIcons.package,
                      color: AarastV3Color.primary,
                      soft: AarastV3Color.primarySoft,
                      title: 'أضف خدماتك وأسعارك',
                      subtitle: 'تظهر في ملفك للعرسان',
                      onTap: () => onStep(ProviderFirstStep.services),
                    ),
                    JourneyListRow(
                      key: const Key('provider-first-step-notifications'),
                      icon: LucideIcons.bell,
                      color: AarastV3Color.primary,
                      soft: AarastV3Color.primarySoft,
                      title: 'شغّل التنبيهات',
                      subtitle: 'تختار وش يوصلك من التنبيهات',
                      onTap: () => onStep(ProviderFirstStep.notifications),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const Key('provider-approved-start'),
              label: 'ابدأ',
              expand: true,
              large: true,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }
}
