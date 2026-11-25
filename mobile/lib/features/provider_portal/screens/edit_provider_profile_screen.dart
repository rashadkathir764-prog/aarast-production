import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../marketplace/marketplace_api.dart'
    show ProviderDashboardProfile, ProviderMarketplaceProvider;
import '../data/provider_text_limits.dart';
import '../providers/provider_dashboard_provider.dart';

class EditProviderProfileScreen extends StatefulWidget {
  const EditProviderProfileScreen({super.key});

  @override
  State<EditProviderProfileScreen> createState() =>
      _EditProviderProfileScreenState();
}

class _EditProviderProfileScreenState extends State<EditProviderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _cityId;
  bool _didPopulate = false;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
      final hasAccount =
          !AppFeatureFlags.devBypassLoginGatesForUxExploration ||
          await AuthActionGuard.hasAccount(context);
      if (!mounted || !hasAccount) return;
      context.read<ProviderDashboardProvider>().loadDashboard();
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;

    if (profile != null && !_didPopulate) {
      _populate(profile);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _configureDraft(profile.id);
      });
    }

    // The other provider pages' frame: the canvas, the round back at the
    // title's start, the page's own gutter.
    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: profile == null
          ? null
          : AarastV3FormActionBar(
              label: 'حفظ التعديلات',
              icon: LucideIcons.save,
              loading: dashboard.isSubmitting,
              onPressed: dashboard.isSubmitting ? null : _submit,
            ),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: AarastV3Density.pageInsets.copyWith(
          bottom: MediaQuery.viewInsetsOf(context).bottom + AarastV3Space.x8,
        ),
        children: [
          JourneySubHeader(
            title: 'تعديل ملفك',
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRouter.providerDashboard);
              }
            },
          ),
          if (dashboard.isLoading && profile == null)
            AarastSkeleton.form(fields: 4, inline: true)
          else if (profile == null && dashboard.errorMessage != null)
            AarastErrorState(
              title: 'ما قدرنا نجيب ملف المزود',
              message: dashboard.errorMessage!,
              onRetry: dashboard.loadDashboard,
            )
          else if (profile == null)
            AarastEmptyState(
              icon: LucideIcons.store,
              title: 'ما في ملف مزود',
              message: 'تعديل بيانات المزود يصير بعد إرسال طلب الانضمام.',
              action: FilledButton.icon(
                onPressed: () => context.go(AppRouter.providerApply),
                icon: const Icon(LucideIcons.contact),
                label: const Text('طلب الانضمام كمزود'),
              ),
            )
          else ...[
            // RA-BE-152 (Q-39): which changes wait for the team, said before
            // he saves, not after.
            _ProfileEditNotice(profile: profile),
            const SizedBox(height: AarastV3Space.x3),
            // RA-MO-303: in the app's words, not formal.
            const AarastV3FocusPrompt(
              eyebrow: 'ملفك',
              question: 'ايش يشوف العرسان في ملفك؟',
              supportingText:
                  'الاسم والرقم والمدينة أول، والنبذة تقدر تضيفها بعدين.',
              icon: LucideIcons.store,
            ),
            if (_draft != null) ...[
              const SizedBox(height: AarastV3Space.x2),
              AarastV3DraftStatusLine(status: _draft!.status),
            ],
            const SizedBox(height: AarastV3Space.x2),
            Form(
              key: _formKey,
              child: AarastV3FormSurface(
                title: 'اللي يشوفه العرسان',
                children: [
                  JourneyTextField(
                    controller: _businessNameController,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(providerTitleMax),
                    ],
                    label: 'اسم النشاط',
                    icon: LucideIcons.badge,
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'اكتب اسم النشاط'
                        : null,
                  ),
                  if (profile.pendingChange?.businessName != null)
                    _UnderReviewLine(live: profile.businessName),
                  const SizedBox(height: AarastV3Field.gap),
                  ContactPhoneField(
                    phoneController: _phoneController,
                    label: 'رقم التواصل',
                    optional: false,
                    requireYemeni: true,
                  ),
                  const SizedBox(height: AarastV3Field.gap),
                  JourneyChoiceField<String>(
                    value: _safeCityId(marketplace),
                    label: 'المدينة',
                    icon: LucideIcons.mapPin,
                    choices: [
                      for (final city in marketplace.cities)
                        JourneyChoice(city.id, city.nameAr),
                    ],
                    onChanged: (value) {
                      setState(() => _cityId = value);
                      _draft?.changed();
                    },
                    validator: (value) => value == null ? 'اختر المدينة' : null,
                  ),
                  if (profile.pendingChange?.cityId != null)
                    _UnderReviewLine(live: profile.city?.nameAr),
                  const SizedBox(height: AarastV3Space.x2),
                  AarastDisclosureCard(
                    title: 'نبذة النشاط',
                    subtitle: _descriptionController.text.trim().isEmpty
                        ? 'تقدر تضيفها بعدين'
                        : 'افتحها وعدّلها',
                    icon: LucideIcons.fileText,
                    child: JourneyTextField(
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 280,
                      label: 'ايش يميز شغلك؟',
                      icon: LucideIcons.fileText,
                    ),
                  ),
                  if (profile.primaryCategory?.nameAr.trim().isNotEmpty ==
                      true) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    _LockedCategoryNote(
                      categoryName: profile.primaryCategory!.nameAr.trim(),
                    ),
                  ],
                  if (marketplace.cities.isEmpty) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    const _ReferenceDataWarning(),
                  ],
                  if (dashboard.errorMessage != null) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    _InlineError(message: dashboard.errorMessage!),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _populate(ProviderDashboardProfile profile) {
    // RA-BE-152: a name or city waiting for the team is what he asked for;
    // saving it again keeps it waiting, and the live one takes it back.
    final waiting = profile.pendingChange;
    _businessNameController.text =
        waiting?.businessName ?? profile.businessName;
    // Grouped as everywhere else («+967 773 210 455»); the save reads it
    // back to the same number.
    _phoneController.text =
        PhoneNumberUtils.analyze(profile.phone).displayPhone ??
        profile.phone ??
        '';
    _descriptionController.text = profile.description ?? '';
    _cityId = waiting?.cityId ?? profile.cityId;
    _didPopulate = true;
  }

  String? _safeCityId(ProviderMarketplaceProvider marketplace) {
    if (_cityId == null) return null;
    return marketplace.cities.any((city) => city.id == _cityId)
        ? _cityId
        : null;
  }

  void _configureDraft(String profileId) {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'provider:profile:$profileId',
      fields: {
        'businessName': _businessNameController,
        'phone': _phoneController,
        'description': _descriptionController,
      },
      readExtras: () => {'cityId': _cityId},
      restoreExtras: (data) {
        if (!mounted) return;
        setState(() => _cityId = data['cityId']?.toString());
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _cityId == null) {
      return;
    }
    if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(context)) {
      return;
    }
    if (!mounted) return;

    final ok = await context.read<ProviderDashboardProvider>().updateProfile(
      businessName: _businessNameController.text,
      phone: _phoneController.text,
      cityId: _cityId!,
      description: _descriptionController.text,
    );

    if (!mounted) return;
    if (ok) {
      await _draft?.clear();
      if (!mounted) return;
      final waits =
          context.read<ProviderDashboardProvider>().profile?.pendingChange !=
          null;
      AarastFormSuccess.show(
        context,
        message: waits
            ? 'انحفظ ملفك. اللي قيد المراجعة يظهر للعرسان بعد ما نوافق عليه.'
            : 'انحفظ ملفك.',
      );
      context.go(AppRouter.providerDashboard);
    }
  }
}

class _ProfileEditNotice extends StatelessWidget {
  const _ProfileEditNotice({required this.profile});

  final ProviderDashboardProfile profile;

  /// RA-BE-152 (Q-39): once approved, these wait for the team; the rest of
  /// the profile changes at once.
  static const reviewedLine =
      'الاسم والمدينة والشعار والغلاف تتغير للعرسان بعد موافقتنا. '
      'النبذة والرقم والأسعار تتغير على طول.';

  @override
  Widget build(BuildContext context) {
    final status = profile.status.toUpperCase();
    return JourneyNote(
      key: const Key('provider-profile-edit-notice'),
      icon: LucideIcons.info,
      tone: JourneyNoteTone.paper,
      text: status == 'ACTIVE'
          ? reviewedLine
          // Before approval the whole profile is under review; editing it
          // is not an approval.
          : 'حالة ملفك: ${_providerStatusLabel(profile.status)}. '
                'التعديل ما يعني إننا وافقنا.',
    );
  }
}

/// RA-BE-152 (Q-39 (أ)): under a field whose new value waits for the team,
/// what customers still read.
class _UnderReviewLine extends StatelessWidget {
  const _UnderReviewLine({required this.live});

  final String? live;

  @override
  Widget build(BuildContext context) {
    final shown = live?.trim();
    return Padding(
      padding: const EdgeInsets.only(top: AarastV3Space.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.hourglass,
            size: AarastV3Icon.sm,
            color: AppTheme.brand,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Expanded(
            child: Text(
              shown == null || shown.isEmpty
                  ? 'قيد المراجعة. يظهر للعرسان لما نوافق.'
                  : 'قيد المراجعة. العرسان يشوفون «$shown» لين نوافق.',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
                height: AarastV3Line.reading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCategoryNote extends StatelessWidget {
  const _LockedCategoryNote({required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return JourneyNote(
      icon: LucideIcons.lock,
      text: 'قسمك: $categoryName. تغيير القسم عن طريق الدعم، مش من هنا.',
    );
  }
}

class _ReferenceDataWarning extends StatelessWidget {
  const _ReferenceDataWarning();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.brandMuted,
      child: Text(
        'ما قدرنا نجيب المدن. مرة ثانية غالبًا تمشي.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.brandMuted,
      border: Border.all(color: AppTheme.danger.withAlpha(55)),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _providerStatusLabel(String status) {
  return switch (status) {
    'ACTIVE' => 'نشط',
    'PENDING' => 'قيد المراجعة',
    'NEEDS_CHANGES' => 'يحتاج تعديل',
    'REJECTED' => 'مرفوض',
    'SUSPENDED' => 'موقوف',
    _ => 'قيد المراجعة',
  };
}
