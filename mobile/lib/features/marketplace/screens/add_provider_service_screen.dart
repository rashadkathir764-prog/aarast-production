import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/marketplace_provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
      context.read<ProviderDashboardProvider>().loadDashboard();
    });
  }

  @override
  void dispose() {
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
      actions: [
        IconButton(
          tooltip: 'رجوع',
          onPressed: () {
            if (context.canPop()) context.pop();
          },
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
                  const _ServiceIntro(),
                  const SizedBox(height: 16),
                  AarastCard(
                    color: AppTheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        const SizedBox(height: 14),
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
                          onChanged: (value) =>
                              setState(() => _categoryId = value),
                          validator: (value) =>
                              value == null ? 'اختر الفئة' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _safeCityId(marketplace),
                          decoration: const InputDecoration(
                            labelText: 'مدينة الخدمة اختياري',
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
                          onChanged: (value) => setState(() => _cityId = value),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          maxLength: 280,
                          decoration: const InputDecoration(
                            labelText: 'الوصف',
                            hintText: 'ما الذي تشمل الخدمة؟',
                            prefixIcon: Icon(LucideIcons.fileText),
                          ),
                        ),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _priceUnitController,
                          decoration: const InputDecoration(
                            labelText: 'مدة الخدمة / ملاحظات السعر',
                            prefixIcon: Icon(LucideIcons.timer),
                          ),
                        ),
                        if (dashboard.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _InlineError(message: dashboard.errorMessage!),
                        ],
                        const SizedBox(height: 18),
                        AarastButton(
                          label: 'إضافة الخدمة',
                          icon: LucideIcons.plus,
                          isLoading: dashboard.isSubmitting,
                          onPressed: dashboard.isSubmitting ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تمت إضافة الخدمة')));
      context.go(AppRouter.providerDashboard);
    }
  }
}

bool _canManageProviderListing(String? status) {
  return status == 'ACTIVE' || status == 'APPROVED';
}

class _ServiceIntro extends StatelessWidget {
  const _ServiceIntro();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.ivory,
      child: Row(
        children: [
          Icon(LucideIcons.sparkles, color: AppTheme.gold),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'اكتب خدمة حقيقية وواضحة. بعد الحفظ ارفع صورها ورتب معرضها من تبويب الخدمات في لوحة المزود.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ],
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
      color: AppTheme.burgundySoft,
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
