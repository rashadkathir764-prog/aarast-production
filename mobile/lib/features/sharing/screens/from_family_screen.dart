import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/whatsapp_share.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthController, AuthStatus;

/// The message the participant sends the groom or the bride to be added.
const fromFamilyAskMessage =
    'هلا، أشتي أساعدك في ترتيب العرس. ضيفني في تطبيق اعّرست من «المشاركين» وارسل لي رابط الدعوة.';

/// The private token inside an invite link, or the token itself when only it
/// was pasted; null when the text holds no invite.
@visibleForTesting
String? inviteTokenFromText(String text) {
  final clean = text.trim();
  if (clean.isEmpty) return null;
  final token = _tokenPattern.hasMatch(clean)
      ? clean
      : RegExp(r'invites/([A-Za-z0-9_-]+)').firstMatch(clean)?.group(1);
  return token != null && _tokenPattern.hasMatch(token) ? token : null;
}

final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

/// x04 «تساعد في عرس أحد؟»: the invite link from WhatsApp is pasted (or
/// found on the clipboard) and opened; without one, a ready message asks the
/// groom or the bride to add you.
class FromFamilyScreen extends StatefulWidget {
  const FromFamilyScreen({super.key});

  @override
  State<FromFamilyScreen> createState() => _FromFamilyScreenState();
}

class _FromFamilyScreenState extends State<FromFamilyScreen> {
  final _linkController = TextEditingController();
  String? _clipboardToken;
  String? _error;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(_onLinkChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    _linkController
      ..removeListener(_onLinkChanged)
      ..dispose();
    super.dispose();
  }

  void _onLinkChanged() {
    if (_error != null) setState(() => _error = null);
    setState(() {});
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final token = inviteTokenFromText(data?.text ?? '');
      if (!mounted || token == null) return;
      setState(() => _clipboardToken = token);
    } on Object {
      // A phone that refuses the clipboard just shows the field.
    }
  }

  void _open([String? token]) {
    final found = token ?? inviteTokenFromText(_linkController.text);
    if (found == null) {
      setState(
        () => _error = 'هذا مو رابط دعوة. انسخ الرابط كامل من رسالة واتساب.',
      );
      return;
    }
    context.push(AppRouter.inviteDecision(found));
  }

  Future<void> _askToBeAdded() async {
    bool opened;
    try {
      opened = await launchUrl(
        whatsAppShareUri(fromFamilyAskMessage),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      opened = false;
    }
    if (opened || !mounted) return;
    await Clipboard.setData(const ClipboardData(text: fromFamilyAskMessage));
    if (!mounted) return;
    AarastToast.showInfo(context, 'نسخنا لك الرسالة، أرسلها له بأي طريقة.');
  }

  void _startOwnPlan() {
    final signedIn =
        context.read<AuthController?>()?.status == AuthStatus.authenticated;
    context.go(signedIn ? AppRouter.createWeddingPlan : AppRouter.welcome);
  }

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                JourneySubHeader(
                  title: '',
                  onBack: () => context.popOrGo(AppRouter.welcome),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: JourneyIconTile(
                    icon: LucideIcons.users,
                    color: AarastV3Color.primary,
                    soft: AarastV3Color.primarySoft,
                    size: 76,
                    radius: 24,
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text(
                    'تساعد في عرس أحد؟',
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.display,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'العريس أو العروسة يضيفونك من خطتهم،\nويوصلك رابط على واتساب.',
                  textAlign: TextAlign.center,
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                JourneyTextField(
                  key: const ValueKey('from-family-link'),
                  label: 'الصق رابط الدعوة',
                  controller: _linkController,
                  icon: LucideIcons.link,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  errorText: _error,
                  onSubmitted: (_) => _open(),
                ),
                if (_clipboardToken case final token?) ...[
                  const SizedBox(height: 10),
                  AarastPressable(
                    key: const ValueKey('from-family-clipboard'),
                    onTap: () => _open(token),
                    semanticLabel: 'لقينا رابط في الحافظة. نفتحه؟',
                    borderRadius: BorderRadius.circular(16),
                    child: const JourneyNote(
                      text: 'لقينا رابط في الحافظة. نفتحه؟',
                      icon: LucideIcons.clipboardCheck,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AarastV3Color.line)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'ما عندك رابط؟',
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AarastV3Color.line)),
                  ],
                ),
                const SizedBox(height: 14),
                JourneyBox(
                  padding: EdgeInsets.zero,
                  child: JourneyListRow(
                    key: const ValueKey('from-family-ask'),
                    icon: LucideIcons.messageCircle,
                    color: AarastV3Color.mint,
                    soft: AarastV3Color.mintSoft,
                    title: 'اطلب منه يضيفك',
                    subtitle: 'نجهز لك رسالة ترسلها له',
                    trailing: const Icon(
                      LucideIcons.chevronLeft,
                      size: 18,
                      color: AarastV3Color.textFaint,
                    ),
                    onTap: _askToBeAdded,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: JourneyTextAction(
                    key: const ValueKey('from-family-own-plan'),
                    label: 'أو أنت عريس؟ ابدأ خطتك',
                    color: AarastV3Color.primary,
                    onPressed: _startOwnPlan,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: JourneyButton(
              key: const ValueKey('from-family-open'),
              label: 'افتح الرابط',
              expand: true,
              large: true,
              onPressed: _linkController.text.trim().isEmpty ? null : _open,
            ),
          ),
        ],
      ),
    );
  }
}
