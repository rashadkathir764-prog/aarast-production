import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_otp_field.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../provider_portal/provider_portal_api.dart'
    show ProviderDashboardProvider;
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_wedding_widgets.dart';

class OtpScreenArgs {
  const OtpScreenArgs({
    required this.phone,
    this.purpose = 'VERIFY_PHONE',
    this.otpNoticeMessage,
    this.registration,
    this.successLocation,
  });

  final String phone;
  final String purpose;
  final String? otpNoticeMessage;
  final PendingRegistration? registration;
  final String? successLocation;
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    this.phone,
    this.purpose,
    this.otpNoticeMessage,
    this.registration,
    this.successLocation,
    super.key,
  });

  final String? phone;
  final String? purpose;
  final String? otpNoticeMessage;
  final PendingRegistration? registration;
  final String? successLocation;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _codeLength = 6;
  static const _resendCooldown = 60;

  final TextEditingController _codeController = TextEditingController();

  bool _isVerifying = false;
  AarastOtpFieldState _fieldState = AarastOtpFieldState.idle;
  String? _otpNoticeMessage;
  Timer? _resendTimer;
  int _resendSeconds = _resendCooldown;

  @override
  void initState() {
    super.initState();
    _otpNoticeMessage = widget.otpNoticeMessage;
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown({bool notify = false}) {
    _resendTimer?.cancel();
    if (notify && mounted) {
      setState(() => _resendSeconds = _resendCooldown);
    } else {
      _resendSeconds = _resendCooldown;
    }
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    final authController = context.read<AuthController>();
    if (authController.isSubmitting) return;
    final phone = widget.phone ?? authController.otpRequest?.phone;
    final purpose =
        widget.purpose ?? authController.otpRequest?.purpose ?? 'VERIFY_PHONE';
    if (phone == null || phone.isEmpty) return;
    final result = await authController.requestOtp(
      phone: phone,
      purpose: purpose,
    );
    if (!mounted || result == null) return;
    _codeController.clear();
    setState(() {
      _fieldState = AarastOtpFieldState.idle;
      _otpNoticeMessage = result.noticeMessage;
    });
    _startResendCooldown(notify: true);
    if (result.isDeliveryConfirmed) {
      AarastToast.showSuccess(context, 'تم تسليم الرمز إلى واتساب');
    } else {
      AarastToast.showInfo(
        context,
        'طلبنا إعادة الإرسال، لكن لم نتأكد من وصول الرمز بعد.',
      );
    }
  }

  void _onCodeChanged(String value) {
    if (value.isEmpty) return;
    if (_fieldState == AarastOtpFieldState.error) {
      setState(() => _fieldState = AarastOtpFieldState.idle);
    }
    final auth = context.read<AuthController>();
    if (auth.errorMessage != null) auth.clearError();
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text;
    if (code.length < _codeLength || _isVerifying) return;
    final auth = context.read<AuthController>();
    final phone = widget.phone ?? auth.otpRequest?.phone;
    final purpose =
        widget.purpose ?? auth.otpRequest?.purpose ?? 'VERIFY_PHONE';
    if (phone == null || phone.isEmpty) {
      AarastToast.showInfo(context, 'اطلب رمز تحقق جديد للمتابعة.');
      return;
    }

    setState(() => _isVerifying = true);
    final registration = widget.registration;
    final providerApplication = registration?.providerApplication;
    final provider = providerApplication == null
        ? null
        : context.read<ProviderDashboardProvider>();
    final success = registration == null
        ? await auth.verifyOtp(
            phone: phone,
            purpose: purpose,
            code: code,
            successLocation: widget.successLocation,
          )
        : await auth.register(
            name: registration.name,
            phone: registration.phone,
            password: registration.password,
            otpCode: code,
            resumeInviteToken: _privateInviteTokenFromLocation(
              widget.successLocation,
            ),
            successLocation: widget.successLocation,
            afterSessionEstablished: providerApplication == null
                ? null
                : () async {
                    final applied = await provider!.applyProvider(
                      businessName: providerApplication.businessName,
                      phone: providerApplication.phone,
                      cityId: providerApplication.cityId,
                      categoryIds: [providerApplication.categoryId],
                      description: providerApplication.description,
                    );
                    if (!applied && mounted) {
                      AarastToast.showError(
                        context,
                        'تم إنشاء الحساب وتوثيق الرقم، لكن تعذر إرسال طلب المزود. يمكنك إعادة الطلب من حسابك.',
                      );
                    }
                    return applied ? AppRouter.providerApplyStatus : null;
                  },
          );

    if (!mounted) return;
    if (!success) {
      setState(() {
        _isVerifying = false;
        _fieldState = AarastOtpFieldState.error;
      });
      return;
    }

    // نجاح: لوحة تأكيد قصيرة قبل المتابعة (تُتخطى مع تقليل الحركة).
    setState(() => _fieldState = AarastOtpFieldState.success);
    await Future<void>.delayed(AarastOtpField.successHold(context));
  }

  void _goBack() {
    final auth = context.read<AuthController>();
    final phone = widget.phone ?? auth.otpRequest?.phone ?? '';
    final purpose =
        widget.purpose ?? auth.otpRequest?.purpose ?? 'VERIFY_PHONE';
    auth.clearError();
    if (context.canPop()) {
      context.pop();
      return;
    }
    final destination = widget.registration != null || purpose == 'REGISTER'
        ? AppRouter.register
        : AppRouter.login;
    context.go(
      _authLocation(
        destination,
        phone: phone,
        resumeLocation: widget.successLocation,
      ),
    );
  }

  void _goToLogin(String phone) {
    context.read<AuthController>().clearError();
    context.go(
      _authLocation(
        AppRouter.login,
        phone: phone,
        resumeLocation: widget.successLocation,
      ),
    );
  }

  void _goToPasswordReset(String phone) {
    context.read<AuthController>().clearError();
    context.go(
      _authLocation(
        AppRouter.resetPassword,
        phone: phone,
        resumeLocation: widget.successLocation,
      ),
    );
  }

  void _goToRegistration(String phone) {
    context.read<AuthController>().clearError();
    context.go(
      _authLocation(
        AppRouter.register,
        phone: phone,
        resumeLocation: widget.successLocation,
      ),
    );
  }

  String _authLocation(
    String location, {
    required String phone,
    String? resumeLocation,
  }) {
    return Uri.parse(location)
        .replace(
          queryParameters: {
            if (phone.isNotEmpty) 'phone': phone,
            if (_isSafeInternalLocation(resumeLocation))
              'resume': resumeLocation,
          },
        )
        .toString();
  }

  bool _isSafeInternalLocation(String? location) {
    return location != null &&
        location.startsWith('/') &&
        !location.startsWith('//');
  }

  String? _privateInviteTokenFromLocation(String? location) {
    if (!_isSafeInternalLocation(location)) return null;
    final uri = Uri.tryParse(location!);
    if (uri == null ||
        uri.hasAuthority ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'invites') {
      return null;
    }
    final token = uri.pathSegments.last.trim();
    return token.isEmpty ? null : token;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthController>();
    final otpNoticeMessage =
        _otpNoticeMessage ?? auth.otpRequest?.noticeMessage;
    final phone = widget.phone ?? auth.otpRequest?.phone ?? '';
    final purpose =
        widget.purpose ?? auth.otpRequest?.purpose ?? 'VERIFY_PHONE';
    final isRegistration = widget.registration != null || purpose == 'REGISTER';
    final deliveryLead = auth.otpRequest?.isLocalDev == true
        ? 'أدخل رمز التجربة الظاهر أدناه'
        : auth.otpRequest?.isDeliveryConfirmed == true
        ? 'أدخل رمز التحقق الذي تم تسليمه إلى واتساب'
        : 'أدخل رمز التحقق إذا وصلك عبر واتساب';
    final heading = isRegistration
        ? 'تأكيد رقم الهاتف'
        : purpose == 'LOGIN'
        ? 'تسجيل الدخول برمز التحقق'
        : 'تأكيد ملكية رقم الهاتف';
    final subtitle = isRegistration
        ? '$deliveryLead\nلإكمال إعداد الحساب.'
        : purpose == 'LOGIN'
        ? '$deliveryLead\nلتسجيل الدخول إلى حسابك.'
        : '$deliveryLead\nلتأكيد ملكية الرقم.';
    final existingAccount =
        auth.errorCode == 'ACCOUNT_ALREADY_EXISTS' ||
        auth.errorCode == 'ADMIN_APP_PASSWORD_ALREADY_SET';
    final missingAccountAfterProof =
        auth.errorCode == 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF';
    final disabledAccountAfterProof =
        auth.errorCode == 'ACCOUNT_DISABLED_AFTER_PHONE_PROOF';

    return AuthWeddingScaffold(
      leading: AuthBackButton(onPressed: _goBack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          AuthPanel(
            // عند نجاح الرمز تتحوّل البطاقة كاملة إلى لوحة ✓ الخضراء.
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              child: _fieldState == AarastOtpFieldState.success
                  ? const AarastOtpSuccessPanel()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (otpNoticeMessage != null) ...[
                          _OtpNotice(message: otpNoticeMessage),
                          const SizedBox(height: 16),
                        ],
                        AarastOtpField(
                          controller: _codeController,
                          length: _codeLength,
                          state: _fieldState,
                          enabled: !_isVerifying,
                          fieldKey: const Key('otp-code-field'),
                          onChanged: _onCodeChanged,
                          onCompleted: (_) => _verifyOtp(),
                        ),
                        const SizedBox(height: 22),
                        if (auth.errorMessage != null) ...[
                          AuthInlineError(message: auth.errorMessage!),
                          const SizedBox(height: 14),
                        ],
                        if (existingAccount) ...[
                          AarastButton(
                            key: const ValueKey('otp-go-to-login'),
                            label: 'الانتقال إلى تسجيل الدخول',
                            icon: LucideIcons.logIn,
                            onPressed: phone.isEmpty
                                ? null
                                : () => _goToLogin(phone),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            key: const ValueKey('otp-go-to-password-reset'),
                            onPressed: phone.isEmpty
                                ? null
                                : () => _goToPasswordReset(phone),
                            icon: const Icon(LucideIcons.keyRound, size: 18),
                            label: const Text('نسيت كلمة المرور؟'),
                          ),
                        ] else if (missingAccountAfterProof) ...[
                          AarastButton(
                            key: const ValueKey('otp-go-to-register'),
                            label: 'إنشاء حساب',
                            icon: LucideIcons.userPlus,
                            onPressed: phone.isEmpty
                                ? null
                                : () => _goToRegistration(phone),
                          ),
                        ] else if (disabledAccountAfterProof) ...[
                          AarastButton(
                            key: const ValueKey('otp-disabled-go-to-login'),
                            label: 'العودة إلى تسجيل الدخول',
                            icon: LucideIcons.arrowRight,
                            onPressed: phone.isEmpty
                                ? null
                                : () => _goToLogin(phone),
                          ),
                        ] else ...[
                          AarastButton(
                            label: 'تأكيد الرمز',
                            icon: LucideIcons.badgeCheck,
                            isLoading: _isVerifying || auth.isSubmitting,
                            onPressed: _verifyOtp,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),
          AuthFooterLink(
            key: const ValueKey('otp-resend-button'),
            prefix: 'لم تستلم الرمز؟',
            action: _resendSeconds > 0
                ? 'إعادة الإرسال خلال $_resendSeconds ث'
                : 'إعادة الإرسال',
            onTap: _resendSeconds > 0 || auth.isSubmitting ? null : _resendOtp,
          ),
        ],
      ),
    );
  }
}

class _OtpNotice extends StatelessWidget {
  const _OtpNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
          height: 1.4,
        ),
      ),
    );
  }
}
