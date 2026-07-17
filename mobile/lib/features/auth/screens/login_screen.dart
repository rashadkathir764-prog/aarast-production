import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_wedding_widgets.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({this.initialPhone, super.key});

  final String? initialPhone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone?.trim() ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final textTheme = Theme.of(context).textTheme;

    return AuthWeddingScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const AuthBrandMark(compact: true),
            const SizedBox(height: 26),
            Text(
              'تسجيل الدخول',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ادخل بحسابك لمتابعة تنظيم زفافك بسهولة.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            AuthPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
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
                  const SizedBox(height: 14),
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          onPressed: auth.isSubmitting
                              ? null
                              : _requestLoginOtp,
                          child: const Text('الدخول برمز تحقق'),
                        ),
                        InkWell(
                          key: const ValueKey('login-forgot-password-action'),
                          onTap: _openResetPassword,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Text(
                              'نسيت كلمة المرور؟',
                              style: textTheme.labelMedium?.copyWith(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AuthInlineError(message: auth.errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  AarastButton(
                    label: 'تسجيل الدخول',
                    icon: LucideIcons.logIn,
                    isLoading: auth.isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AuthFooterLink(
              prefix: 'ليس لديك حساب؟',
              action: 'إنشاء حساب',
              onTap: () {
                if (auth.isSubmitting) return;
                auth.clearError();
                final resume = _safeResumeLocation(context);
                context.go(
                  _withResume(AppRouter.register, resumeLocation: resume),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'أعرسِت يساعدك على ترتيب الميزانية والتكاليف والمهام والمشاركات من مكان واحد.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openResetPassword() {
    final phone = _phoneController.text.trim();
    final resume = _safeResumeLocation(context);
    final location = Uri.parse(AppRouter.resetPassword)
        .replace(
          queryParameters: {
            if (phone.isNotEmpty) 'phone': phone,
            'resume': ?resume,
          },
        )
        .toString();
    context.push(location);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      final defaultLocation = auth.user?.isProviderAccount == true
          ? AppRouter.providerDashboard
          : AppRouter.home;
      context.go(_safeResumeLocation(context) ?? defaultLocation);
    }
  }

  Future<void> _requestLoginOtp() async {
    final phoneInput = _phoneController.text.trim();
    if (!isValidYemeniPhoneInput(phoneInput)) {
      AarastToast.showError(context, 'أدخل رقم هاتف صحيح أولًا.');
      return;
    }

    final auth = context.read<AuthController>();
    final phone = normalizeYemeniPhone(phoneInput);
    final otp = await auth.requestOtp(phone: phone, purpose: 'LOGIN');
    if (otp == null || !mounted) return;

    context.go(
      AppRouter.otp,
      extra: OtpScreenArgs(
        phone: phone,
        purpose: 'LOGIN',
        otpNoticeMessage: otp.noticeMessage,
        successLocation: _safeResumeLocation(context),
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
