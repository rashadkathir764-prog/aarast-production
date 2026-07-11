import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/providers/marketplace_provider.dart';
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_wedding_widgets.dart';

class OtpScreenArgs {
  const OtpScreenArgs({
    required this.phone,
    this.purpose = 'VERIFY_PHONE',
    this.devOtpMessage,
    this.registration,
    this.successLocation,
  });

  final String phone;
  final String purpose;
  final String? devOtpMessage;
  final PendingRegistration? registration;
  final String? successLocation;
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    this.phone,
    this.purpose,
    this.devOtpMessage,
    this.registration,
    this.successLocation,
    super.key,
  });

  final String? phone;
  final String? purpose;
  final String? devOtpMessage;
  final PendingRegistration? registration;
  final String? successLocation;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _codeLength = 6;

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  bool _isVerifying = false;
  String? _devOtpMessage;

  @override
  void initState() {
    super.initState();
    _devOtpMessage = widget.devOtpMessage;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isEmpty) {
      if (index > 0) {
        FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      }
      return;
    }

    if (index < _codeLength - 1) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      return;
    }

    _focusNodes[index].unfocus();
    _verifyOtp();
  }

  Future<void> _verifyOtp() async {
    final code = _controllers.map((controller) => controller.text).join();
    if (code.length < _codeLength || _isVerifying) return;
    final auth = context.read<AuthController>();
    final phone = widget.phone ?? auth.otpRequest?.phone;
    final purpose =
        widget.purpose ?? auth.otpRequest?.purpose ?? 'VERIFY_PHONE';
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلب رمز تحقق جديد للمتابعة.')),
      );
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
      setState(() => _isVerifying = false);
      return;
    }

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنشاء الحساب وتوثيق الرقم، لكن تعذر إرسال طلب المزود. يمكنك إعادة الطلب من حسابك.',
          ),
        ),
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
    final devOtpMessage = _devOtpMessage ?? auth.otpRequest?.localDevMessage;

    return AuthWeddingScaffold(
      leading: AuthBackButton(onPressed: _goBack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const AuthBrandMark(compact: true),
          const SizedBox(height: 24),
          const WeddingRingsBadge(size: 88),
          const SizedBox(height: 24),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (devOtpMessage != null) ...[
                  _DevOtpNotice(message: devOtpMessage),
                  const SizedBox(height: 16),
                ],
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: List.generate(_codeLength, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: index == _codeLength - 1 ? 0 : 6,
                          ),
                          child: SizedBox(
                            height: 58,
                            child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: textTheme.titleLarge?.copyWith(
                                color: AppTheme.burgundyDeep,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLength: 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: AppTheme.surfaceElevated,
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLg,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppTheme.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLg,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppTheme.burgundy,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (value) => _onChanged(value, index),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
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
          const SizedBox(height: 18),
          AuthFooterLink(
            prefix: 'لم تستلم الرمز؟',
            action: 'إعادة الإرسال',
            onTap: () async {
              final authController = context.read<AuthController>();
              final messenger = ScaffoldMessenger.of(context);
              final phone = widget.phone ?? auth.otpRequest?.phone;
              final purpose =
                  widget.purpose ?? auth.otpRequest?.purpose ?? 'VERIFY_PHONE';
              if (phone == null || phone.isEmpty) return;
              final result = await authController.requestOtp(
                phone: phone,
                purpose: purpose,
              );
              if (result == null) return;
              if (result.localDevMessage != null && mounted) {
                setState(() => _devOtpMessage = result.localDevMessage);
              }
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('تم إعادة إرسال الرمز')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DevOtpNotice extends StatelessWidget {
  const _DevOtpNotice({required this.message});

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
