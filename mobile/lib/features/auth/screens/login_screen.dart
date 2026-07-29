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
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;

    return AuthWeddingScaffold(
      padding: EdgeInsets.zero,
      maxWidth: double.infinity,
      useSafeArea: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoyalHero(topInset: topInset),
          Transform.translate(
            offset: const Offset(0, -26),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radius2xl),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.ink.withValues(alpha: 0.06),
                    blurRadius: 26,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(22, 28, 22, 26 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'تسجيل الدخول',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
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
                      const SizedBox(height: 26),
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
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
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
                        child: InkWell(
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
                                color: AppTheme.goldDeep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
                      const SizedBox(height: 18),
                      const _GoldDivider(label: 'أو'),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: auth.isSubmitting ? null : _requestLoginOtp,
                        icon: const Icon(LucideIcons.messageCircle, size: 20),
                        label: const Text('الدخول برمز عبر واتساب'),
                      ),
                      const SizedBox(height: 22),
                      _RegisterPrompt(
                        onTap: () {
                          if (auth.isSubmitting) return;
                          auth.clearError();
                          final resume = _safeResumeLocation(context);
                          context.go(
                            _withResume(
                              AppRouter.register,
                              resumeLocation: resume,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
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
              ),
            ),
          ),
        ],
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

    if (!mounted) return;

    if (success) {
      context.go(AppRouter.authenticatedEntry(_safeResumeLocation(context)));
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

/// ترويسة ملكية عريضة تملأ أعلى الشاشة — تدرّج بورجندي مع توهّج ذهبي
/// وحلقات عروسية خافتة، وشعار "أعرسِت" داخل ميدالية ذهبية.
class _RoyalHero extends StatelessWidget {
  const _RoyalHero({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ClipRect(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: topInset - 34,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.gold.withValues(alpha: 0.30),
                      AppTheme.gold.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.68],
                  ),
                ),
              ),
            ),
            Positioned(
              top: topInset - 4,
              child: _RingOutline(size: 224, opacity: 0.16),
            ),
            Positioned(
              top: topInset + 26,
              child: _RingOutline(size: 150, opacity: 0.12),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: topInset + 44,
                bottom: 48,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Monogram(),
                  const SizedBox(height: 18),
                  Text(
                    'أعرسِت',
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall?.copyWith(
                      fontFamily: AppTheme.displayFontFamily,
                      color: AppTheme.goldGlow,
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'خطّط لزفافك من مكان واحد بثقة وذوق.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.goldGlow.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingOutline extends StatelessWidget {
  const _RingOutline({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.goldLight.withValues(alpha: opacity),
          width: 1,
        ),
      ),
    );
  }
}

/// ميدالية الشعار — حلقة ذهبية متوهّجة تحيط بقلب على قرص ذهبي.
class _Monogram extends StatelessWidget {
  const _Monogram();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: AppTheme.goldLight.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.35),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.goldLight, AppTheme.gold],
            ),
          ),
          child: const Icon(
            LucideIcons.heart,
            color: AppTheme.burgundyDark,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// فاصل بلمسة ذهبية خافتة مع كلمة في المنتصف.
class _GoldDivider extends StatelessWidget {
  const _GoldDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.border, Colors.transparent],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppTheme.border],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text.rich(
          textAlign: TextAlign.center,
          TextSpan(
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
            children: [
              const TextSpan(text: 'ليس لديك حساب؟  '),
              TextSpan(
                text: 'إنشاء حساب',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.burgundy,
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
