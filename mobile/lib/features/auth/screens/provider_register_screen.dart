import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';
import '../utils/application_password_policy.dart';
import 'otp_screen.dart';

/// p01 «حساب مزود»: the provider's own account, his name, phone and
/// password. The business and its prices are asked after the WhatsApp code,
/// in the joining steps (p03 onwards), so nothing about the business is sent
/// here.
class ProviderRegisterScreen extends StatefulWidget {
  const ProviderRegisterScreen({
    this.initialPhone,
    this.resumeLocation,
    super.key,
  });

  final String? initialPhone;

  /// The provider page that sent the person here, from the route.
  final String? resumeLocation;

  @override
  State<ProviderRegisterScreen> createState() => _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  /// After a press showed errors, each field re-checks as it is edited.
  bool _submitAttempted = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone?.trim() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_submitAttempted) return null;
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'اكتب اسمك';
    if (name.length < 3) return 'الاسم قصير';
    return null;
  }

  String? get _phoneError {
    if (!_submitAttempted) return null;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return 'اكتب رقم هاتفك';
    if (!isValidYemeniPhoneInput(phone)) return 'رقم الهاتف غير صحيح';
    return null;
  }

  String? get _passwordError {
    if (!_submitAttempted) return null;
    final password = _passwordController.text;
    if (password.isEmpty) return 'اكتب كلمة المرور';
    if (password.length < 6) return 'كلمة المرور 6 أحرف أو أكثر';
    if (!isApplicationPasswordWithinByteLimit(password)) {
      return 'كلمة المرور طويلة. اختصرها وجرّب مرة ثانية';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                JourneySubHeader(title: 'حساب مزود', onBack: _back),
                Semantics(
                  header: true,
                  child: Text(
                    'ابدأ استقبال طلبات العرسان',
                    style: JourneyType.of(
                      JourneyType.display,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AarastV3Space.x1),
                Text(
                  'حسابك أنت. نشاطك وأسعارك نسألك عنها بعدين.',
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: AarastV3Space.x4),
                JourneyTextField(
                  key: const Key('provider-register-name'),
                  label: 'اسمك',
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  errorText: _nameError,
                  onChanged: _edited,
                ),
                const SizedBox(height: AarastV3Space.x2),
                JourneyTextField(
                  key: const Key('provider-register-phone'),
                  label: 'رقم الهاتف',
                  controller: _phoneController,
                  icon: LucideIcons.phone,
                  hint: '7XX XXX XXX',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  errorText: _phoneError,
                  onChanged: _edited,
                ),
                const SizedBox(height: AarastV3Space.x2),
                JourneyTextField(
                  key: const Key('provider-register-password'),
                  label: 'كلمة المرور',
                  controller: _passwordController,
                  icon: LucideIcons.lock,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: _passwordError,
                  onChanged: _edited,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AarastV3Space.x3),
                const JourneyNote(
                  text:
                      'بعدها رمز على واتساب. ونفس الرقم تقدر تسوي فيه خطة عرسك بعدين.',
                  icon: LucideIcons.messageCircle,
                ),
                if (auth.errorMessage case final message?) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  JourneyNote(
                    key: const Key('provider-register-error'),
                    text: message,
                    icon: LucideIcons.alertCircle,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                ],
                const SizedBox(height: AarastV3Space.x3),
                Center(
                  child: JourneyTextAction(
                    key: const Key('provider-register-login'),
                    label: 'عندي حساب؟ تسجيل الدخول',
                    color: AarastV3Color.primary,
                    onPressed: auth.isSubmitting ? null : _login,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const Key('provider-register-submit'),
              label: 'إنشاء حساب مزود',
              expand: true,
              large: true,
              loading: auth.isSubmitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  void _edited(String _) {
    final auth = context.read<AuthController>();
    if (auth.errorMessage != null) auth.clearError();
    if (_submitAttempted) setState(() {});
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.welcome);
    }
  }

  void _login() {
    context.read<AuthController>().clearError();
    context.go(
      Uri(
        path: AppRouter.login,
        queryParameters: {'resume': _resumeLocation()},
      ).toString(),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitAttempted = true);
    if (_nameError != null || _phoneError != null || _passwordError != null) {
      return;
    }
    final auth = context.read<AuthController>();
    final name = _nameController.text.trim();
    final phone = normalizeYemeniPhone(_phoneController.text);
    final otp = await auth.startRegistration(
      name: name,
      phone: phone,
      password: _passwordController.text,
    );
    if (otp == null || !mounted) return;
    context.go(
      AppRouter.otp,
      extra: OtpScreenArgs(
        phone: phone,
        purpose: 'REGISTER',
        otpNoticeMessage: otp.noticeMessage,
        successLocation: _resumeLocation(),
        registration: PendingRegistration(
          name: name,
          phone: phone,
          password: _passwordController.text,
        ),
      ),
    );
  }

  /// Where the account lands after the code: the joining (p02 or p03),
  /// unless a provider page sent the person here.
  String _resumeLocation() {
    final resume = widget.resumeLocation;
    if (resume == null ||
        resume.trim().isEmpty ||
        !resume.startsWith('/provider/') ||
        resume.startsWith('//')) {
      return AppRouter.providerApply;
    }
    return resume;
  }
}
