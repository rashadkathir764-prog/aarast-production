import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../models/provider_board.dart';

/// f01 «خدمات عرسك»: every service of the wedding and how far it got, with
/// the one next step on each row.
class ProviderBoardView extends StatelessWidget {
  const ProviderBoardView({
    required this.rows,
    required this.onOpen,
    required this.onSearch,
    super.key,
  });

  final List<ProviderBoardRow> rows;
  final ValueChanged<ProviderBoardRow> onOpen;
  final ValueChanged<ProviderBoardRow> onSearch;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return JourneyBox(
        key: const ValueKey('provider-board-empty'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ما في خدمات في خطتك بعد',
              style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
            ),
            const SizedBox(height: 4),
            Text(
              context.say(
                'أضف بنود عرسك في المال (القاعة، الضيافة، التصوير…) وتظهر هنا، أو دوّر في «استكشف».',
                'أضيفي بنود عرسك في المال (الصالة، الضيافة، التصوير…) وتظهر هنا، أو دوّري في «استكشف».',
              ),
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'خدمات عرسك',
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'طلب · عرض · طلب حجز · محجوز',
                  textAlign: TextAlign.end,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              for (final row in rows)
                _BoardRow(
                  key: ValueKey('provider-board-${row.key}'),
                  row: row,
                  onOpen: () => onOpen(row),
                  onSearch: () => onSearch(row),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData providerServiceIcon(String name) =>
    switch (providerServiceGroupOf(name)) {
      0 => LucideIcons.building2,
      1 => LucideIcons.utensils,
      2 => LucideIcons.camera,
      3 => LucideIcons.flower2,
      4 => LucideIcons.music,
      5 => LucideIcons.shirt,
      6 => LucideIcons.scissors,
      7 => LucideIcons.leaf,
      _ => LucideIcons.store,
    };

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.row,
    required this.onOpen,
    required this.onSearch,
    super.key,
  });

  final ProviderBoardRow row;
  final VoidCallback onOpen;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (row.booked) {
      trailing = const JourneyTag(
        label: 'محجوز',
        color: AarastV3Color.mint,
        soft: AarastV3Color.mintSoft,
      );
    } else if (row.stage == 0) {
      trailing = _SoftAction(
        label: context.say('ابحث', 'ابحثي'),
        onTap: onSearch,
      );
    } else if (row.waitingOffers >= 2) {
      trailing = _SoftAction(
        label: context.say('قارن', 'قارني'),
        onTap: onOpen,
      );
    } else if (row.waitingOffers == 1) {
      trailing = _SoftAction(
        label: context.say('شوف العرض', 'شوفي العرض'),
        onTap: onOpen,
      );
    } else {
      trailing = const Icon(
        LucideIcons.chevronLeft,
        size: 18,
        color: AarastV3Color.textFaint,
      );
    }
    return InkWell(
      onTap: row.stage == 0 ? onSearch : onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            JourneyIconTile(
              icon: providerServiceIcon(row.title),
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    row.detail,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StageBar(stage: row.stage),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Like JourneyListRow: the action never squeezes the name out.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.4,
              ),
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}

/// Four short bars: طلب · عرض · طلب حجز · محجوز.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    const labels = ['ما بدأت', 'طلب', 'عرض', 'طلب حجز', 'محجوز'];
    return Semantics(
      label: labels[stage],
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++) ...[
            Flexible(
              child: Container(
                width: 18,
                height: 5,
                decoration: BoxDecoration(
                  color: i < stage
                      ? (stage == 4 ? AarastV3Color.mint : AarastV3Color.cobalt)
                      : AarastV3Color.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AarastV3Color.cobaltSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: JourneyType.of(
              JourneyType.body,
              weight: JourneyType.bold,
              color: AarastV3Color.cobalt,
            ),
          ),
        ),
      ),
    );
  }
}
