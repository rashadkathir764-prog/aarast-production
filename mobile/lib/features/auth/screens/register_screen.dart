import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show ProviderMarketplaceProvider, providerReferenceDataErrorMessage;
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';
import '../utils/application_password_policy.dart';
import 'otp_screen.dart';
import '../widgets/auth_wedding_widgets.dart';

enum _AccountType { customer, provider }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    this.startAsProvider = false,
    this.initialPhone,
    super.key,
  });

  final bool startAsProvider;
  final String? initialPhone;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
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
    _phoneController.text = widget.initialPhone?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final marketplace = context.watch<ProviderMarketplaceProvider>();
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
            _RegisterNarrative(providerMode: providerMode),
            const SizedBox(height: AarastV3Space.x3),
            AuthPanel(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AccountTypeSegmentedControl(
                    value: _accountType,
                    onChanged: (value) {
                      auth.clearError();
                      setState(() => _accountType = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (providerMode) ...[
                    const _ProviderModeNote(),
                    const SizedBox(height: 10),
                  ],
                  AuthTextField(
                    controller: _nameController,
                    label: providerMode
                        ? 'اسم النشاط / اسم المزود'
                        : 'الاسم الكامل',
                    icon: providerMode ? LucideIcons.store : LucideIcons.user,
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
                  const SizedBox(height: 10),
                  AuthTextField(
                    controller: _phoneController,
                    label: providerMode ? 'رقم التواصل' : 'رقم الهاتف',
                    hint: 'مثال: 77xxxxxxx',
                    icon: LucideIcons.phone,
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
                  if (providerMode) ...[
                    const SizedBox(height: 10),
                    _ProviderReferenceFields(
                      marketplace: marketplace,
                      cityId: _safeCityId(marketplace),
                      categoryId: _safeCategoryId(marketplace),
                      onCityChanged: (value) => setState(() => _cityId = value),
                      onCategoryChanged: (value) =>
                          setState(() => _categoryId = value),
                    ),
                    const SizedBox(height: 10),
                    AarastDisclosureCard(
                      title: 'نبذة النشاط',
                      subtitle: 'أضف الخدمات وما يميزك عند الحاجة',
                      icon: LucideIcons.fileText,
                      child: AuthTextField(
                        controller: _descriptionController,
                        label: 'نبذة مختصرة',
                        hint: 'الخدمات، المدينة، وما يميز نشاطك',
                        icon: LucideIcons.fileText,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    icon: LucideIcons.lock,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    suffixIcon: AuthObscureToggle(
                      obscured: _obscurePassword,
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'كلمة المرور مطلوبة';
                      }
                      if (value.length < 6) {
                        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      }
                      if (!isApplicationPasswordWithinByteLimit(value)) {
                        return 'كلمة المرور طويلة جدًا. اختصرها ثم حاول مرة أخرى';
                      }
                      return null;
                    },
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    AuthInlineError(message: auth.errorMessage!),
                  ],
                  const SizedBox(height: 12),
                  AarastButton(
                    label: providerMode ? 'إرسال طلب الانضمام' : 'إنشاء حساب',
                    icon: providerMode
                        ? LucideIcons.contact
                        : LucideIcons.userPlus,
                    isLoading: auth.isSubmitting,
                    compact: true,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
    final normalizedPhone = normalizeYemeniPhone(_phoneController.text);
    final otp = await auth.startRegistration(
      name: _nameController.text.trim(),
      phone: normalizedPhone,
      password: _passwordController.text,
    );

    if (otp == null || !mounted) return;

    final providerApplication = _accountType == _AccountType.provider
        ? PendingProviderApplication(
            businessName: _nameController.text.trim(),
            phone: normalizedPhone,
            cityId: _cityId!,
            categoryId: _categoryId!,
            description: _descriptionController.text.trim(),
          )
        : null;

    context.go(
      AppRouter.otp,
      extra: OtpScreenArgs(
        phone: normalizedPhone,
        purpose: 'REGISTER',
        otpNoticeMessage: otp.noticeMessage,
        successLocation: _safeResumeLocation(context),
        registration: PendingRegistration(
          name: _nameController.text.trim(),
          phone: normalizedPhone,
          password: _passwordController.text,
          providerApplication: providerApplication,
        ),
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

class _RegisterNarrative extends StatelessWidget {
  const _RegisterNarrative({required this.providerMode});

  final bool providerMode;

  @override
  Widget build(BuildContext context) {
    final accent = providerMode ? AarastV3Color.cobalt : AarastV3Color.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AuthBrandMark(compact: true),
            const SizedBox(width: AarastV3Space.x3),
            Container(width: 28, height: 2, color: AarastV3Color.signal),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: Text(
                providerMode ? 'بوابة المزوّد' : 'حسابك في أعرست',
                style: AarastV3Type.label(context).copyWith(color: accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
        Text(
          providerMode ? 'أنشئ حساب مزوّد' : 'أنشئ حسابك',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AarastV3Color.ink,
            fontFamily: AppTheme.displayFontFamily,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AarastV3Space.x2),
        Text(
          providerMode
              ? 'بيانات النشاط الأساسية أولاً، ثم تراجع الإدارة الطلب.'
              : 'ثلاثة حقول فقط تفصلك عن مساحة زفافك.',
          style: AarastV3Type.body(context),
        ),
      ],
    );
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
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: AppTheme.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SegmentOption(
                  selected: value == _AccountType.customer,
                  label: 'عميل',
                  icon: LucideIcons.heart,
                  onTap: () => onChanged(_AccountType.customer),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentOption(
                  selected: value == _AccountType.provider,
                  label: 'مزود',
                  icon: LucideIcons.store,
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
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
    return const Padding(
      padding: EdgeInsetsDirectional.only(start: 2),
      child: Text(
        'سيتم مراجعة طلبك، وبعد الموافقة ستظهر لوحة المزود.',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
          height: 1.45,
        ),
      ),
    );
  }
}

class _ProviderDropdown extends StatelessWidget {
  const _ProviderDropdown({
    required this.fieldKey,
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
    required this.validator,
  });

  final Key fieldKey;
  final String? value;
  final String label;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: fieldKey,
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class _ProviderReferenceFields extends StatelessWidget {
  const _ProviderReferenceFields({
    required this.marketplace,
    required this.cityId,
    required this.categoryId,
    required this.onCityChanged,
    required this.onCategoryChanged,
  });

  final ProviderMarketplaceProvider marketplace;
  final String? cityId;
  final String? categoryId;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    if (marketplace.isReferenceDataLoading &&
        (marketplace.cities.isEmpty || marketplace.categories.isEmpty)) {
      return const _ProviderReferenceLoading();
    }

    if (marketplace.cities.isEmpty || marketplace.categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthInlineError(
            message:
                marketplace.referenceDataErrorMessage ??
                providerReferenceDataErrorMessage,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: marketplace.isReferenceDataLoading
                ? null
                : marketplace.loadReferenceData,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    return Column(
      children: [
        _ProviderDropdown(
          fieldKey: const Key('provider-city-dropdown'),
          value: cityId,
          label: 'المدينة',
          icon: LucideIcons.mapPin,
          items: marketplace.cities
              .map(
                (city) =>
                    DropdownMenuItem(value: city.id, child: Text(city.nameAr)),
              )
              .toList(),
          onChanged: onCityChanged,
          validator: (value) => value == null ? 'اختر المدينة' : null,
        ),
        const SizedBox(height: 10),
        _ProviderDropdown(
          fieldKey: const Key('provider-category-dropdown'),
          value: categoryId,
          label: 'الفئة',
          icon: LucideIcons.shapes,
          items: marketplace.categories
              .map(
                (category) => DropdownMenuItem(
                  value: category.id,
                  child: Text(category.nameAr),
                ),
              )
              .toList(),
          onChanged: onCategoryChanged,
          validator: (value) => value == null ? 'اختر الفئة' : null,
        ),
      ],
    );
  }
}

class _ProviderReferenceLoading extends StatelessWidget {
  const _ProviderReferenceLoading();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastV3ProgressLine(
            height: 3,
            semanticsLabel: 'تحميل المدن والفئات',
          ),
          SizedBox(height: 10),
          Text(
            'جارٍ تحميل المدن والفئات…',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
