import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show ProviderMarketplaceProvider;
import '../providers/provider_dashboard_provider.dart';

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

    return AarastPageScaffold(
      title: 'إضافة خدمة',
      subtitle: 'أضف خدمة واضحة لتظهر ضمن ملف المزود بعد الاعتماد.',
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: canManageListing
          ? AarastV3FormActionBar(
              label: 'إضافة الخدمة',
              icon: LucideIcons.plus,
              loading: dashboard.isSubmitting,
              onPressed: dashboard.isSubmitting ? null : _submit,
            )
          : null,
      actions: [
        IconButton(
          tooltip: 'رجوع',
          // Opened by a link there is no page behind it: back to «ملفي».
          onPressed: () => context.popOrGo(AppRouter.providerProfileTab),
          icon: const Icon(LucideIcons.chevronRight),
        ),
      ],
      child: !canManageListing
          ? ListView(
              children: [
                if (dashboard.isLoading && dashboard.profile == null)
                  AarastSkeleton.form(fields: 4, inline: true)
                else
                  AarastEmptyState(
                    icon: LucideIcons.fileClock,
                    title: 'إضافة الخدمات بعد الاعتماد',
                    message:
                        'الإدارة تراجع حساب المزود أولاً. يمكنك إضافة الخدمات بعد أن تصبح الحالة نشطة.',
                    action: FilledButton.icon(
                      onPressed: () => context.go(AppRouter.providerDashboard),
                      icon: const Icon(LucideIcons.layoutDashboard),
                      label: const Text('فتح لوحة المزود'),
                    ),
                  ),
              ],
            )
          : Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const AarastV3FocusPrompt(
                    question: 'ما الخدمة التي سيجدها العميل هنا؟',
                    supportingText:
                        'اكتب اسمًا مفهومًا واختر الفئة؛ السعر والوصف يساعدان المقارنة دون وعود حجز.',
                    icon: LucideIcons.wand,
                  ),
                  if (_draft != null) ...[
                    const SizedBox(height: AarastV3Space.x2),
                    AarastV3DraftStatusLine(status: _draft!.status),
                  ],
                  const SizedBox(height: AarastV3Space.x2),
                  AarastV3FormSurface(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم الخدمة',
                          prefixIcon: Icon(LucideIcons.wand),
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'اكتب اسم الخدمة'
                            : null,
                      ),
                      const SizedBox(height: AarastV3Space.x2),
                      DropdownButtonFormField<String>(
                        initialValue: _safeCategoryId(marketplace),
                        decoration: const InputDecoration(
                          labelText: 'الفئة',
                          prefixIcon: Icon(LucideIcons.shapes),
                        ),
                        items: marketplace.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.nameAr),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _categoryId = value);
                          _draft?.changed();
                        },
                        validator: (value) =>
                            value == null ? 'اختر الفئة' : null,
                      ),
                      const SizedBox(height: AarastV3Space.x2),
                      TextFormField(
                        controller: _basePriceController,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'السعر من',
                          suffixText: currencyLabelAr(defaultCurrencyCode),
                          prefixIcon: Icon(LucideIcons.wallet),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  AarastDisclosureCard(
                    title: 'تفاصيل تساعد العميل',
                    subtitle: 'المدينة والوصف وملاحظة السعر',
                    icon: LucideIcons.fileText,
                    initiallyExpanded:
                        _cityId != null ||
                        _descriptionController.text.isNotEmpty,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _safeCityId(marketplace),
                          decoration: const InputDecoration(
                            labelText: 'مدينة الخدمة',
                            prefixIcon: Icon(LucideIcons.mapPin),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('نفس مدينة المزود'),
                            ),
                            for (final city in marketplace.cities)
                              DropdownMenuItem(
                                value: city.id,
                                child: Text(city.nameAr),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _cityId = value);
                            _draft?.changed();
                          },
                        ),
                        const SizedBox(height: AarastV3Space.x2),
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 3,
                          maxLength: 280,
                          decoration: const InputDecoration(
                            labelText: 'ماذا تشمل الخدمة؟',
                            prefixIcon: Icon(LucideIcons.fileText),
                          ),
                        ),
                        const SizedBox(height: AarastV3Space.x2),
                        TextFormField(
                          controller: _priceUnitController,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظة السعر أو المدة',
                            prefixIcon: Icon(LucideIcons.timer),
                          ),
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

  String? _safeCategoryId(ProviderMarketplaceProvider marketplace) {
    if (_categoryId == null) return null;
    return marketplace.categories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
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
      basePrice: _basePriceController.text,
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
        message: 'تمت إضافة الخدمة.',
        nextLabel: 'إضافة أخرى',
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
