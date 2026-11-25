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
import '../../marketplace/marketplace_api.dart' show MarketplaceService;
import '../data/provider_text_limits.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_listing_sheet.dart' show providerListingPriceError;

class AddProviderPackageScreen extends StatefulWidget {
  const AddProviderPackageScreen({super.key});

  @override
  State<AddProviderPackageScreen> createState() =>
      _AddProviderPackageScreenState();
}

class _AddProviderPackageScreenState extends State<AddProviderPackageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _itemsController = TextEditingController();
  String? _serviceId;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderDashboardProvider>().loadDashboard();
      _configureDraft();
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final services = dashboard.services;
    final canManageListing = _canManageProviderListing(
      dashboard.profile?.status,
    );

    // The other provider pages' frame: the canvas, the round back at the
    // title's start, the page's own gutter.
    final header = JourneySubHeader(
      title: 'إضافة باقة',
      // Opened by a link there is no page behind it: back to «ملفي».
      onBack: () => context.popOrGo(AppRouter.providerProfileTab),
    );
    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: canManageListing
          ? AarastV3FormActionBar(
              label: 'إضافة الباقة',
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
                    title: 'الباقات تنضاف بعد الموافقة',
                    message:
                        'فريق اعّرست يراجع ملفك أول، وبعد ما نوافق تضيف باقاتك من هنا.',
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
                  // RA-MO-303: one voice to the provider (it mixed «اجمعي»
                  // and «تريد»). What a package is, in one line: «الخدمات»
                  // and «الباقات» read alike (finding 11).
                  const AarastV3FocusPrompt(
                    eyebrow: 'الباقة',
                    question: 'ايش تجمع هذي الباقة؟',
                    supportingText:
                        'الباقة تجمع خدماتك بسعر واحد، وتطلع لك في العرض السريع.',
                    icon: LucideIcons.package,
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
                        label: 'اسم الباقة',
                        icon: LucideIcons.package,
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'اكتب اسم الباقة'
                            : null,
                      ),
                      const SizedBox(height: AarastV3Field.gap),
                      JourneyTextField(
                        controller: _priceController,
                        validator: (value) =>
                            providerListingPriceError(value ?? ''),
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        label: 'السعر',
                        suffix: currencyLabelAr(defaultCurrencyCode),
                        // Why the currency is fixed.
                        helper: 'الأسعار بالريال اليمني',
                        icon: LucideIcons.wallet,
                      ),
                    ],
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  AarastDisclosureCard(
                    title: 'محتوى الباقة',
                    subtitle: 'الخدمة اللي تتبعها، وايش يشمل',
                    icon: LucideIcons.listChecks,
                    initiallyExpanded:
                        _serviceId != null ||
                        _descriptionController.text.isNotEmpty ||
                        _itemsController.text.isNotEmpty,
                    child: Column(
                      children: [
                        JourneyChoiceField<String?>(
                          value: _safeServiceId(services),
                          label: 'الخدمة المرتبطة',
                          icon: LucideIcons.wand,
                          choices: [
                            const JourneyChoice(null, 'باقة عامة'),
                            for (final service in services)
                              JourneyChoice(service.id, service.title),
                          ],
                          onChanged: (value) {
                            setState(() => _serviceId = value);
                            _draft?.changed();
                          },
                        ),
                        const SizedBox(height: AarastV3Field.gap),
                        JourneyTextField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 3,
                          maxLength: 220,
                          label: 'وصف مختصر',
                          icon: LucideIcons.fileText,
                        ),
                        const SizedBox(height: AarastV3Field.gap),
                        JourneyTextField(
                          controller: _itemsController,
                          minLines: 3,
                          maxLines: 4,
                          label: 'المميزات',
                          hint: 'كل ميزة في سطر',
                          icon: LucideIcons.listChecks,
                          validator: (value) =>
                              providerPackageItemsError(value ?? ''),
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

  String? _safeServiceId(List<MarketplaceService> services) {
    if (_serviceId == null) return null;
    return services.any((service) => service.id == _serviceId)
        ? _serviceId
        : null;
  }

  void _configureDraft() {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'provider:package:new',
      fields: {
        'title': _titleController,
        'description': _descriptionController,
        'price': _priceController,
        'items': _itemsController,
      },
      readExtras: () => {'serviceId': _serviceId},
      restoreExtras: (data) {
        if (!mounted) return;
        setState(() => _serviceId = data['serviceId']?.toString());
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final items = providerPackageItems(_itemsController.text);

    final ok = await context.read<ProviderDashboardProvider>().createPackage(
      title: _titleController.text,
      serviceId: _serviceId,
      description: _descriptionController.text,
      price: typedAmount(_priceController.text),
      currency: defaultCurrencyCode,
      items: items,
    );

    if (!mounted) return;
    if (ok) {
      await _draft?.clear();
      if (!mounted) return;
      final router = GoRouter.of(context);
      AarastFormSuccess.show(
        context,
        message: 'انضافت الباقة.',
        nextLabel: 'أضف باقة ثانية',
        onNext: () => router.push(AppRouter.providerPackageNew),
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
