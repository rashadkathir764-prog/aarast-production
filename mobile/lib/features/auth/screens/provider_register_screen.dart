import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart' show AarastScreenFrame;
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';
import 'otp_screen.dart';

/// «استقبال طلبات العرسان» (D75): the provider's own account, a name and
/// a number, then a WhatsApp code; no password. The business and its prices
/// are the four joining steps after the code, so nothing about the business
/// is sent here. Before the choice of a plan, the words fit anyone.
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
    super.dispose();
  }

  String? get _nameError {
    if (!_submitAttempted) return null;
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'الاسم مطلوب';
    return null;
  }

  String? get _phoneError {
    if (!_submitAttempted) return null;
    return yemeniPhoneInputError(_phoneController.text);
  }

  /// The app's own colour and neutral words come from its route (D75).
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final offline = auth.failedOffline;
    final error = auth.errorMessage;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      child: JourneyPage(
        bottom: JourneyEntryActions(
          above: error == null
              ? null
              : JourneyNote(
                  key: const Key('provider-register-error'),
                  text: offline ? 'ما قدرنا نرسل الرمز، النت مقطوع.' : error,
                  icon: offline ? LucideIcons.wifiOff : LucideIcons.alertCircle,
                  color: AarastV3Color.danger,
                  soft: AarastV3Color.dangerSoft,
                ),
          primary: JourneyButton(
            key: const Key('provider-register-submit'),
            label: offline ? 'أرسل الرمز مرة ثانية' : 'أرسل الرمز',
            expand: true,
            large: true,
            loading: auth.isSubmitting,
            onPressed: _submit,
          ),
          secondary: JourneyEntryLink(
            key: const Key('provider-register-login'),
            label: 'عندك حساب في اعّرست؟ تسجيل الدخول',
            strong: true,
            onPressed: auth.isSubmitting ? null : _login,
          ),
        ),
        children: [
          JourneyStepBar(onBack: _back),
          const JourneyEntryQuestion(
            question: 'استقبال طلبات العرسان',
            help: 'مكان لنشاطك في اعّرست، توصل منه طلبات عروض الأسعار.',
          ),
          const SizedBox(height: AarastV3Space.x5),
          JourneyTextField(
            key: const Key('provider-register-name'),
            label: 'الاسم',
            hint: 'اسمك',
            controller: _nameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            helper: 'اسم النشاط في الخطوة الجاية',
            helperColor: AarastV3Color.textMuted,
            errorText: _nameError,
            onChanged: _edited,
          ),
          const SizedBox(height: AarastV3Field.gap),
          JourneyPhoneField(
            key: const Key('provider-register-phone'),
            controller: _phoneController,
            errorText: _phoneError,
            onChanged: _edited,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AarastV3Space.x4),
          const JourneyBox(child: _JoiningSteps()),
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
    if (_nameError != null || _phoneError != null) return;
    final auth = context.read<AuthController>();
    final name = _nameController.text.trim();
    final phone = normalizeYemeniPhone(_phoneController.text);
    final otp = await auth.startRegistration(name: name, phone: phone);
    if (otp == null || !mounted) return;
    context.push(
      AppRouter.otp,
      extra: OtpScreenArgs(
        phone: phone,
        purpose: 'REGISTER',
        otpNoticeMessage: otp.noticeMessage,
        successLocation: _resumeLocation(),
        registration: PendingRegistration(name: name, phone: phone),
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

/// «بعد رمز واتساب، أربع خطوات»: the joining, as its steps are.
class _JoiningSteps extends StatelessWidget {
  const _JoiningSteps();

  static const _steps = [
    'النشاط ونوعه',
    'مكان العمل',
    'الخدمة وسعرها',
    'معاينة الإعلان وإرساله، ثم المراجعة',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'بعد رمز واتساب، أربع خطوات',
          style: JourneyType.of(
            JourneyType.bodyLarge,
            weight: JourneyType.bold,
          ),
        ),
        const SizedBox(height: AarastV3Space.x2),
        for (final (index, step) in _steps.indexed)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AarastV3Space.x8),
            child: Row(
              children: [
                Container(
                  width: AarastV3Space.x6,
                  height: AarastV3Space.x6,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.accent.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                      color: context.accent.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: AarastV3Space.x3),
                Expanded(
                  child: Text(step, style: JourneyType.of(JourneyType.body)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
