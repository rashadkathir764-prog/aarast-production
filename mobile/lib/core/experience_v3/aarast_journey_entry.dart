import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../widgets/aarast_pressable.dart';
import 'aarast_journey.dart';
import 'aarast_journey_art.dart';
import 'aarast_journey_profile.dart';
import 'aarast_journey_sheet.dart';
import 'aarast_v3_foundations.dart';

/// The pieces of the entry screens (D75): the door, the groom-or-bride
/// choice, the plan's three questions, saving the plan and signing in. Each
/// one is drawn once here so every entry screen says the same thing the same
/// way.

/// The height of a person's picture card («أنت العريس ولا العروسة؟»), so
/// both choices weigh the same.
const _personaCardHeight = 112.0;

/// The width of the picture on a person's card.
const _personaPictureWidth = 96.0;

/// The thickness of the questions' progress track.
const _stepTrack = 8.0;

/// Back, and on the plan's three questions the progress: a done question is
/// full, the current one half, the next ones empty.
class JourneyStepBar extends StatelessWidget {
  const JourneyStepBar({
    required this.onBack,
    this.step,
    this.total = 3,
    super.key,
  });

  final VoidCallback onBack;

  /// The current question, from 1; null shows the back button alone.
  final int? step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final step = this.step;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AarastV3Space.x2),
      child: Row(
        children: [
          JourneyRoundButton(
            icon: LucideIcons.arrowRight,
            tooltip: 'رجوع',
            onPressed: onBack,
          ),
          if (step != null) ...[
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: Semantics(
                label: 'السؤال $step من $total',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 1; i <= total; i++) ...[
                        if (i > 1) const SizedBox(width: AarastV3Space.x2),
                        Expanded(
                          child: _StepTrack(
                            share: i < step ? 1 : (i == step ? 0.5 : 0),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepTrack extends StatelessWidget {
  const _StepTrack({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AarastV3Radius.pill);
    return Container(
      height: _stepTrack,
      decoration: BoxDecoration(
        color: AarastV3Color.line,
        borderRadius: radius,
      ),
      alignment: AlignmentDirectional.centerStart,
      child: share == 0
          ? null
          : FractionallySizedBox(
              widthFactor: share,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.accent.primary,
                  borderRadius: radius,
                ),
              ),
            ),
    );
  }
}

/// The question and the line that says why it is asked.
class JourneyEntryQuestion extends StatelessWidget {
  const JourneyEntryQuestion({required this.question, this.help, super.key});

  final String question;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AarastV3Space.x5),
        Semantics(
          header: true,
          child: Text(
            question,
            style: JourneyType.of(
              JourneyType.question,
              weight: JourneyType.bold,
              height: 1.3,
            ),
          ),
        ),
        if (help != null) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            help!,
            style: JourneyType.of(
              JourneyType.bodyLarge,
              color: AarastV3Color.textMuted,
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }
}

/// The action under an entry screen: the main button, and under it the
/// second way out. The second line keeps its room even when empty, so the
/// main button stays in one place from screen to screen.
class JourneyEntryActions extends StatelessWidget {
  const JourneyEntryActions({
    required this.primary,
    this.secondary,
    this.above,
    this.reserve = true,
    super.key,
  });

  final Widget primary;
  final Widget? secondary;

  /// A note that belongs to the action (an error), right over it.
  final Widget? above;
  final bool reserve;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (above != null) ...[
          above!,
          const SizedBox(height: AarastV3Space.x3),
        ],
        primary,
        const SizedBox(height: AarastV3Space.x1),
        if (secondary != null)
          Center(child: secondary)
        else if (reserve)
          const SizedBox(height: AarastV3Space.x12),
      ],
    );
  }
}

/// The second way out under the main action: a plain line, sometimes with
/// a smaller line under it.
class JourneyEntryLink extends StatelessWidget {
  const JourneyEntryLink({
    required this.label,
    required this.onPressed,
    this.sub,
    this.strong = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? sub;

  /// In the plan's deep colour (a way forward), not the quiet grey (later).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong ? context.accent.primaryDark : AarastV3Color.textMuted;
    return Semantics(
      button: true,
      label: [label, ?sub].join('، '),
      onTap: onPressed,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AarastV3Space.x12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: color,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How a note sits: on white (information that changes a decision), on
/// saffron (a warning), or bare (a small aside).
enum JourneyEntryNoteTone { paper, warn, bare }

/// A note on an entry screen.
class JourneyEntryNote extends StatelessWidget {
  const JourneyEntryNote({
    required this.text,
    required this.icon,
    this.tone = JourneyEntryNoteTone.paper,
    this.color,
    super.key,
  });

  final String text;
  final IconData icon;
  final JourneyEntryNoteTone tone;

  /// The icon's colour; the plan's colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = tone == JourneyEntryNoteTone.warn
        ? AarastV3Color.brandAccentStrong
        : color ?? context.accent.primary;
    if (tone == JourneyEntryNoteTone.bare) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AarastV3Space.half),
              child: Icon(icon, size: AarastV3Icon.sm, color: iconColor),
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: Text(
                text,
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final warn = tone == JourneyEntryNoteTone.warn;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x4,
        vertical: AarastV3Space.x3,
      ),
      decoration: BoxDecoration(
        color: warn ? AarastV3Color.brandAccentSoft : AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AarastV3Space.half),
            child: Icon(icon, size: AarastV3Icon.md, color: iconColor),
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.body,
                color: warn
                    ? AarastV3Color.brandAccentStrong
                    : AarastV3Color.textMuted,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded square icon on the plan's soft fill.
class JourneyEntryTile extends StatelessWidget {
  const JourneyEntryTile({
    required this.icon,
    this.size = AarastV3Space.x10,
    this.background,
    super.key,
  });

  final IconData icon;
  final double size;

  /// The fill; the plan's soft colour when null.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? context.accent.primarySoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
      ),
      child: Icon(icon, size: AarastV3Icon.md, color: context.accent.primary),
    );
  }
}

/// One way in from the door: an icon, what it is, who it is for.
class JourneyDoor extends StatelessWidget {
  const JourneyDoor({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title، $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(AarastV3Space.x4),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.card),
          ),
          child: Row(
            children: [
              JourneyEntryTile(icon: icon),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.title,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      subtitle,
                      style: JourneyType.of(
                        JourneyType.bodySmall,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              const Icon(
                LucideIcons.chevronLeft,
                size: AarastV3Icon.md,
                color: AarastV3Color.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The groom's or the bride's card: their name in their colour, what their
/// plan holds, and their picture at the far edge. Both are the same size.
class JourneyPersonaCard extends StatelessWidget {
  const JourneyPersonaCard({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.picture,
    required this.onTap,
    super.key,
  });

  final JourneyAccent accent;
  final String title;
  final String subtitle;
  final Widget picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AarastV3Radius.card);
    return Semantics(
      button: true,
      label: '$title، $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: _personaCardHeight),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: radius,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AarastV3Space.x4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: JourneyType.of(
                                  JourneyType.pageTitle,
                                  weight: JourneyType.bold,
                                  color: accent.primaryDark,
                                ),
                              ),
                              const SizedBox(height: AarastV3Space.x1),
                              Text(
                                subtitle,
                                style: JourneyType.of(
                                  JourneyType.body,
                                  color: AarastV3Color.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AarastV3Space.x2),
                        const Icon(
                          LucideIcons.chevronLeft,
                          size: AarastV3Icon.md,
                          color: AarastV3Color.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: _personaPictureWidth,
                  child: ColoredBox(
                    color: accent.primarySoft,
                    child: ClipRect(child: picture),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The wedding sky over the top of a screen, its lights and fireworks
/// only, melting into the page (no gradient, D3).
class JourneySkyBand extends StatelessWidget {
  const JourneySkyBand({required this.height, super.key});

  /// The band's height; the sky is drawn taller and cut at it, so the band
  /// shows the lights and the fireworks, not the empty night under them.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: height * 1.65,
          maxHeight: height * 1.65,
          child: const JourneyWeddingSky(base: AarastV3Color.canvas),
        ),
      ),
    );
  }
}

/// A row of a white list on an entry screen: an icon, a line, a smaller
/// line under it.
class JourneyEntryRow extends StatelessWidget {
  const JourneyEntryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.divider = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x4,
        vertical: AarastV3Space.x3,
      ),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: AarastV3Color.line))
            : null,
      ),
      child: Row(
        children: [
          JourneyEntryTile(icon: icon),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                const SizedBox(height: AarastV3Space.half),
                Text(
                  subtitle,
                  style: JourneyType.of(
                    JourneyType.bodySmall,
                    color: AarastV3Color.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «رقم جوالك»: the Yemeni code, then the number, left to right as it is
/// read and dialled. The app takes Yemeni numbers today, so the code is
/// fixed, not a picker.
class JourneyPhoneField extends StatefulWidget {
  const JourneyPhoneField({
    required this.controller,
    this.label = 'رقم جوالك',
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;

  @override
  State<JourneyPhoneField> createState() => _JourneyPhoneFieldState();
}

class _JourneyPhoneFieldState extends State<JourneyPhoneField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_repaint);
  }

  void _repaint() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_repaint)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText;
    final focused = _focus.hasFocus;
    final border = error != null
        ? AarastV3Color.danger
        : focused
        ? context.accent.primary
        : AarastV3Color.line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Container(
            padding: AarastV3Field.padding,
            decoration: BoxDecoration(
              color: AarastV3Color.paper,
              borderRadius: BorderRadius.circular(AarastV3Field.radius),
              border: Border.all(
                color: border,
                width: focused || error != null ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: JourneyType.of(
                    JourneyType.label,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: AarastV3Space.x1),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(right: AarastV3Space.x3),
                        margin: const EdgeInsets.only(right: AarastV3Space.x3),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: AarastV3Color.line),
                          ),
                        ),
                        child: Text(
                          '+967',
                          style: JourneyType.of(
                            JourneyType.bodyLarge,
                            weight: JourneyType.bold,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('journey-phone-input'),
                          controller: widget.controller,
                          focusNode: _focus,
                          autofocus: widget.autofocus,
                          enabled: widget.enabled,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9٠-٩+ ]'),
                            ),
                            LengthLimitingTextInputFormatter(16),
                          ],
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                          cursorColor: context.accent.primary,
                          style: JourneyType.of(
                            JourneyType.lead,
                            weight: JourneyType.bold,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: '7XX XXX XXX',
                            hintStyle: JourneyType.of(
                              JourneyType.bodyLarge,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AarastV3Space.x1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
            child: Text(
              error,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// «على هذا الجوال الحين · عرس محمد · صنعاء · 12 بند»: the plan the number
/// will save, so it is clear what is being saved.
class JourneyKeptPlanStrip extends StatelessWidget {
  const JourneyKeptPlanStrip({required this.line, super.key});

  final String line;

  @override
  Widget build(BuildContext context) {
    final dark = context.accent.primaryDark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x4,
        vertical: AarastV3Space.x3,
      ),
      decoration: BoxDecoration(
        color: context.accent.primarySoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      ),
      child: Row(
        children: [
          const JourneyEntryTile(
            icon: LucideIcons.smartphone,
            background: AarastV3Color.paper,
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'على هذا الجوال الحين',
                  style: JourneyType.of(JourneyType.label, color: dark),
                ),
                Text(
                  line,
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                    color: dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «0:42» for a countdown in seconds.
String journeyClock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// «الرمز ما وصل؟»: what to check, send it again, fix the number, and one
/// more way out (look at the plan first, or sign in with a password). Codes
/// go by WhatsApp only.
class JourneyCodeHelpSheet extends StatefulWidget {
  const JourneyCodeHelpSheet({
    super.key,
    required this.resendSeconds,
    required this.changeLabel,
    required this.onResend,
    required this.onChangeNumber,
    required this.onLater,
    required this.onPassword,
  });

  final int Function() resendSeconds;
  final String changeLabel;
  final VoidCallback onResend;
  final VoidCallback onChangeNumber;

  /// With a plan kept on the phone: look at it first, save it later.
  final VoidCallback? onLater;

  /// Without one: an account with a password can still sign in.
  final VoidCallback? onPassword;

  @override
  State<JourneyCodeHelpSheet> createState() => _CodeHelpSheetState();
}

class _CodeHelpSheetState extends State<JourneyCodeHelpSheet> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.resendSeconds();
    final onLater = widget.onLater;
    final onPassword = widget.onPassword;
    return JourneySheetBody(
      title: 'الرمز ما وصل؟',
      children: [
        JourneyEntryNote(
          text: context.say(
            'تأكد إن الرقم عليه واتساب.',
            'تأكدي إن الرقم عليه واتساب.',
          ),
          icon: LucideIcons.messageCircle,
          tone: JourneyEntryNoteTone.bare,
        ),
        JourneyEntryNote(
          text: context.say('تأكد إن النت شغّال.', 'تأكدي إن النت شغّال.'),
          icon: LucideIcons.wifi,
          tone: JourneyEntryNoteTone.bare,
        ),
        const SizedBox(height: AarastV3Space.x2),
        _HelpRow(
          icon: LucideIcons.refreshCw,
          label: 'أرسله مرة ثانية',
          sub: seconds > 0 ? 'بعد ${journeyClock(seconds)}' : null,
          onTap: seconds > 0 ? null : widget.onResend,
        ),
        _HelpRow(
          icon: LucideIcons.smartphone,
          label: widget.changeLabel,
          onTap: widget.onChangeNumber,
        ),
        if (onLater != null)
          _HelpRow(
            icon: LucideIcons.clock,
            label: context.say('بعدين، خلني أشوف أول', 'بعدين، خليني أشوف أول'),
            sub: context.say(
              'الخطة على هذا الجوال، وتحفظها برقمك أي وقت',
              'الخطة على هذا الجوال، وتحفظينها برقمك أي وقت',
            ),
            onTap: onLater,
          )
        else if (onPassword != null)
          _HelpRow(
            icon: LucideIcons.lock,
            label: 'الدخول بكلمة المرور',
            sub: 'لو حطيت كلمة مرور لحسابك',
            onTap: onPassword,
          ),
      ],
    );
  }
}

/// A row of the sheet: an icon, what it does, a smaller line, and a chevron
/// while it can be tapped.
class _HelpRow extends StatelessWidget {
  const _HelpRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: [label, ?sub].join('، '),
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              JourneyEntryTile(
                icon: icon,
                background: enabled ? null : AarastV3Color.canvas,
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                        color: enabled
                            ? AarastV3Color.ink
                            : AarastV3Color.textMuted,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub!,
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (enabled)
                const Icon(
                  LucideIcons.chevronLeft,
                  size: AarastV3Icon.md,
                  color: AarastV3Color.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Under the code boxes: when the code can be sent again (or the way to send
/// it now), and «ما وصلني الرمز».
class JourneyCodeResendRow extends StatelessWidget {
  const JourneyCodeResendRow({
    required this.seconds,
    required this.onResend,
    required this.onHelp,
    super.key,
  });

  /// Seconds left before the code can be sent again; 0 when it can.
  final int seconds;
  final VoidCallback? onResend;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final dark = context.accent.primaryDark;
    final onHelp = this.onHelp;
    return Row(
      children: [
        Expanded(
          child: seconds > 0
              ? Text(
                  'نرسله مرة ثانية بعد ${journeyClock(seconds)}',
                  key: const ValueKey('otp-resend-button'),
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                  ),
                )
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyTextAction(
                    key: const ValueKey('otp-resend-button'),
                    label: 'أرسله مرة ثانية',
                    color: dark,
                    onPressed: onResend,
                  ),
                ),
        ),
        if (onHelp != null)
          JourneyTextAction(
            key: const ValueKey('otp-code-help'),
            label: 'ما وصلني الرمز',
            color: dark,
            onPressed: onHelp,
          ),
      ],
    );
  }
}
