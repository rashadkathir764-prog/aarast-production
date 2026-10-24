import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show ProviderDashboardProfile;
import '../widgets/provider_join_parts.dart';

/// p09 «يحتاج تعديل بسيط»: the review team asked for changes.
///
/// The server keeps one free-text note (`reviewNote`), not a note per field,
/// and has no way for the provider to send the profile back to review (F3,
/// B-01). So the note shows once, above the fields he can edit, and the
/// main action is support, which tells the team he is done. Nothing says
/// «أرسلت التعديل» or «نراجعه أول بأول». The drawn photo and package fields
/// need approval first (F2, B-10), so only the profile's own fields show.
class ProviderChangesScreen extends StatelessWidget {
  const ProviderChangesScreen({
    required this.profile,
    required this.onRefresh,
    required this.onEdit,
    required this.onSupport,
    required this.onAccount,
    super.key,
  });

  final ProviderDashboardProfile profile;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onSupport;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final note = profile.reviewNote?.trim() ?? '';
    final city = profile.city?.nameAr.trim() ?? '';
    final about = profile.description?.trim() ?? '';
    final notedAt = profile.reviewedAt;
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'يحتاج تعديل بسيط',
                              style: JourneyType.of(
                                JourneyType.pageTitle,
                                weight: JourneyType.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ProviderAccountButton(onPressed: onAccount),
                      ],
                    ),
                  ),
                  JourneyNote(
                    icon: LucideIcons.clipboardCheck,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                    text: note.isEmpty
                        ? 'ملفك قريب. صلّح بياناته، وبعدها كلّم الدعم يراجعونه.'
                        : 'ملفك قريب. صلّح الملاحظة تحت، وبعدها كلّم الدعم يراجعونه.',
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    JourneyNote(
                      key: const Key('provider-changes-note'),
                      icon: LucideIcons.messageSquare,
                      color: AarastV3Color.danger,
                      soft: AarastV3Color.dangerSoft,
                      text: note,
                    ),
                  ],
                  const SizedBox(height: 14),
                  JourneyPickerField(
                    key: const Key('provider-changes-name'),
                    label: 'اسم النشاط',
                    value: profile.businessName.trim(),
                    onTap: onEdit,
                  ),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    JourneyPickerField(
                      key: const Key('provider-changes-city'),
                      label: 'المدينة',
                      value: city,
                      onTap: onEdit,
                    ),
                  ],
                  if (about.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    JourneyPickerField(
                      key: const Key('provider-changes-about'),
                      label: 'نبذة النشاط',
                      value: about,
                      onTap: onEdit,
                    ),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      notedAt == null
                          ? 'الملاحظة من فريق المراجعة'
                          : 'الملاحظة من فريق المراجعة · ${providerDayLabel(notedAt)}',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: JourneyButton(
              key: const Key('provider-changes-support'),
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
