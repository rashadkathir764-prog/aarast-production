import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _joinArtHeight = 120.0;

/// A sheet of options (the joining's category and city, p09's category):
/// the picked id, or null when closed. Each option is keyed
/// `$keyPrefix-<id>`.
Future<String?> providerPickOption(
  BuildContext context, {
  required String title,
  required String keyPrefix,
  required List<(String, String)> options,
  required String? current,
}) {
  if (options.isEmpty) return Future.value();
  return showJourneySheet<String>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      title: title,
      children: [
        for (final (id, name) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
            child: JourneyOption(
              key: ValueKey('$keyPrefix-$id'),
              title: name,
              selected: id == current,
              onTap: () => Navigator.of(sheetContext).pop(id),
            ),
          ),
      ],
    ),
  );
}

/// «تصوير · صنعاء»: the provider's kind line, from what the server holds.
/// Parts the server does not have (teams, audience, travel) are never
/// added.
String providerKindLine({String? category, String? city}) => [
  category?.trim() ?? '',
  city?.trim() ?? '',
].where((part) => part.isNotEmpty).join(' · ');

/// The provider's identity (prototype `pBiz`): a 46-point teal square with
/// the business's first letter (or his logo once he added one), the name,
/// and the kind line under it.
class ProviderIdentityRow extends StatelessWidget {
  const ProviderIdentityRow({
    required this.name,
    this.kind = '',
    this.trailing,
    this.logoUrl,
    super.key,
  });

  final String name;
  final String kind;
  final Widget? trailing;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '' : trimmed.characters.first;
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AarastV3Color.primary,
              borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            ),
            child: logoUrl?.trim().isNotEmpty == true
                ? Image.network(
                    logoUrl!,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _letter(letter),
                  )
                : _letter(letter),
          ),
        ),
        const SizedBox(width: AarastV3Space.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trimmed,
                style: JourneyType.of(
                  JourneyType.lead,
                  weight: JourneyType.bold,
                ),
              ),
              if (kind.isNotEmpty)
                Text(
                  kind,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: AarastV3Space.x2),
          trailing,
        ],
      ],
    );
  }

  static Widget _letter(String letter) => Text(
    letter,
    textScaler: TextScaler.noScaling,
    style: JourneyType.of(
      JourneyType.pageTitle,
      weight: JourneyType.bold,
      color: AarastV3Color.onPrimary,
    ),
  );
}

/// One fact with its icon (prototype `eff`): what is true now, one line
/// each.
class ProviderFactRow extends StatelessWidget {
  const ProviderFactRow({
    required this.icon,
    required this.text,
    this.color = AarastV3Color.textMuted,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(JourneyType.body, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// «كذا بيشوفك العرسان» (p07, and p08's preview): the cover and the
/// identity, built on the phone from what was entered, and the price of the
/// service he joins with as p07's green tag (B-10). No photo is drawn until
/// the server has one.
class ProviderPreviewCard extends StatelessWidget {
  const ProviderPreviewCard({
    required this.name,
    required this.kind,
    this.priceTag,
    super.key,
  });

  final String name;
  final String kind;

  /// «من 150,000 ر.ي»: the joining service's price.
  final String? priceTag;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AarastV3Radius.card),
      child: ColoredBox(
        color: AarastV3Color.paper,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              height: _joinArtHeight,
              child: ColoredBox(
                color: AarastV3Color.textFaint,
                child: Icon(
                  LucideIcons.image,
                  size: 36,
                  color: AarastV3Color.line,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AarastV3Space.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProviderIdentityRow(name: name, kind: kind),
                  if (priceTag case final price?) ...[
                    const SizedBox(height: AarastV3Space.x2),
                    JourneyTag(
                      key: const Key('provider-preview-price'),
                      label: price,
                      color: AarastV3Color.mint,
                      soft: AarastV3Color.mintSoft,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The body of a review state (p08, p10, p12): the identity on top, the
/// state's icon, its title and the line under it, centred as drawn.
class ProviderStateHeading extends StatelessWidget {
  const ProviderStateHeading({
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.message,
    this.trailing,
    super.key,
  });

  final String name;
  final String kind;
  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AarastV3Space.x2),
        ProviderIdentityRow(name: name, kind: kind, trailing: trailing),
        const SizedBox(height: AarastV3Space.x4),
        Center(
          child: JourneyIconTile(
            icon: icon,
            color: color,
            soft: soft,
            size: 64,
            radius: 24,
          ),
        ),
        const SizedBox(height: AarastV3Space.x3),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.display,
              weight: JourneyType.bold,
            ),
          ),
        ),
        const SizedBox(height: AarastV3Space.x1),
        Text(
          message,
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AarastV3Space.x4),
      ],
    );
  }
}

/// The round «حسابي» button beside the identity of a state with no tabs, so
/// the account (log out, the wedding plans) stays one tap away.
class ProviderAccountButton extends StatelessWidget {
  const ProviderAccountButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return JourneyRoundButton(
      key: const Key('provider-state-account'),
      icon: LucideIcons.user,
      tooltip: 'حسابي',
      onPressed: onPressed,
    );
  }
}

/// «أرسلته اليوم 10 الصبح»: a day, then the hour and its part of the day.
String providerMomentLabel(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  final dayLabel = switch (days) {
    0 => 'اليوم',
    1 => 'أمس',
    _ => formatArabicDayMonth(local),
  };
  final hour = local.hour;
  final part = switch (hour) {
    < 4 => 'الليل',
    < 12 => 'الصبح',
    < 15 => 'الظهر',
    < 18 => 'العصر',
    _ => 'المسا',
  };
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  final minute = local.minute == 0
      ? ''
      : ':${local.minute.toString().padLeft(2, '0')}';
  return '$dayLabel $twelve$minute $part';
}

/// «من أمس»: the day a state began, without the hour.
String providerDayLabel(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final days = today
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  return switch (days) {
    0 => 'اليوم',
    1 => 'أمس',
    _ => formatArabicDayMonth(local),
  };
}
