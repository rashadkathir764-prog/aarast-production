import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/providers/marketplace_provider.dart';
import '../providers/auth_controller.dart';
import 'otp_screen.dart';
import '../widgets/auth_wedding_widgets.dart';

enum _AccountType { customer, provider }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({this.startAsProvider = false, super.key});

  final bool startAsProvider;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _obscurePassword = true;
  _AccountType _accountType = _AccountType.customer;
  String? _cityId;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    if (widget.startAsProvider) {
      _accountType = _AccountType.provider;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final textTheme = Theme.of(context).textTheme;
    final providerMode = _accountType == _AccountType.provider;

    return AuthWeddingScaffold(
      leading: AuthBackButton(
        onPressed: () => context.go(AppRouter.onboarding),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const AuthBrandMark(compact: true),
            const SizedBox(height: 18),
            Text(
              providerMode ? 'طلب الانضمام كمزود' : 'إنشاء حساب',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              providerMode
                  ? 'أرسلي بيانات نشاطك وسيتم مراجعة الطلب قبل ظهور لوحة المزود.'
                  : 'ابدأ رحلتك بخطة زفاف واضحة ومرتبة.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            AuthPanel(
              padding: EdgeInsets.all(providerMode ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AccountTypeSegmentedControl(
                    value: _accountType,
                    onChanged: (value) {
                      auth.clearError();
                      dashboard.clearError();
                      setState(() => _accountType = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (providerMode) ...[
                    const _ProviderModeNote(),
                    const SizedBox(height: 14),
                  ],
                  AuthTextField(
                    controller: _nameController,
                    label: providerMode
                        ? 'اسم النشاط / اسم المزود'
                        : 'الاسم الكامل',
                    icon: providerMode
                        ? Icons.storefront_rounded
                        : Icons.person_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return providerMode
                            ? 'اسم النشاط مطلوب'
                            : 'الاسم مطلوب';
                      }
                      if (value.trim().length < 3) {
                        return providerMode
                            ? 'اسم النشاط قصير جداً'
                            : 'الاسم قصير جداً';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _phoneController,
                    label: providerMode ? 'رقم التواصل' : 'رقم الهاتف',
                    hint: 'مثال: 77xxxxxxx',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    suffixIcon: ContactPhoneFieldSuffix(
                      controller: _phoneController,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'رقم الهاتف مطلوب';
                      }
                      if (!isValidYemeniPhoneInput(value)) {
                        return 'رقم الهاتف غير صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني اختياري',
                    icon: Icons.mail_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  if (providerMode) ...[
                    const SizedBox(height: 14),
                    _ProviderDropdown(
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
                          value == null ? 'اختر المدينة' : null,
                    ),
                    const SizedBox(height: 14),
                    _ProviderDropdown(
                      value: _safeCategoryId(marketplace),
                      label: 'الفئة',
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
                      validator: (value) => value == null ? 'اختر الفئة' : null,
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _descriptionController,
                      label: 'نبذة مختصرة',
                      hint: 'الخدمات، المدينة، وما يميز نشاطك',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    icon: Icons.lock_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'إظهار كلمة المرور'
                          : 'إخفاء كلمة المرور',
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'كلمة المرور مطلوبة';
                      }
                      if (value.length < 6) {
                        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AuthInlineError(message: auth.errorMessage!),
                  ],
                  if (providerMode && dashboard.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AuthInlineError(message: dashboard.errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  AarastButton(
                    label: providerMode ? 'إرسال طلب الانضمام' : 'إنشاء حساب',
                    icon: providerMode
                        ? Icons.assignment_ind_outlined
                        : Icons.person_add_alt_1_rounded,
                    isLoading: auth.isSubmitting || dashboard.isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AuthFooterLink(
              prefix: 'لديك حساب بالفعل؟',
              action: 'تسجيل الدخول',
              onTap: () {
                if (auth.isSubmitting) return;
                auth.clearError();
                final resume = _safeResumeLocation(context);
                context.go(
                  _withResume(AppRouter.login, resumeLocation: resume),
                );
              },
            ),
          ],
        ),
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
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final email = _emailController.text.trim();
    final normalizedPhone = normalizeYemeniPhone(_phoneController.text);
    final success = await auth.register(
      name: _nameController.text.trim(),
      phone: normalizedPhone,
      email: email.isEmpty ? null : email,
      password: _passwordController.text,
    );

    if (!success || !mounted) return;

    if (_accountType == _AccountType.provider) {
      if (_cityId == null || _categoryId == null) return;
      final applied = await context
          .read<ProviderDashboardProvider>()
          .applyProvider(
            businessName: _nameController.text.trim(),
            phone: normalizedPhone,
            cityId: _cityId!,
            categoryIds: [_categoryId!],
            description: _descriptionController.text,
          );
      if (applied && mounted) {
        context.go(AppRouter.providerApplyStatus);
      }
      return;
    }

    final otp = await auth.requestOtp(
      phone: normalizedPhone,
      purpose: 'VERIFY_PHONE',
    );
    if (otp == null || !mounted) return;

    context.go(
      AppRouter.otp,
      extra: OtpScreenArgs(
        phone: normalizedPhone,
        purpose: 'VERIFY_PHONE',
        devOtpMessage: otp.localDevMessage,
      ),
    );
  }

  String? _safeResumeLocation(BuildContext context) {
    final resume = GoRouterState.of(context).uri.queryParameters['resume'];
    if (resume == null || resume.trim().isEmpty) return null;
    if (!resume.startsWith('/') || resume.startsWith('//')) return null;
    return resume;
  }

  String _withResume(String location, {String? resumeLocation}) {
    if (resumeLocation == null) return location;
    return Uri.parse(
      location,
    ).replace(queryParameters: {'resume': resumeLocation}).toString();
  }
}

class _AccountTypeSegmentedControl extends StatelessWidget {
  const _AccountTypeSegmentedControl({
    required this.value,
    required this.onChanged,
  });

  final _AccountType value;
  final ValueChanged<_AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'نوع الحساب',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.dInk,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.dCard2,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.dLine),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SegmentOption(
                  selected: value == _AccountType.customer,
                  label: 'عميل',
                  icon: Icons.favorite_border_rounded,
                  onTap: () => onChanged(_AccountType.customer),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentOption(
                  selected: value == _AccountType.provider,
                  label: 'مزود',
                  icon: Icons.storefront_rounded,
                  onTap: () => onChanged(_AccountType.provider),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentOption extends StatelessWidget {
  const _SegmentOption({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.dMaroon : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppTheme.dInkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.dInkSoft,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderModeNote extends StatelessWidget {
  const _ProviderModeNote();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      padding: EdgeInsets.all(14),
      color: AppTheme.dCreamBg,
      child: Text(
        'سيتم مراجعة طلبك، وبعد الموافقة ستظهر لوحة المزود.',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: AppTheme.dInk,
          fontWeight: FontWeight.w800,
          height: 1.45,
        ),
      ),
    );
  }
}

class _ProviderDropdown extends StatelessWidget {
  const _ProviderDropdown({
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
