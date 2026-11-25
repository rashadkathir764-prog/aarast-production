import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceService, ProviderDashboardProfile;
import '../data/provider_changes_ledger.dart';
import '../widgets/provider_join_parts.dart';
import '../widgets/provider_request_parts.dart' show providerMoneyLabel;

/// p09 «يحتاج تعديل بسيط»: the review team asked for changes (B-01).
///
/// Each note sits under the field it is about, with the coral border the
/// design draws; a note about the whole profile (and a reopened refusal's
/// reason, B-02) shows above the fields. The fields are the ones he can fix
/// before approval: the name, the category, the city, the bio and the
/// service he joined with (B-10). The drawn photo and package fields wait
/// for approval (D41). «أرسل للمراجعة» sends the profile back to review;
/// a noted field he changed says «عدّلته», and sending with one he did not
/// change asks first. The back arrow stays «حسابي» (D42): this state has
/// nowhere to go back to. No gender is kept for a provider (D70), so the
/// words address no one.
class ProviderChangesScreen extends StatefulWidget {
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

  /// «ما عدّلت اسم النشاط والخدمة. نرسل الملف كذا؟»
  static String unchangedQuestion(List<String> fields) {
    final named = switch (fields.length) {
      0 => '',
      1 => fields.single,
      _ => '${fields.sublist(0, fields.length - 1).join('، ')} و${fields.last}',
    };
    return 'ما عدّلت $named. نرسل الملف كذا؟';
  }

  @override
  State<ProviderChangesScreen> createState() => _ProviderChangesScreenState();
}

/// The fields a note can be about, in the screen's order, with their names.
const _noteFields = [
  ('BUSINESS_NAME', 'اسم النشاط'),
  ('CATEGORY', 'القسم'),
  ('CITY', 'المدينة'),
  ('DESCRIPTION', 'نبذة النشاط'),
  ('SERVICE', 'الخدمة'),
];

class _ProviderChangesScreenState extends State<ProviderChangesScreen> {
  /// What the noted fields held when this phone first read the notes;
  /// null until read.
  Map<String, String>? _start;
  String? _startDecision;

  /// Each field as it stands now, compared with [_start].
  Map<String, String> _current() {
    final profile = widget.profile;
    final service = widget.service;
    return {
      'BUSINESS_NAME': profile.businessName.trim(),
      'CATEGORY': profile.primaryCategoryId ?? '',
      'CITY': profile.cityId ?? '',
      'DESCRIPTION': profile.description?.trim() ?? '',
      'SERVICE': service == null
          ? ''
          : [
              service.id,
              service.title.trim(),
              service.basePrice ?? '',
              service.description?.trim() ?? '',
            ].join('|'),
    };
  }

  String get _decision =>
      widget.profile.latestDecisionId ??
      widget.profile.reviewedAt?.toIso8601String() ??
      'none';

  @override
  void initState() {
    super.initState();
    _readStart();
  }

  @override
  void didUpdateWidget(covariant ProviderChangesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Notes rewritten meanwhile are read on the values he has now.
    if (_decision != _startDecision) _readStart();
  }

  void _readStart() {
    final decision = _decision;
    final providerId = widget.profile.id;
    final current = _current();
    _startDecision = decision;
    _start = null;
    unawaited(() async {
      Map<String, String> start;
      try {
        start = await ProviderChangesLedger(
          await SharedPreferences.getInstance(),
        ).startOf(providerId: providerId, decision: decision, current: current);
      } on Object catch (error) {
        // Not kept on the phone: this visit's values are the start.
        appDebugNote('Provider changes start not kept: $error');
        start = current;
      }
      if (!mounted || decision != _startDecision) return;
      setState(() => _start = start);
    }());
  }

  /// Whether the noted [field] differs from what it held under the notes.
  bool _fixed(String field, Map<String, String> current) {
    final start = _start;
    return start != null && start[field] != current[field];
  }

  Future<void> _send() async {
    final notes = widget.profile.fieldNotes;
    final current = _current();
    final unchanged = [
      for (final (field, name) in _noteFields)
        if (notes[field] != null && _start != null && !_fixed(field, current))
          name,
    ];
    if (unchanged.isNotEmpty) {
      final send = await showJourneySheet<bool>(
        context: context,
        builder: (sheetContext) => JourneySheetBody(
          title: ProviderChangesScreen.unchangedQuestion(unchanged),
          subtitle: 'فريق المراجعة طلب تعديلها قبل ما نوافق.',
          children: [
            JourneyButton(
              key: const Key('provider-changes-send-anyway'),
              label: 'أرسل كذا',
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: AarastV3Space.x2),
            JourneyButton(
              key: const Key('provider-changes-keep-editing'),
              label: 'أعدّل أول',
              background: AarastV3Color.paper,
              foreground: AarastV3Color.ink,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      );
      if (send != true || !mounted) return;
    }
    widget.onResubmit();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final note = profile.reviewNote?.trim() ?? '';
    final notes = profile.fieldNotes;
    final city = profile.city?.nameAr.trim() ?? '';
    final category = profile.primaryCategory?.nameAr.trim() ?? '';
    final about = profile.description?.trim() ?? '';
    final service = widget.service;
    final notedAt = profile.reviewedAt;
    final error = widget.errorMessage;
    final current = _current();

    // A noted field, and «عدّلته» under it once its value changed.
    List<Widget> field(String key, Widget box) => [
      box,
      if (notes[key] != null && _fixed(key, current))
        _FixedLine(key: Key('provider-changes-fixed-$key')),
    ];

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AarastV3Color.primary,
              onRefresh: widget.onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AarastV3Density.pageInsets,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AarastV3Space.half,
                      AarastV3Space.x1,
                      AarastV3Space.half,
                      AarastV3Space.x3,
                    ),
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
                        const SizedBox(width: AarastV3Space.x3),
                        ProviderAccountButton(onPressed: widget.onAccount),
                      ],
                    ),
                  ),
                  JourneyNote(
                    icon: LucideIcons.clipboardCheck,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                    text: ProviderChangesScreen.leadLine(
                      notes.length,
                      general: note.isNotEmpty,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    JourneyNote(
                      key: const Key('provider-changes-note'),
                      icon: LucideIcons.messageSquare,
                      color: AarastV3Color.danger,
                      soft: AarastV3Color.dangerSoft,
                      text: note,
                    ),
                  ],
                  const SizedBox(height: AarastV3Space.x3),
                  ...field(
                    'BUSINESS_NAME',
                    JourneyPickerField(
                      key: const Key('provider-changes-name'),
                      label: 'اسم النشاط',
                      value: profile.businessName.trim(),
                      note: notes['BUSINESS_NAME'],
                      onTap: widget.onEdit,
                    ),
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  ...field(
                    'CATEGORY',
                    JourneyPickerField(
                      key: const Key('provider-changes-category'),
                      label: 'القسم',
                      value: category,
                      note: notes['CATEGORY'],
                      onTap: widget.onPickCategory,
                    ),
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  ...field(
                    'CITY',
                    JourneyPickerField(
                      key: const Key('provider-changes-city'),
                      label: 'المدينة',
                      value: city,
                      note: notes['CITY'],
                      onTap: widget.onEdit,
                    ),
                  ),
                  if (about.isNotEmpty || notes['DESCRIPTION'] != null) ...[
                    const SizedBox(height: AarastV3Space.x2),
                    ...field(
                      'DESCRIPTION',
                      JourneyPickerField(
                        key: const Key('provider-changes-about'),
                        label: 'نبذة النشاط',
                        value: about,
                        placeholder: 'اكتب نبذة عن نشاطك',
                        note: notes['DESCRIPTION'],
                        onTap: widget.onEdit,
                      ),
                    ),
                  ],
                  const SizedBox(height: AarastV3Space.x2),
                  ...field(
                    'SERVICE',
                    JourneyPickerField(
                      key: const Key('provider-changes-service'),
                      label: service == null
                          ? 'خدمتك وسعرها'
                          : 'خدمة «${service.title.trim()}»',
                      value: service == null
                          ? null
                          : providerMoneyLabel(
                              service.basePrice,
                              service.currency,
                            ),
                      placeholder: 'خدمة بسعرها',
                      helper: service?.description?.trim().isNotEmpty == true
                          ? service!.description!.trim()
                          : null,
                      note: notes['SERVICE'],
                      onTap: widget.onEditService,
                    ),
                  ),
                  if (note.isNotEmpty || notes.isNotEmpty) ...[
                    const SizedBox(height: AarastV3Space.x2),
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
                    const SizedBox(height: AarastV3Space.x3),
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
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const Key('provider-changes-resubmit'),
              label: 'أرسل للمراجعة',
              icon: LucideIcons.send,
              expand: true,
              large: true,
              loading: widget.submitting,
              onPressed: _send,
            ),
          ),
        ],
      ),
    );
  }
}

/// «عدّلته» under a noted field whose value changed since the notes.
class _FixedLine extends StatelessWidget {
  const _FixedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AarastV3Space.x1,
        right: AarastV3Space.x1,
        left: AarastV3Space.x1,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.checkCircle2,
            size: AarastV3Icon.sm,
            color: AarastV3Color.mint,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Text(
            'عدّلته',
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: AarastV3Color.mint,
            ),
          ),
        ],
      ),
    );
  }
}
