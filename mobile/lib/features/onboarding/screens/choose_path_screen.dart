import 'package:flutter/material.dart';

import '../models/guest_onboarding_draft.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class ChoosePathScreen extends StatelessWidget {
  const ChoosePathScreen({
    this.selectedPath,
    this.onSelectPath,
    this.onContinue,
    this.onBack,
    super.key,
  });

  final GuestOnboardingPath? selectedPath;
  final ValueChanged<GuestOnboardingPath>? onSelectPath;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingStepScaffold(
      stepNumber: 1,
      title: 'كيف تريد استخدام أعرست؟',
      description:
          'اختر المسار المناسب حتى تبقى تجربة التخطيط منفصلة عن مسار المزودين.',
      continueLabel: 'متابعة',
      onContinue: selectedPath == null ? null : onContinue,
      onBack: onBack,
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            key: const Key('guest-path-wedding-user'),
            title: 'أرتب زفافي',
            subtitle: 'مسار تخطيط الزفاف والميزانية والمهام والضيوف.',
            icon: Icons.favorite_rounded,
            selected: selectedPath == GuestOnboardingPath.weddingUser,
            onTap: () => onSelectPath?.call(GuestOnboardingPath.weddingUser),
          ),
          const SizedBox(height: 12),
          GuestOnboardingOptionTile(
            key: const Key('guest-path-provider'),
            title: 'أنا مزود خدمة',
            subtitle:
                'مسار منفصل لتجهيز ملف خدمتك ومتابعة طلبات العروض لاحقًا.',
            icon: Icons.storefront_rounded,
            selected: selectedPath == GuestOnboardingPath.provider,
            onTap: () => onSelectPath?.call(GuestOnboardingPath.provider),
          ),
        ],
      ),
    );
  }
}
