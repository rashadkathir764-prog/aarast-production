import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../utils/ask_on_whatsapp.dart';
import '../../auth/auth_api.dart' show AuthController, AuthStatus;

/// The message the participant sends the groom or the bride to be added.
const fromFamilyAskMessage =
    'هلا، أشتي أساعد في ترتيب العرس. ممكن تضيفوني في اعّرست من «المشاركين» وترسلوا لي رابط الدعوة؟';

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

/// «معك رابط دعوة؟» (D75): the link from WhatsApp is pasted (the clipboard
/// is read only on «لصق», never on its own) and opened; without one, a ready
/// WhatsApp message asks the plan's owner for it. The words fit anyone: a
/// mother, a sister, a friend.
class FromFamilyScreen extends StatefulWidget {
  const FromFamilyScreen({super.key});

  @override
  State<FromFamilyScreen> createState() => _FromFamilyScreenState();
}

class _FromFamilyScreenState extends State<FromFamilyScreen> {
  final _linkController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(_onLinkChanged);
  }

  @override
  void dispose() {
    _linkController
      ..removeListener(_onLinkChanged)
      ..dispose();
    super.dispose();
  }

  void _onLinkChanged() {
    setState(() => _error = null);
  }

  /// «لصق»: the person asked, so the clipboard is read now.
  Future<void> _paste() async {
    String text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    } on Object {
      text = '';
    }
    if (!mounted) return;
    if (text.trim().isEmpty) {
      setState(() => _error = 'ما في شي منسوخ. انسخ الرابط من رسالة واتساب.');
      return;
    }
    _linkController.text = text.trim();
  }

  void _open() {
    final found = inviteTokenFromText(_linkController.text);
    if (found == null) {
      setState(
        () => _error = 'هذا مو رابط دعوة. انسخ الرابط كامل من رسالة واتساب.',
      );
      return;
    }
    context.push(AppRouter.inviteDecision(found));
  }

  Future<void> _askToBeAdded() => askOnWhatsApp(context, fromFamilyAskMessage);

  void _startOwnPlan() {
    final signedIn =
        context.read<AuthController?>()?.status == AuthStatus.authenticated;
    context.go(signedIn ? AppRouter.createWeddingPlan : AppRouter.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.accent.primaryDark;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      child: JourneyPage(
        bottom: JourneyEntryActions(
          primary: JourneyButton(
            key: const ValueKey('from-family-open'),
            label: 'فتح الرابط',
            expand: true,
            large: true,
            onPressed: _linkController.text.trim().isEmpty ? null : _open,
          ),
          secondary: JourneyEntryLink(
            key: const ValueKey('from-family-own-plan'),
            label: 'خطة عرس جديدة؟ من هنا',
            strong: true,
            onPressed: _startOwnPlan,
          ),
        ),
        children: [
          JourneyStepBar(onBack: () => context.popOrGo(AppRouter.welcome)),
          const JourneyEntryQuestion(
            question: 'معك رابط دعوة؟',
            help: 'يوصل على واتساب من صاحب خطة العرس.',
          ),
          const SizedBox(height: AarastV3Space.x5),
          JourneyTextField(
            key: const ValueKey('from-family-link'),
            label: 'رابط الدعوة',
            hint: 'الرابط هنا',
            controller: _linkController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            errorText: _error,
            onSubmitted: (_) => _open(),
            trailing: _PasteButton(onPressed: _paste),
          ),
          const SizedBox(height: AarastV3Space.x2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
            child: Text(
              'الدخول بنفس الرقم اللي وصلته الدعوة.',
              style: JourneyType.of(
                JourneyType.bodySmall,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x5),
          JourneyBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ما في رابط؟',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                const SizedBox(height: AarastV3Space.x1),
                Text(
                  'رسالة واتساب جاهزة لطلب الدعوة من صاحب الخطة.',
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                    height: 1.5,
                  ),
                ),
                JourneyTextAction(
                  key: const ValueKey('from-family-ask'),
                  label: 'طلب الدعوة على واتساب',
                  icon: LucideIcons.messageCircle,
                  color: dark,
                  onPressed: _askToBeAdded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «لصق» at the end of the link field.
class _PasteButton extends StatelessWidget {
  const _PasteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'لصق الرابط',
      onTap: onPressed,
      excludeSemantics: true,
      child: AarastPressable(
        key: const ValueKey('from-family-paste'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: AarastV3Space.x12),
          padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x4),
          decoration: BoxDecoration(
            color: context.accent.primarySoft,
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.clipboard,
                size: AarastV3Icon.sm,
                color: context.accent.primaryDark,
              ),
              const SizedBox(width: AarastV3Space.x1),
              Text(
                'لصق',
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                  color: context.accent.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
