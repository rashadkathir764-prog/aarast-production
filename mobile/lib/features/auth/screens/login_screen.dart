import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
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

  /// After a submit showed errors, fields re-check as they are edited.
  bool _submitAttempted = false;

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

    return AuthWeddingScaffold(
      maxWidth: 460,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      contentAlignment: Alignment.topCenter,
      child: Form(
        key: _formKey,
        autovalidateMode: _submitAttempted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: LoginExperience(
          phoneController: _phoneController,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          isSubmitting: auth.isSubmitting,
          errorMessage: auth.errorMessage,
          onSubmit: _submit,
          onRequestOtp: _requestLoginOtp,
          onResetPassword: _openResetPassword,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onRegister: () {
            if (auth.isSubmitting) return;
            auth.clearError();
            final resume = _safeResumeLocation(context);
            context.go(_withResume(AppRouter.register, resumeLocation: resume));
          },
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
    if (!_submitAttempted) setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      successLocation: _safeResumeLocation(context),
    );

    if (!mounted) return;

    if (success) {
      return;
    }

    // The backend emits this code only after the application password matched
    // an active account. Continue the same login attempt through phone proof;
    // invalid credentials must never trigger an OTP or reveal account state.
    if (auth.errorCode == 'PHONE_VERIFICATION_REQUIRED') {
      await _requestLoginOtp();
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

/// العرض الإنتاجي لشاشة الدخول، منفصل عن المصادقة والتنقل حتى تستخدمه
/// المعاينة البصرية نفسها ولا تنحرف عن الشاشة الفعلية.
class LoginExperience extends StatelessWidget {
  const LoginExperience({
    required this.phoneController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onRequestOtp,
    required this.onResetPassword,
    required this.onTogglePassword,
    required this.onRegister,
    this.errorMessage,
    super.key,
  });

  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final VoidCallback onRequestOtp;
  final VoidCallback onResetPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LoginTopBar(),
        const SizedBox(height: AarastV3Space.x8),
        const _LoginNarrative(),
        const SizedBox(height: AarastV3Space.x6),
        AuthPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: AarastV3Space.x1,
            vertical: AarastV3Space.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AarastV3Color.primarySoft,
                      borderRadius: BorderRadius.circular(
                        AarastV3Radius.control,
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.keyRound,
                      size: 17,
                      color: AarastV3Color.primary,
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'بيانات الدخول',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'رقمك وكلمة المرور فقط',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x3),
              AuthTextField(
                controller: phoneController,
                label: 'رقم الهاتف',
                hint: '77xxxxxxx',
                icon: LucideIcons.phone,
                compact: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: AarastV3Space.x2),
              AuthTextField(
                controller: passwordController,
                label: 'كلمة المرور',
                icon: LucideIcons.lock,
                compact: true,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                suffixIcon: AuthObscureToggle(
                  obscured: obscurePassword,
                  onPressed: onTogglePassword,
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'كلمة المرور مطلوبة'
                    : null,
              ),
              _LoginRecoveryRow(
                onResetPassword: onResetPassword,
                textStyle: textTheme.bodySmall,
              ),
              if (errorMessage != null) ...[
                AuthInlineError(message: errorMessage!),
                const SizedBox(height: AarastV3Space.x3),
              ],
              AarastButton(
                label: 'تسجيل الدخول',
                icon: LucideIcons.logIn,
                isLoading: isSubmitting,
                compact: true,
                onPressed: onSubmit,
              ),
              const SizedBox(height: AarastV3Space.x3),
              const _InlineDivider(label: 'أو بدون كلمة مرور'),
              const SizedBox(height: AarastV3Space.x3),
              OutlinedButton.icon(
                key: const ValueKey('login-otp-action'),
                onPressed: isSubmitting ? null : onRequestOtp,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AarastV3Space.x4,
                    vertical: AarastV3Space.x2,
                  ),
                  foregroundColor: AarastV3Color.ink,
                  backgroundColor: AarastV3Color.paper,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: AarastV3Color.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AarastV3Radius.surface),
                  ),
                ),
                icon: const Icon(LucideIcons.messageCircle, size: 19),
                label: const Text('الدخول برمز واتساب'),
              ),
              const SizedBox(height: AarastV3Space.x2),
              Text(
                'لن نرسل الرمز إلا بعد طلبك.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AarastV3Space.x4),
        _RegisterPrompt(onTap: isSubmitting ? null : onRegister),
      ],
    );
  }
}

class _LoginTopBar extends StatelessWidget {
  const _LoginTopBar();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AarastV3Space.x4,
      runSpacing: AarastV3Space.x2,
      children: [
        const AuthBrandMark(compact: true),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AarastV3Color.paperQuiet,
            borderRadius: BorderRadius.circular(AarastV3Radius.pill),
            border: Border.all(color: AarastV3Color.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 15,
                color: AarastV3Color.mint,
              ),
              const SizedBox(width: AarastV3Space.x2),
              Text('دخول آمن', style: AarastV3Type.label(context)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginRecoveryRow extends StatelessWidget {
  const _LoginRecoveryRow({
    required this.onResetPassword,
    required this.textStyle,
  });

  final VoidCallback onResetPassword;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final trust = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          LucideIcons.shieldCheck,
          size: 16,
          color: AarastV3Color.mint,
        ),
        const SizedBox(width: AarastV3Space.x2),
        Flexible(
          child: Text(
            'دخول آمن إلى مساحتك الخاصة',
            style: textStyle?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    final reset = TextButton(
      key: const ValueKey('login-forgot-password-action'),
      onPressed: onResetPassword,
      child: const Text('نسيت كلمة المرور؟'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 330 || textScale > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              trust,
              Align(alignment: Alignment.centerLeft, child: reset),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: trust),
            reset,
          ],
        );
      },
    );
  }
}

class _LoginNarrative extends StatelessWidget {
  const _LoginNarrative();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: AarastV3Space.x4),
      decoration: const BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: AarastV3Color.signal, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مرحبًا بعودتك',
            style: AarastV3Type.label(
              context,
            ).copyWith(color: AarastV3Color.primary),
          ),
          const SizedBox(height: AarastV3Space.x2),
          Text('خطتك بانتظارك.', style: AarastV3Type.display(context)),
          const SizedBox(height: AarastV3Space.x2),
          Text(
            'تابع المهام والضيوف والمصاريف من آخر نقطة.',
            style: AarastV3Type.body(context),
          ),
        ],
      ),
    );
  }
}

/// فاصل هادئ مع كلمة في المنتصف.
class _InlineDivider extends StatelessWidget {
  const _InlineDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppTheme.border)),
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppTheme.border)),
      ],
    );
  }
}

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      key: const ValueKey('login-register-action'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          vertical: AarastV3Space.x1,
          horizontal: AarastV3Space.x3,
        ),
        decoration: BoxDecoration(
          color: AarastV3Color.paperQuiet,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Text.rich(
          textAlign: TextAlign.center,
          TextSpan(
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
            children: [
              const TextSpan(text: 'ليس لديك حساب؟  '),
              TextSpan(
                text: 'إنشاء حساب',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.brand,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
