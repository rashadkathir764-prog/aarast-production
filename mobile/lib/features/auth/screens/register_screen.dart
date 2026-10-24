import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingDraft, GuestOnboardingStorage;
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';
import '../utils/application_password_policy.dart';
import 'otp_screen.dart';
import '../widgets/auth_wedding_widgets.dart';

/// The wedding account (a-series). A provider's account is
/// [ProviderRegisterScreen] (p01).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({this.initialPhone, super.key});

  final String? initialPhone;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  /// After a submit showed errors, each field re-checks as it is edited, so
  /// "required" disappears once the field is filled (field test Q09).
  bool _submitAttempted = false;

  /// The plan kept on the phone (a08), which this account will save.
  GuestOnboardingDraft? _keptPlan;

  /// The name came with the kept plan and is valid, so it is not asked
  /// again (a08b). A name that would fail stays in a field to fix.
  bool _nameFromPlan = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _readKeptPlan();
    });
  }

  Future<void> _readKeptPlan() async {
    final GuestOnboardingStorage storage;
    try {
      storage = context.read<GuestOnboardingStorage>();
    } on ProviderNotFoundException {
      return;
    }
    final draft = await storage.loadDraft();
    if (!mounted || draft == null || !draft.isCompleteGuestPlan) return;
    final title = draft.planName?.trim() ?? '';
    final name = title.startsWith('عرس ') ? title.substring(4).trim() : '';
    setState(() {
      _keptPlan = draft;
      if (_nameController.text.trim().isEmpty && name.length >= 3) {
        _nameController.text = name;
        _nameFromPlan = true;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final keptPlan = _keptPlan;

    return AuthWeddingScaffold(
      leading: AuthBackButton(
        onPressed: () => context.go(AppRouter.onboarding),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JourneyButton(
            key: const ValueKey('register-submit'),
            label: keptPlan != null ? 'احفظ خطتي' : 'إنشاء حساب',
            expand: true,
            large: true,
            loading: auth.isSubmitting,
            onPressed: _submit,
          ),
          AuthFooterLink(
            prefix: 'لديك حساب؟',
            action: 'تسجيل الدخول',
            onTap: () {
              if (auth.isSubmitting) return;
              auth.clearError();
              final resume = _safeResumeLocation(context);
              context.go(_withResume(AppRouter.login, resumeLocation: resume));
            },
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: _submitAttempted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeading(
              title: keptPlan != null
                  ? context.say('احفظ خطتك', 'احفظي خطتك')
                  : context.say('أنشئ حسابك', 'أنشئي حسابك'),
              subtitle: keptPlan != null
                  ? 'خطتك محفوظة في جوالك، وبالحساب ما تضيع'
                  : 'حساب واحد لخطتك ولكل خطة تشارك فيها',
            ),
            const SizedBox(height: 18),
            if (keptPlan != null) ...[
              _KeptPlanStrip(plan: keptPlan),
              const SizedBox(height: 14),
            ],
            AuthPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_nameFromPlan) ...[
                    AuthTextField(
                      controller: _nameController,
                      label: 'الاسم',
                      icon: LucideIcons.user,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الاسم مطلوب';
                        }
                        if (value.trim().length < 3) {
                          return 'الاسم قصير جداً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  AuthTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    hint: '777 123 456',
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
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '6 أحرف أو أكثر. بعدها نرسل لك رمز تأكيد على واتساب.',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    AuthInlineError(message: auth.errorMessage!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_submitAttempted) setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final normalizedPhone = normalizeYemeniPhone(_phoneController.text);
    final otp = await auth.startRegistration(
      name: _nameController.text.trim(),
      phone: normalizedPhone,
      password: _passwordController.text,
    );

    if (otp == null || !mounted) return;

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

/// «عرس محمد · صنعاء · 11 بند»: the plan this account will save.
class _KeptPlanStrip extends StatelessWidget {
  const _KeptPlanStrip({required this.plan});

  final GuestOnboardingDraft plan;

  @override
  Widget build(BuildContext context) {
    final items = plan.selectedCategoryKeys.length;
    final line = [
      plan.planName?.trim() ?? '',
      plan.city?.trim() ?? '',
      if (items > 0)
        arabicCount(
          items,
          one: 'بند واحد',
          two: 'بندين',
          few: 'بنود',
          many: 'بند',
        ),
    ].where((part) => part.isNotEmpty).join(' · ');
    return JourneyNote(text: line, icon: LucideIcons.checkCircle2);
  }
}
