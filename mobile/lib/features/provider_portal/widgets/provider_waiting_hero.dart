import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';

/// Rashad 2026-11-17: the provider's path wears the plan's hero, the
/// home's own look and size (JourneyPlanHero). The new requests waiting for
/// his answer are the big figure; one and two are said in their word, as
/// the home says «يومين على عرسك». Said for a provider of any gender
/// (critique ب3). The home and the requests tab give their own [subtitle]
/// and [tag].
class ProviderWaitingHero extends StatelessWidget {
  const ProviderWaitingHero({
    required this.waiting,
    this.subtitle,
    this.tag,
    super.key,
  });

  /// The new requests (SENT and VIEWED), as [providerWaitingCount].
  final int waiting;
  final String? subtitle;
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    final title = providerWaitingWords(waiting);
    return JourneyPlanHero(
      figure: waiting > 2 ? '$waiting' : null,
      figureKey: const ValueKey('provider-waiting-figure'),
      title: title,
      subtitle: subtitle,
      tag: tag,
      semanticLabel: [
        if (waiting > 2) '$waiting $title' else title,
        ?subtitle,
      ].join('، '),
    );
  }
}

/// The hero's words beside the figure: «ما فيه طلب ينتظر ردك», «طلب ينتظر
/// ردك», «طلبين ينتظرون ردك», «طلبات تنتظر ردك» after 3 to 10, «طلب ينتظر
/// ردك» after 11 and on.
String providerWaitingWords(int waiting) => switch (waiting) {
  0 => 'ما فيه طلب ينتظر ردك',
  1 => 'طلب ينتظر ردك',
  2 => 'طلبين ينتظرون ردك',
  _ => arabicCountWord(
    waiting,
    one: 'طلب ينتظر ردك',
    two: 'طلبين ينتظرون ردك',
    few: 'طلبات تنتظر ردك',
    many: 'طلب ينتظر ردك',
  ),
};
