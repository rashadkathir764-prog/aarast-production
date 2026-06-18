import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
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
      subtitle: 'أضيفي خدمة واضحة لتظهر ضمن ملف المزود بعد الاعتماد.',
      resizeToAvoidBottomInset: true,
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      child: !canManageListing
          ? ListView(
              children: [
                if (dashboard.isLoading && dashboard.profile == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  AarastEmptyState(
                    icon: Icons.lock_clock_outlined,
                    title: 'إضافة الخدمات بعد الاعتماد',
                    message:
                        'الإدارة تراجع حساب المزود أولاً. ستتمكنين من إضافة الخدمات بعد أن تصبح الحالة نشطة.',
                    action: FilledButton.icon(
                      onPressed: () => context.go(AppRouter.providerDashboard),
                      icon: const Icon(Icons.dashboard_customize_outlined),
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
                    color: AppTheme.dCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'اسم الخدمة',
                            prefixIcon: Icon(Icons.design_services_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 2
                              ? 'اكتبي اسم الخدمة'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _safeCategoryId(marketplace),
                          decoration: const InputDecoration(
                            labelText: 'الفئة',
                            prefixIcon: Icon(Icons.category_outlined),
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
                              value == null ? 'اختاري الفئة' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _safeCityId(marketplace),
                          decoration: const InputDecoration(
                            labelText: 'مدينة الخدمة اختياري',
                            prefixIcon: Icon(Icons.place_outlined),
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
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _basePriceController,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'السعر من',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _priceUnitController,
                          decoration: const InputDecoration(
                            labelText: 'مدة الخدمة / ملاحظات السعر',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                        ),
                        if (dashboard.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _InlineError(message: dashboard.errorMessage!),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: dashboard.isSubmitting ? null : _submit,
                          icon: dashboard.isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_rounded),
                          label: const Text('إضافة الخدمة'),
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
      currency: 'YER',
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
      color: AppTheme.dCreamBg,
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppTheme.dGoldDeep),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'اكتبي خدمة حقيقية وواضحة. رفع الصور سيظهر لاحقًا عند ربط نظام الملفات.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.dInk,
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
      color: AppTheme.dPinkBg,
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
