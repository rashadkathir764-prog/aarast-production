import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingStorage, GuestPersona;

/// D112 (Q-13), the owner's word: the other side's plan kept on this phone
/// is a quiet strip, not a sheet at every open. It says whose plan is on
/// the phone and that they save it by their own number; «غيّر» brings the
/// question back (keep it, or delete it from the phone).
///
/// Nothing when the open account left no plan on the phone for its owner.
class PhonePlanKeptStrip extends StatelessWidget {
  const PhonePlanKeptStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final GuestOnboardingStorage storage;
    try {
      storage = context.read<GuestOnboardingStorage>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final accountUserId = context.watch<AuthController?>()?.user?.id;
    return ValueListenableBuilder<int>(
      valueListenable: storage.keptForOwner,
      builder: (context, _, _) {
        final kept = storage.keptForOwnerBy(accountUserId);
        if (kept == null) return const SizedBox.shrink();
        final bride = kept.ownerPersona == GuestPersona.bride;
        final words = bride
            ? 'على هذا الجوال خطة العروسة. تحفظها هي برقمها.'
            : 'على هذا الجوال خطة العريس. يحفظها هو برقمه.';
        return Padding(
          key: const ValueKey('phone-plan-kept-strip'),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AarastV3Space.x4,
            AarastV3Space.x2,
            AarastV3Space.x4,
            0,
          ),
          child: JourneyBox(
            color: AarastV3Color.primarySoft,
            padding: const EdgeInsetsDirectional.fromSTEB(
              AarastV3Space.x3,
              AarastV3Space.x1,
              AarastV3Space.x1,
              AarastV3Space.x1,
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.smartphone,
                  size: AarastV3Icon.sm,
                  color: AarastV3Color.primary,
                ),
                const SizedBox(width: AarastV3Space.x2),
                Expanded(
                  child: Text(
                    words,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.ink,
                    ),
                  ),
                ),
                JourneyTextAction(
                  key: const ValueKey('phone-plan-kept-change'),
                  label: context.say('غيّر', 'غيّري'),
                  color: AarastV3Color.primary,
                  onPressed: storage.askAgainAboutKeptPlan,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
