import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/forms/latin_digits_formatter.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show ProviderMarketplaceProvider;
import '../data/provider_text_limits.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_listing_sheet.dart' show providerListingPriceError;

class AddProviderServiceScreen extends StatefulWidget {
  const AddProviderServiceScreen({super.key});

  @override
  State<AddProviderServiceScreen> createState() =>
      _AddProviderServiceScreenState();
}

class _AddProviderServiceScreenState extends State<AddProviderServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _priceUnitController = TextEditingController(text: 'حسب الخدمة');
  String? _categoryId;
  String? _cityId;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
      context.read<ProviderDashboardProvider>().loadDashboard();
      _configureDraft();
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    _priceUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final canManageListing = _canManageProviderListing(
      dashboard.profile?.status,
    );

    // The other provider pages' frame: the canvas, the round back at the
    // title's start, the page's own gutter.
    final header = JourneySubHeader(
      title: 'إضافة خدمة',
      // Opened by a link there is no page behind it: back to «ملفي».
      onBack: () => context.popOrGo(AppRouter.providerProfileTab),
    );
    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: canManageListing
          ? AarastV3FormActionBar(
              label: 'إضافة الخدمة',
              icon: LucideIcons.plus,
              loading: dashboard.isSubmitting,
              onPressed: dashboard.isSubmitting ? null : _submit,
            )
          : null,
      child: !canManageListing
          ? ListView(
              padding: AarastV3Density.pageInsets,
              children: [
                header,
                if (dashboard.isLoading && dashboard.profile == null)
                  AarastSkeleton.form(fields: 4, inline: true)
                else
                  AarastEmptyState(
                    icon: LucideIcons.fileClock,
                    title: 'الخدمات تنضاف بعد الموافقة',
                    message:
                        'فريق اعّرست يراجع ملفك أول، وبعد ما نوافق تضيف خدماتك من هنا.',
                    action: FilledButton.icon(
                      onPressed: () => context.go(AppRouter.providerDashboard),
                      icon: const Icon(LucideIcons.layoutDashboard),
                      label: const Text('ارجع للرئيسية'),
                    ),
                  ),
              ],
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: AarastV3Density.pageInsets,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  header,
                  // In the portal's own voice and words («العرسان»,
                  // «القسم»), and what a service is (finding 11).
                  const AarastV3FocusPrompt(
                    eyebrow: 'الخدمة',
                    question: 'ايش الخدمة اللي يلقاها العرسان عندك؟',
                    supportingText:
                        'شغلك وسعره من كم، وبها يظهر ملفك في قسمه في الدليل.',
                    icon: LucideIcons.wand,
                  ),
                  if (_draft != null) ...[
                    const SizedBox(height: AarastV3Space.x2),
                    AarastV3DraftStatusLine(status: _draft!.status),
                  ],
                  const SizedBox(height: AarastV3Space.x2),
                  AarastV3FormSurface(
                    children: [
                      JourneyTextField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(providerTitleMax),
                        ],
                        label: 'اسم الخدمة',
                        icon: LucideIcons.wand,
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'اكتب اسم الخدمة'
                            : null,
                      ),
                      const SizedBox(height: AarastV3Field.gap),
                      JourneyChoiceField<String>(
                        value: _safeCategoryId(marketplace, dashboard),
                        // The portal's word for it everywhere («القسم»).
                        label: 'القسم',
                        icon: LucideIcons.shapes,
                        choices: [
                          for (final category in _sections(
                            marketplace,
                            dashboard,
                          ))
                            JourneyChoice(category.id, category.nameAr),
                        ],
                        onChanged: (value) {
                          setState(() => _categoryId = value);
                          _draft?.changed();
                        },
                        validator: (value) =>
                            value == null ? 'اختر القسم' : null,
                      ),
                      const SizedBox(height: AarastV3Field.gap),
                      JourneyTextField(
                        controller: _basePriceController,
                        // RA-MO-301: the price went to the server as
                        // typed, and a refusal named no field.
                        validator: (value) =>
                            providerListingPriceError(value ?? ''),
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        label: 'السعر من',
                        suffix: currencyLabelAr(defaultCurrencyCode),
                        // Why the currency is fixed.
                        helper: 'الأسعار بالريال اليمني',
                        icon: LucideIcons.wallet,
                      ),
                    ],
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  AarastDisclosureCard(
                    title: 'تفاصيل تساعد العرسان',
                    subtitle: 'المدينة وايش يشمل وملاحظة السعر',
                    icon: LucideIcons.fileText,
                    initiallyExpanded:
                        _cityId != null ||
                        _descriptionController.text.isNotEmpty,
                    child: Column(
                      children: [
                        JourneyChoiceField<String?>(
                          value: _safeCityId(marketplace),
                          label: 'مدينة الخدمة',
                          icon: LucideIcons.mapPin,
                          choices: [
                            const JourneyChoice(null, 'نفس مدينة ملفك'),
                            for (final city in marketplace.cities)
                              JourneyChoice(city.id, city.nameAr),
                          ],
                          onChanged: (value) {
                            setState(() => _cityId = value);
                            _draft?.changed();
                          },
                        ),
                        const SizedBox(height: AarastV3Field.gap),
                        JourneyTextField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 3,
                          maxLength: 280,
                          label: 'ايش يشمل',
                          icon: LucideIcons.fileText,
                        ),
                        const SizedBox(height: AarastV3Field.gap),
                        JourneyTextField(
                          controller: _priceUnitController,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              providerPriceUnitMax,
                            ),
                          ],
                          label: 'ملاحظة السعر أو المدة',
                          icon: LucideIcons.timer,
                        ),
                      ],
                    ),
                  ),
                  if (dashboard.errorMessage != null) ...[
                    const SizedBox(height: AarastV3Space.x2),
                    _InlineError(message: dashboard.errorMessage!),
                  ],
                  const SizedBox(height: AarastV3Space.x4),
                ],
              ),
            ),
    );
  }

  String? _safeCategoryId(
    ProviderMarketplaceProvider marketplace,
    ProviderDashboardProvider dashboard,
  ) {
    if (_categoryId == null) return null;
    return _sections(
          marketplace,
          dashboard,
        ).any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
  }

  /// RA-BE-152: the sections his listing is in (his category and his active
  /// services'); the server takes a new service only in one of them, and a
  /// new section comes with a category change the team approves.
  List<({String id, String nameAr})> _sections(
    ProviderMarketplaceProvider marketplace,
    ProviderDashboardProvider dashboard,
  ) {
    final listed = {
      dashboard.profile?.primaryCategoryId,
      for (final service in dashboard.services)
        if (service.isActive) service.categoryId,
    };
    return [
      for (final category in marketplace.categories)
        if (listed.contains(category.id))
          (id: category.id, nameAr: category.nameAr),
    ];
  }

  String? _safeCityId(ProviderMarketplaceProvider marketplace) {
    if (_cityId == null) return null;
    return marketplace.cities.any((city) => city.id == _cityId)
        ? _cityId
        : null;
  }

  void _configureDraft() {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'provider:service:new',
      fields: {
        'title': _titleController,
        'description': _descriptionController,
        'basePrice': _basePriceController,
        'priceUnit': _priceUnitController,
      },
      readExtras: () => {'categoryId': _categoryId, 'cityId': _cityId},
      restoreExtras: (data) {
        if (!mounted) return;
        setState(() {
          _categoryId = data['categoryId']?.toString();
          _cityId = data['cityId']?.toString();
        });
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    final ok = await context.read<ProviderDashboardProvider>().createService(
      title: _titleController.text,
      categoryId: _categoryId!,
      description: _descriptionController.text,
      basePrice: typedAmount(_basePriceController.text),
      priceUnit: _priceUnitController.text,
      currency: defaultCurrencyCode,
      cityId: _cityId,
    );

    if (!mounted) return;
    if (ok) {
      await _draft?.clear();
      if (!mounted) return;
      final router = GoRouter.of(context);
      AarastFormSuccess.show(
        context,
        message: 'انضافت الخدمة.',
        nextLabel: 'أضف خدمة ثانية',
        onNext: () => router.push(AppRouter.providerServiceNew),
      );
      context.go(AppRouter.providerDashboard);
    }
  }
}

bool _canManageProviderListing(String? status) {
  return status == 'ACTIVE' || status == 'APPROVED';
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
