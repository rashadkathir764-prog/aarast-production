import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../providers/marketplace_provider.dart';

class ProviderApplyScreen extends StatefulWidget {
  const ProviderApplyScreen({super.key});

  @override
  State<ProviderApplyScreen> createState() => _ProviderApplyScreenState();
}

class _ProviderApplyScreenState extends State<ProviderApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _cityId;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
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
    final auth = context.watch<AuthController>();
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final hasProfile = dashboard.hasProviderProfile;

    return AarastPageScaffold(
      title: 'طلب الانضمام كمزود',
      subtitle: 'أضيفي نشاطك ليصل إليك عملاء يبحثون عن خدمات الزفاف.',
      resizeToAvoidBottomInset: true,
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.home);
            }
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + 32,
        ),
        children: [
          if (auth.status == AuthStatus.unauthenticated)
            _AuthRequiredCard(
              onLogin: () => context.go(AppRouter.login),
              onRegisterProvider: () =>
                  context.go('${AppRouter.register}?type=provider'),
            )
          else if (dashboard.isLoading && dashboard.profile == null)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasProfile)
            _AlreadyProviderCard(
              status: dashboard.profile?.status ?? 'PENDING',
              onDashboard: () => context.go(AppRouter.providerDashboard),
            )
          else ...[
            const _ApplyIntroCard(),
            const SizedBox(height: 16),
            AarastCard(
              color: AppTheme.dCard,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AarastSectionHeader(
                      title: 'بيانات النشاط',
                      icon: Icons.storefront_rounded,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _businessNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'اسم النشاط / اسم المزود',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? 'اكتبي اسم النشاط'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'رقم التواصل',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 6
                          ? 'اكتبي رقم تواصل صحيح'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _ApplyDropdown(
                      value: _safeCityId(marketplace),
                      label: 'المدينة',
                      icon: Icons.place_outlined,
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
                          value == null ? 'اختاري المدينة' : null,
                    ),
                    const SizedBox(height: 14),
                    _ApplyDropdown(
                      value: _safeCategoryId(marketplace),
                      label: 'فئة الخدمة',
                      icon: Icons.category_outlined,
                      items: marketplace.categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.nameAr),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'اختاري فئة الخدمة' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      maxLength: 280,
                      decoration: const InputDecoration(
                        labelText: 'نبذة مختصرة',
                        hintText: 'اكتبي ما يميز خدمتك ومناطق التغطية...',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    if (marketplace.cities.isEmpty ||
                        marketplace.categories.isEmpty) ...[
                      const SizedBox(height: 12),
                      const _ReferenceDataWarning(),
                    ],
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('إرسال طلب الانضمام'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String? _safeCityId(ProviderMarketplaceProvider marketplace) {
    if (_cityId == null) return null;
    return marketplace.cities.any((city) => city.id == _cityId)
        ? _cityId
        : null;
  }

  String? _safeCategoryId(ProviderMarketplaceProvider marketplace) {
    if (_categoryId == null) return null;
    return marketplace.categories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _cityId == null ||
        _categoryId == null) {
      return;
    }

    final ok = await context.read<ProviderDashboardProvider>().applyProvider(
      businessName: _businessNameController.text,
      phone: _phoneController.text,
      cityId: _cityId!,
      categoryIds: [_categoryId!],
      description: _descriptionController.text,
    );

    if (!mounted) return;
    if (ok) context.go(AppRouter.providerApplyStatus);
  }
}

class ProviderApplyStatusScreen extends StatelessWidget {
  const ProviderApplyStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AarastPageScaffold(
      title: 'تم استلام طلبك',
      subtitle: 'طلب الانضمام كمزود قيد المراجعة.',
      child: ListView(
        children: [
          const SizedBox(height: 32),
          AarastEmptyState(
            icon: Icons.mark_email_read_outlined,
            title: 'تم استلام طلبك',
            message:
                'سيتم مراجعة بياناتك، وبعد الموافقة ستظهر لوحة المزود وخدماتك في المكان المناسب.',
            action: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(AppRouter.home),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('العودة للرئيسية'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRouter.providerMarketplace),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('فتح الموردين'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _ProviderReviewNote(),
        ],
      ),
    );
  }
}

class _ApplyIntroCard extends StatelessWidget {
  const _ApplyIntroCard();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.dCreamBg,
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: AppTheme.dGoldDeep),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'سيتم مراجعة طلبك، وبعد الموافقة ستظهر لوحة المزود وتستطيعين إدارة الخدمات والباقات وطلبات عروض الأسعار.',
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

class _AuthRequiredCard extends StatelessWidget {
  const _AuthRequiredCard({
    required this.onLogin,
    required this.onRegisterProvider,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegisterProvider;

  @override
  Widget build(BuildContext context) {
    return AarastEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'تسجيل الدخول مطلوب',
      message: 'أنشئي حسابًا أو سجلي الدخول أولًا لإرسال طلب الانضمام كمزود.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('تسجيل الدخول'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRegisterProvider,
            icon: const Icon(Icons.storefront_rounded),
            label: const Text('إنشاء حساب كمزود'),
          ),
        ],
      ),
    );
  }
}

class _AlreadyProviderCard extends StatelessWidget {
  const _AlreadyProviderCard({required this.status, required this.onDashboard});

  final String status;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    return AarastEmptyState(
      icon: Icons.store_mall_directory_outlined,
      title: status == 'ACTIVE' ? 'حساب المزود نشط' : 'طلبك قيد المراجعة',
      message: status == 'ACTIVE'
          ? 'يمكنك فتح لوحة المزود لإدارة الخدمات والطلبات.'
          : 'تم استلام طلبك مسبقًا. ستظهر حالة الحساب من لوحة المزود.',
      action: FilledButton.icon(
        onPressed: onDashboard,
        icon: const Icon(Icons.dashboard_customize_outlined),
        label: const Text('فتح لوحة المزود'),
      ),
    );
  }
}

class _ReferenceDataWarning extends StatelessWidget {
  const _ReferenceDataWarning();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.dPinkBg,
      child: Text(
        'تعذر تحميل المدن أو الفئات حاليًا. تأكدي من تشغيل الخلفية ثم أعيدي المحاولة.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ProviderReviewNote extends StatelessWidget {
  const _ProviderReviewNote();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.dCard,
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.dMaroon),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لن يتم اعتماد المزود تلقائيًا. الظهور في نتائج البحث يعتمد على حالة الموافقة من النظام.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
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

class _ApplyDropdown extends StatelessWidget {
  const _ApplyDropdown({
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
