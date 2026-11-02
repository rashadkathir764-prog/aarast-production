import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart' show AarastScreenFrame;
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingDraft, GuestOnboardingStorage, GuestPersona;
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';
import 'otp_screen.dart';

/// «احفظ خطتك» (D75): the plan kept on this phone is saved with the number
/// and a WhatsApp code, nothing else. The screen wears the plan's colour and
/// speaks in its owner's words. A provider's account is
/// [ProviderRegisterScreen].
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({this.initialPhone, super.key});

  final String? initialPhone;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  /// After a send showed errors, each field re-checks as it is edited.
  bool _submitAttempted = false;

  /// The plan kept on the phone, which this account will save.
  GuestOnboardingDraft? _keptPlan;

  /// The name came with the kept plan («عرس محمد»), so it is not asked again.
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
    super.dispose();
  }

  String? get _nameError {
    if (!_submitAttempted || _nameFromPlan) return null;
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'الاسم مطلوب';
    if (name.length < 3) return 'الاسم قصير جداً';
    return null;
  }

  String? get _phoneError {
    if (!_submitAttempted) return null;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return 'رقم الجوال مطلوب';
    if (!isValidYemeniPhoneInput(phone)) return 'رقم الجوال غير صحيح';
    return null;
  }

  void _edited() {
    final auth = context.read<AuthController>();
    if (auth.errorMessage != null) auth.clearError();
    if (_submitAttempted) setState(() {});
  }

  void _back() {
    context.read<AuthController>().clearError();
    if (context.canPop()) {
      context.pop();
    } else if (_keptPlan != null) {
      context.go(AppRouter.home);
    } else {
      context.go(AppRouter.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keptPlan = _keptPlan;
    final persona = keptPlan?.persona == GuestPersona.bride ? 'BRIDE' : 'GROOM';
    return JourneyProfileScope(
      profile: JourneyProfile.fromPersona(persona),
      child: Builder(builder: (context) => _page(context, keptPlan)),
    );
  }

  Widget _page(BuildContext context, GuestOnboardingDraft? keptPlan) {
    final auth = context.watch<AuthController>();
    final offline = auth.failedOffline;
    final serverError = offline ? null : auth.errorMessage;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      child: JourneyPage(
        bottom: JourneyEntryActions(
          above: serverError == null
              ? null
              : JourneyNote(
                  text: serverError,
                  icon: LucideIcons.alertCircle,
                  color: AarastV3Color.danger,
                  soft: AarastV3Color.dangerSoft,
                ),
          primary: JourneyButton(
            key: const ValueKey('register-submit'),
            label: offline ? 'أرسل الرمز مرة ثانية' : 'أرسل الرمز',
            expand: true,
            large: true,
            loading: auth.isSubmitting,
            onPressed: _submit,
          ),
          secondary: offline && keptPlan != null
              ? JourneyEntryLink(
                  label: context.say(
                    'بعدين، خلني أشوف أول',
                    'بعدين، خليني أشوف أول',
                  ),
                  onPressed: () => context.go(AppRouter.home),
                )
              : JourneyEntryLink(
                  key: const ValueKey('register-login'),
                  label: 'عندك حساب؟ تسجيل الدخول',
                  sub: keptPlan == null
                      ? null
                      : context.say(
                          'ولو حسابك فيه خطة، تختار وين تكون هذي',
                          'ولو حسابك فيه خطة، تختارين وين تكون هذي',
                        ),
                  strong: true,
                  onPressed: auth.isSubmitting ? null : _login,
                ),
        ),
        children: [
          JourneyStepBar(onBack: _back),
          if (offline) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyEntryNote(
              key: const ValueKey('register-offline'),
              text: keptPlan == null
                  ? 'ما قدرنا نرسل الرمز، النت مقطوع.'
                  : 'ما قدرنا نرسل الرمز، النت مقطوع. خطتك محفوظة على هذا الجوال.',
              icon: LucideIcons.wifiOff,
              tone: JourneyEntryNoteTone.warn,
            ),
          ],
          JourneyEntryQuestion(
            question: keptPlan != null
                ? context.say('احفظ خطتك', 'احفظي خطتك')
                : 'حساب جديد',
            help: keptPlan != null
                ? context.say(
                    'بحسابك ما تضيع، وتفتحها من أي جوال.',
                    'بحسابك ما تضيع، وتفتحينها من أي جوال.',
                  )
                : 'برقم جوالك ورمز على واتساب.',
          ),
          if (keptPlan != null) ...[
            const SizedBox(height: AarastV3Space.x5),
            JourneyKeptPlanStrip(line: _planLine(keptPlan)),
          ],
          const SizedBox(height: AarastV3Space.x5),
          if (!_nameFromPlan) ...[
            JourneyTextField(
              label: 'اسمك',
              controller: _nameController,
              textInputAction: TextInputAction.next,
              errorText: _nameError,
              onChanged: (_) => _edited(),
            ),
            const SizedBox(height: AarastV3Field.gap),
          ],
          JourneyPhoneField(
            controller: _phoneController,
            errorText: _phoneError,
            onChanged: (_) => _edited(),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AarastV3Space.x3),
          JourneyEntryNote(
            text: context.say(
              'نرسل لك رمز على واتساب. تأكد إن الرقم عليه واتساب.',
              'نرسل لك رمز على واتساب. تأكدي إن الرقم عليه واتساب.',
            ),
            icon: LucideIcons.messageCircle,
          ),
        ],
      ),
    );
  }

  /// «عرس محمد · صنعاء · 12 بند».
  String _planLine(GuestOnboardingDraft plan) {
    final items = plan.selectedCategoryKeys.length;
    return [
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
  }

  void _login() {
    final auth = context.read<AuthController>();
    auth.clearError();
    final resume = _safeResumeLocation(context);
    context.go(_withResume(AppRouter.login, resumeLocation: resume));
  }

  Future<void> _submit() async {
    if (!_submitAttempted) setState(() => _submitAttempted = true);
    if (_nameError != null || _phoneError != null) return;

    final auth = context.read<AuthController>();
    final name = _nameController.text.trim();
    final normalizedPhone = normalizeYemeniPhone(_phoneController.text);
    final otp = await auth.startRegistration(
      name: name,
      phone: normalizedPhone,
    );
    if (otp == null || !mounted) return;

    context.push(
      AppRouter.otp,
      extra: OtpScreenArgs(
        phone: normalizedPhone,
        purpose: 'REGISTER',
        otpNoticeMessage: otp.noticeMessage,
        successLocation: _safeResumeLocation(context),
        registration: PendingRegistration(name: name, phone: normalizedPhone),
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
