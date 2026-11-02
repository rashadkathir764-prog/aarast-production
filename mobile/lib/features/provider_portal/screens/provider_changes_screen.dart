import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceService, ProviderDashboardProfile;
import '../widgets/provider_join_parts.dart';
import '../widgets/provider_request_parts.dart' show providerMoneyLabel;

/// p09 «يحتاج تعديل بسيط»: the review team asked for changes (B-01).
///
/// Each note sits under the field it is about, with the coral border the
/// design draws; a note about the whole profile (and a reopened refusal's
/// reason, B-02) shows above the fields. The fields are the ones he can fix
/// before approval: the name, the category, the city, the bio and the
/// service he joined with (B-10). The drawn photo and package fields wait
/// for approval (D41). «أرسلت التعديل» sends the profile back to review. The
/// back arrow stays «حسابي» (D42): this state has nowhere to go back to.
class ProviderChangesScreen extends StatelessWidget {
  const ProviderChangesScreen({
    required this.profile,
    required this.service,
    required this.submitting,
    required this.onRefresh,
    required this.onEdit,
    required this.onPickCategory,
    required this.onEditService,
    required this.onResubmit,
    required this.onAccount,
    this.errorMessage,
    super.key,
  });

  final ProviderDashboardProfile profile;

  /// The service he joined with; null when the profile has none yet.
  final MarketplaceService? service;
  final bool submitting;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onPickCategory;
  final VoidCallback onEditService;
  final VoidCallback onResubmit;
  final VoidCallback onAccount;

  /// «ملفك قريب. باقي تعديل الملاحظتين تحت، ونراجعه أول بأول.» No gender is
  /// kept for a provider, so this asks without addressing one.
  static String leadLine(int fieldNotes, {required bool general}) {
    final what = switch (fieldNotes) {
      0 when general => 'تعديل اللي في الملاحظة',
      0 => 'تعديل بياناته',
      1 => 'تعديل الملاحظة تحت',
      2 => 'تعديل الملاحظتين تحت',
      _ => 'تعديل الملاحظات تحت',
    };
    return 'ملفك قريب. باقي $what، ونراجعه أول بأول.';
  }

  @override
  Widget build(BuildContext context) {
    final note = profile.reviewNote?.trim() ?? '';
    final notes = profile.fieldNotes;
    final city = profile.city?.nameAr.trim() ?? '';
    final category = profile.primaryCategory?.nameAr.trim() ?? '';
    final about = profile.description?.trim() ?? '';
    final service = this.service;
    final notedAt = profile.reviewedAt;
    final error = errorMessage;
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
                    text: leadLine(notes.length, general: note.isNotEmpty),
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
                    note: notes['BUSINESS_NAME'],
                    onTap: onEdit,
                  ),
                  const SizedBox(height: 10),
                  JourneyPickerField(
                    key: const Key('provider-changes-category'),
                    label: 'القسم',
                    value: category,
                    note: notes['CATEGORY'],
                    onTap: onPickCategory,
                  ),
                  const SizedBox(height: 10),
                  JourneyPickerField(
                    key: const Key('provider-changes-city'),
                    label: 'المدينة',
                    value: city,
                    note: notes['CITY'],
                    onTap: onEdit,
                  ),
                  if (about.isNotEmpty || notes['DESCRIPTION'] != null) ...[
                    const SizedBox(height: 10),
                    JourneyPickerField(
                      key: const Key('provider-changes-about'),
                      label: 'نبذة النشاط',
                      value: about,
                      placeholder: 'اكتب نبذة عن نشاطك',
                      note: notes['DESCRIPTION'],
                      onTap: onEdit,
                    ),
                  ],
                  const SizedBox(height: 10),
                  JourneyPickerField(
                    key: const Key('provider-changes-service'),
                    label: service == null
                        ? 'خدمتك وسعرها'
                        : 'خدمة «${service.title.trim()}»',
                    value: service == null
                        ? null
                        : providerMoneyLabel(service.basePrice, service.currency),
                    placeholder: 'أضف خدمة بسعرها',
                    helper: service?.description?.trim().isNotEmpty == true
                        ? service!.description!.trim()
                        : null,
                    note: notes['SERVICE'],
                    onTap: onEditService,
                  ),
                  if (note.isNotEmpty || notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      notedAt == null
                          ? 'الملاحظات من فريق المراجعة'
                          : 'الملاحظات من فريق المراجعة · ${providerDayLabel(notedAt)}',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    JourneyNote(
                      key: const Key('provider-changes-error'),
                      text: error,
                      icon: LucideIcons.alertCircle,
                      color: AarastV3Color.danger,
                      soft: AarastV3Color.dangerSoft,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: JourneyButton(
              key: const Key('provider-changes-resubmit'),
              label: 'أرسلت التعديل',
              icon: LucideIcons.send,
              expand: true,
              large: true,
              loading: submitting,
              onPressed: onResubmit,
            ),
          ),
        ],
      ),
    );
  }
}
