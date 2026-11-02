import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_wedding_widgets.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.initialPhone,
    this.sessionExpired = false,
    super.key,
  });

  final String? initialPhone;

  /// x18: the session expired; the same account signs in again and its
  /// unsent changes are sent (C58).
  final bool sessionExpired;

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

    void register() {
      if (auth.isSubmitting) return;
      auth.clearError();
      final resume = _safeResumeLocation(context);
      context.go(_withResume(AppRouter.register, resumeLocation: resume));
    }

    return AuthWeddingScaffold(
      leading: AuthBackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(AppRouter.welcome),
      ),
      bottom: LoginActions(
        isSubmitting: auth.isSubmitting,
        onSubmit: _submit,
        onRequestOtp: _requestLoginOtp,
        onRegister: register,
      ),
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
          // x18's heading already says why; the expiry line returns only
          // with an error from a new attempt.
          errorMessage: widget.sessionExpired && !_submitAttempted
              ? null
              : auth.errorMessage,
          onSubmit: _submit,
          onRequestOtp: _requestLoginOtp,
          onResetPassword: _openResetPassword,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onRegister: register,
          showActions: false,
          sessionExpired: widget.sessionExpired,
          pendingChanges: widget.sessionExpired ? _pendingChanges() : 0,
        ),
      ),
    );
  }

  int _pendingChanges() {
    try {
      return context.watch<OfflineSyncService>().pendingCount;
    } on ProviderNotFoundException {
      return 0;
    }
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

/// The sign-in form (prototype a10), apart from sign-in and navigation so
/// the visual preview renders the real screen. With [showActions] false the
/// screen holds the actions at the bottom through [LoginActions].
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
    this.showActions = true,
    this.sessionExpired = false,
    this.pendingChanges = 0,
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
  final bool showActions;
  final bool sessionExpired;
  final int pendingChanges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuthBrandMark(compact: true),
        ),
        const SizedBox(height: 18),
        AuthHeading(
          title: sessionExpired
              ? context.say('ادخل مرة ثانية', 'ادخلي مرة ثانية')
              : 'أهلًا من جديد',
          subtitle: sessionExpired
              ? context.say(
                  'طال غيابك، فقفلنا الدخول لأمانك. ادخل وترجع مكانك.',
                  'طال غيابك، فقفلنا الدخول لأمانك. ادخلي وترجعين مكانك.',
                )
              : 'كل شي محفوظ، مثل ما تركته.',
        ),
        if (pendingChanges > 0) ...[
          const SizedBox(height: 16),
          JourneyBox(
            padding: EdgeInsets.zero,
            child: JourneyListRow(
              icon: LucideIcons.cloudOff,
              color: AarastV3Color.brandAccentStrong,
              soft: AarastV3Color.brandAccentSoft,
              title: arabicCount(
                pendingChanges,
                one: 'شي واحد سجّلته بدون نت',
                two: 'شيئين سجّلتها بدون نت',
                few: 'أشياء سجّلتها بدون نت',
                many: 'شي سجّلته بدون نت',
              ),
              subtitle: 'محفوظة في جوالك، وتوصل أول ما تدخل بنفس الحساب',
            ),
          ),
        ],
        const SizedBox(height: 16),
        AuthTextField(
          controller: phoneController,
          label: 'رقم الهاتف',
          hint: '777 123 456',
          icon: LucideIcons.phone,
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
        const SizedBox(height: 10),
        AuthTextField(
          controller: passwordController,
          label: 'كلمة المرور',
          icon: LucideIcons.lock,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          suffixIcon: AuthObscureToggle(
            obscured: obscurePassword,
            onPressed: onTogglePassword,
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'كلمة المرور مطلوبة' : null,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: JourneyTextAction(
            key: const ValueKey('login-forgot-password-action'),
            label: context.say('نسيت كلمة المرور؟', 'نسيتِ كلمة المرور؟'),
            color: context.accent.primary,
            onPressed: onResetPassword,
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 4),
          AuthInlineError(message: errorMessage!),
        ],
        if (showActions) ...[
          const SizedBox(height: 20),
          LoginActions(
            isSubmitting: isSubmitting,
            onSubmit: onSubmit,
            onRequestOtp: onRequestOtp,
            onRegister: onRegister,
          ),
        ],
      ],
    );
  }
}

/// a10's actions: sign in, or a WhatsApp code without a password, or a
/// new account.
class LoginActions extends StatelessWidget {
  const LoginActions({
    required this.isSubmitting,
    required this.onSubmit,
    required this.onRequestOtp,
    required this.onRegister,
    super.key,
  });

  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onRequestOtp;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyButton(
          key: const ValueKey('login-submit'),
          label: 'تسجيل الدخول',
          expand: true,
          large: true,
          loading: isSubmitting,
          onPressed: onSubmit,
        ),
        const SizedBox(height: 10),
        const _InlineDivider(label: 'أو بدون كلمة مرور'),
        const SizedBox(height: 10),
        JourneyButton(
          key: const ValueKey('login-otp-action'),
          label: 'الدخول برمز واتساب',
          icon: LucideIcons.messageCircle,
          background: AarastV3Color.mintSoft,
          foreground: AarastV3Color.mint,
          expand: true,
          large: true,
          onPressed: isSubmitting ? null : onRequestOtp,
        ),
        AuthFooterLink(
          key: const ValueKey('login-register-action'),
          prefix: 'ما عندك حساب؟',
          action: 'أنشئ حساب',
          onTap: isSubmitting ? null : onRegister,
        ),
      ],
    );
  }
}

/// A quiet rule with a word in its middle.
class _InlineDivider extends StatelessWidget {
  const _InlineDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AarastV3Color.line)),
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        ),
        const Expanded(child: Divider(color: AarastV3Color.line)),
      ],
    );
  }
}
