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
    show GuestOnboardingDraft, GuestOnboardingStorage;
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

  /// The last send made the account with a just-proven number (no code),
  /// so a lost connection is about the account, not a code (J1-17).
  bool _creatingWithProof = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Someone already signed in has no account to make here (J1-15).
      final auth = context.read<AuthController>();
      if (auth.status == AuthStatus.authenticated) {
        auth.requestAuthenticatedEntry(_safeResumeLocation(context));
        return;
      }
      _readKeptPlan();
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
      if (_nameController.text.trim().isEmpty && name.isNotEmpty) {
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
    return null;
  }

  String? get _phoneError {
    if (!_submitAttempted) return null;
    return yemeniPhoneInputError(_phoneController.text);
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
    // The kept plan's owner gives the colour and voice from the app root.
    return _page(context, keptPlan);
  }

  Widget _page(BuildContext context, GuestOnboardingDraft? keptPlan) {
    final auth = context.watch<AuthController>();
    final offline = auth.failedOffline;
    final proven = auth.phoneProofFor(_phoneController.text) != null;
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
            // A number just proven by a sign-in code needs no code (D75).
            label: proven
                ? (keptPlan != null
                      ? context.say('احفظ خطتي', 'احفظي خطتي')
                      : 'إنشاء الحساب')
                : offline
                ? 'أرسل الرمز مرة ثانية'
                : 'أرسل الرمز',
            expand: true,
            large: true,
            loading: auth.isSubmitting,
            onPressed: _submit,
          ),
          secondary: offline && keptPlan != null
              ? JourneyTextAction(
                  label: context.say(
                    'بعدين، خلني أشوف أول',
                    'بعدين، خليني أشوف أول',
                  ),
                  onPressed: () => context.go(AppRouter.home),
                )
              : JourneyTextAction(
                  key: const ValueKey('register-login'),
                  label: 'عندك حساب؟ تسجيل الدخول',
                  sub: keptPlan == null
                      ? null
                      : context.say(
                          'ولو حسابك فيه خطة، تختار وين تكون هذي',
                          'ولو حسابك فيه خطة، تختارين وين تكون هذي',
                        ),
                  onPressed: auth.isSubmitting ? null : _login,
                  color: context.accent.primaryDark,
                ),
        ),
        children: [
          JourneyStepBar(onBack: _back),
          if (offline) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyNote(
              key: const ValueKey('register-offline'),
              text: _creatingWithProof
                  ? context.say(
                      'ما قدرنا ننشئ حسابك الحين، تأكد من النت وجرّب.',
                      'ما قدرنا ننشئ حسابك الحين، تأكدي من النت وجرّبي.',
                    )
                  : keptPlan == null
                  ? 'ما قدرنا نرسل الرمز، ما وصلنا للخادم.'
                  : 'ما قدرنا نرسل الرمز، ما وصلنا للخادم. خطتك محفوظة على هذا الجوال.',
              icon: LucideIcons.wifiOff,
              tone: JourneyNoteTone.warn,
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
          JourneyNote(
            text: proven
                ? 'تأكدنا من هذا الرقم قبل شوي، فما نحتاج رمز ثاني.'
                : context.say(
                    'نرسل لك رمز على واتساب. تأكد إن الرقم عليه واتساب.',
                    'نرسل لك رمز على واتساب. تأكدي إن الرقم عليه واتساب.',
                  ),
            icon: LucideIcons.messageCircle,
            tone: JourneyNoteTone.paper,
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
    final auth = context.read<AuthController>();
    // The keyboard's «done» keeps the button's guard: one request at a time.
    if (auth.isSubmitting) return;
    if (!_submitAttempted) setState(() => _submitAttempted = true);
    if (_nameError != null || _phoneError != null) return;

    final name = _nameController.text.trim();
    final normalizedPhone = normalizeYemeniPhone(_phoneController.text);
    // The number was just proven by a sign-in code (D75): no second code.
    final proof = auth.phoneProofFor(normalizedPhone);
    setState(() => _creatingWithProof = proof != null);
    if (proof != null) {
      await auth.register(
        name: name,
        phone: normalizedPhone,
        phoneProof: proof,
        successLocation: _safeResumeLocation(context),
        savesKeptPlan: _keptPlan != null,
      );
      return;
    }
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
