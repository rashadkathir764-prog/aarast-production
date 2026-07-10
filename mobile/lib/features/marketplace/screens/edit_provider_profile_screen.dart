import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

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
    }

    return AarastPageScaffold(
      title: 'تعديل ملف المزود',
      subtitle: 'حدّث بيانات النشاط التي تظهر للعملاء في سوق الموردين.',
      resizeToAvoidBottomInset: true,
      actions: [
        IconButton(
          tooltip: 'رجوع',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.providerDashboard);
            }
          },
          icon: const Icon(LucideIcons.chevronRight),
        ),
      ],
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + 32,
        ),
        children: [
          if (dashboard.isLoading && profile == null)
            AarastSkeleton.form(fields: 4, inline: true)
          else if (profile == null && dashboard.errorMessage != null)
            AarastErrorState(
              title: 'تعذر تحميل ملف المزود',
              message: dashboard.errorMessage!,
              onRetry: dashboard.loadDashboard,
            )
          else if (profile == null)
            AarastEmptyState(
              icon: LucideIcons.store,
              title: 'لا يوجد ملف مزود',
              message:
                  'أرسل طلب الانضمام أولاً حتى تتمكن من تعديل بيانات المزود.',
              action: FilledButton.icon(
                onPressed: () => context.go(AppRouter.providerApply),
                icon: const Icon(LucideIcons.contact),
                label: const Text('طلب الانضمام كمزود'),
              ),
            )
          else ...[
            _ProfileEditNotice(profile: profile),
            const SizedBox(height: 16),
            AarastCard(
              color: AppTheme.surface,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AarastSectionHeader(
                      title: 'بيانات الظهور للعملاء',
                      icon: LucideIcons.store,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _businessNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'اسم النشاط / اسم المزود',
                        prefixIcon: Icon(LucideIcons.badge),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? 'اكتب اسم النشاط'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    ContactPhoneField(
                      phoneController: _phoneController,
                      label: 'رقم التواصل',
                      optional: false,
                      requireYemeni: true,
                    ),
                    const SizedBox(height: 14),
                    _ProfileDropdown(
                      value: _safeCityId(marketplace),
                      label: 'المدينة',
                      icon: LucideIcons.mapPin,
                      items: marketplace.cities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city.id,
                              child: Text(city.nameAr),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _cityId = value),
                      validator: (value) =>
                          value == null ? 'اختر المدينة' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      maxLength: 280,
                      decoration: const InputDecoration(
                        labelText: 'نبذة مختصرة',
                        hintText: 'اكتب ما يميز خدمتك ومناطق التغطية...',
                        prefixIcon: Icon(LucideIcons.fileText),
                      ),
                    ),
                    if (profile.primaryCategory?.nameAr.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 12),
                      _LockedCategoryNote(
                        categoryName: profile.primaryCategory!.nameAr.trim(),
                      ),
                    ],
                    if (marketplace.cities.isEmpty) ...[
                      const SizedBox(height: 12),
                      const _ReferenceDataWarning(),
                    ],
                    if (dashboard.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _InlineError(message: dashboard.errorMessage!),
                    ],
                    const SizedBox(height: 18),
                    AarastButton(
                      label: 'حفظ التعديل',
                      icon: LucideIcons.save,
                      isLoading: dashboard.isSubmitting,
                      onPressed: dashboard.isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _populate(ProviderDashboardProfile profile) {
    _businessNameController.text = profile.businessName;
    _phoneController.text = profile.phone ?? '';
    _descriptionController.text = profile.description ?? '';
    _cityId = profile.cityId;
    _didPopulate = true;
  }

  String? _safeCityId(ProviderMarketplaceProvider marketplace) {
    if (_cityId == null) return null;
    return marketplace.cities.any((city) => city.id == _cityId)
        ? _cityId
        : null;
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
    if (ok) context.go(AppRouter.providerDashboard);
  }
}

class _ProfileEditNotice extends StatelessWidget {
  const _ProfileEditNotice({required this.profile});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _providerStatusLabel(profile.status);
    return AarastCard(
      color: AppTheme.ivory,
      child: Row(
        children: [
          const Icon(LucideIcons.info, color: AppTheme.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'حالة الحساب: $statusLabel. تعديل البيانات لا يعني اعتماد المزود تلقائياً.',
              textAlign: TextAlign.right,
              style: const TextStyle(
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

class _LockedCategoryNote extends StatelessWidget {
  const _LockedCategoryNote({required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.burgundySoft,
      child: Row(
        children: [
          const Icon(LucideIcons.lock, color: AppTheme.burgundy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'فئة الخدمة الحالية: $categoryName. تغيير الفئة يحتاج مسار مراجعة منفصل.',
              textAlign: TextAlign.right,
              style: const TextStyle(
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

class _ReferenceDataWarning extends StatelessWidget {
  const _ReferenceDataWarning();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.burgundySoft,
      child: Text(
        'تعذر تحميل المدن الآن. تحقق من الاتصال وحاول مرة أخرى.',
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

class _ProfileDropdown extends StatelessWidget {
  const _ProfileDropdown({
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
    required this.validator,
  });

  final String? value;
  final String label;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }
}

String _providerStatusLabel(String status) {
  return switch (status) {
    'ACTIVE' => 'نشط',
    'PENDING' => 'قيد المراجعة',
    'REJECTED' => 'مرفوض',
    'SUSPENDED' => 'موقوف',
    _ => 'قيد المراجعة',
  };
}
