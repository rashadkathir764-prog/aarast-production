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
import '../../marketplace/providers/marketplace_provider.dart';
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
    AarastToast.showSuccess(context, 'تم إعادة إرسال الرمز');
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
    final success = registration == null
        ? await auth.verifyOtp(phone: phone, purpose: purpose, code: code)
        : await auth.register(
            name: registration.name,
            phone: registration.phone,
            email: registration.email,
            password: registration.password,
            otpCode: code,
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
    if (!mounted) return;

    final providerApplication = registration?.providerApplication;
    if (providerApplication != null) {
      final provider = context.read<ProviderDashboardProvider>();
      final applied = await provider.applyProvider(
        businessName: providerApplication.businessName,
        phone: providerApplication.phone,
        cityId: providerApplication.cityId,
        categoryIds: [providerApplication.categoryId],
        description: providerApplication.description,
      );
      if (!mounted) return;
      if (applied) {
        await auth.refreshCurrentUser();
        if (!mounted) return;
        context.go(AppRouter.providerApplyStatus);
        return;
      }

      AarastToast.showError(
        context,
        'تم إنشاء الحساب وتوثيق الرقم، لكن تعذر إرسال طلب المزود. يمكنك إعادة الطلب من حسابك.',
      );
    }

    final defaultLocation = auth.user?.isProviderAccount == true
        ? AppRouter.providerDashboard
        : AppRouter.home;
    context.go(widget.successLocation ?? defaultLocation);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.register);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthController>();
    final otpNoticeMessage =
        _otpNoticeMessage ?? auth.otpRequest?.noticeMessage;

    return AuthWeddingScaffold(
      leading: AuthBackButton(onPressed: _goBack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'تأكيد رقم الهاتف',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'أدخل رمز التحقق المرسل إلى رقم هاتفك\nلإكمال إعداد الحساب.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
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
                        AarastButton(
                          label: 'تأكيد الرمز',
                          icon: LucideIcons.badgeCheck,
                          isLoading: _isVerifying || auth.isSubmitting,
                          onPressed: _verifyOtp,
                        ),
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
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.ink,
          fontWeight: FontWeight.w900,
          height: 1.4,
        ),
      ),
    );
  }
}
