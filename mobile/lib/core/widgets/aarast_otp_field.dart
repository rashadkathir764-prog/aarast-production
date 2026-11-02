import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../experience_v3/aarast_journey.dart' show JourneyType;
import '../experience_v3/aarast_journey_profile.dart';
import '../experience_v3/aarast_v3_foundations.dart';

/// The hidden input under the code boxes only carries the digits.
const _hiddenInputSize = 1.0;

/// الحالة البصرية لحقل رمز التحقق الموحّد.
enum AarastOtpFieldState { idle, error, success }

/// حقل رمز التحقق الموحّد — نفس التجربة في كل شاشات التحقق:
/// خانات منفصلة بصرياً فوق حقل إدخال واحد (يدعم اللصق والملء التلقائي
/// من رسالة SMS عبر [AutofillHints.oneTimeCode])، اهتزاز أحمر عند الخطأ
/// مع مسح تلقائي وإعادة تركيز، وحد أخضر مع ✓ عند النجاح، مع haptics
/// واحترام إعداد تقليل الحركة.
class AarastOtpField extends StatefulWidget {
  const AarastOtpField({
    required this.controller,
    this.length = 6,
    this.state = AarastOtpFieldState.idle,
    this.enabled = true,
    this.autofocus = false,
    this.fieldKey,
    this.onChanged,
    this.onCompleted,
    super.key,
  }) : assert(length > 0, 'OTP length must be greater than zero.');

  final TextEditingController controller;
  final int length;
  final AarastOtpFieldState state;
  final bool enabled;
  final bool autofocus;

  /// مفتاح حقل الإدخال الداخلي — تستخدمه الاختبارات لإدخال الرمز.
  final Key? fieldKey;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  /// مدة إبقاء حالة النجاح (لوحة ✓ الخضراء) ظاهرة قبل متابعة التنقل.
  /// ثانية واحدة كحد أقصى — وصفر عند تفعيل "تقليل الحركة".
  static Duration successHold(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 1000);
  }

  @override
  State<AarastOtpField> createState() => _AarastOtpFieldState();
}

class _AarastOtpFieldState extends State<AarastOtpField>
    with TickerProviderStateMixin {
  static const _boxHeight = 52.0;

  late final AnimationController _shakeController;
  late final AnimationController _fillController;
  final FocusNode _focusNode = FocusNode();

  int _previousLength = 0;
  int _staggerStart = 0;
  int _controllerChangeRevision = 0;
  Timer? _errorClearTimer;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _previousLength = widget.controller.text.length;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: 1,
    );
    widget.controller.addListener(_handleExternalChange);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AarastOtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleExternalChange);
      widget.controller.addListener(_handleExternalChange);
      _previousLength = widget.controller.text.length;
    }
    if (oldWidget.state != widget.state) {
      switch (widget.state) {
        case AarastOtpFieldState.error:
          _playError();
        case AarastOtpFieldState.success:
          _playSuccess();
        case AarastOtpFieldState.idle:
          _errorClearTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    widget.controller.removeListener(_handleExternalChange);
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _shakeController.dispose();
    _fillController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  // يلتقط المسح/التعبئة الخارجية من الشاشة الأم (مثل clear بعد خطأ)
  // حتى تبقى الخانات مطابقة لنص الـ controller دائماً.
  void _handleExternalChange() {
    if (!mounted) return;
    final length = widget.controller.text.length;
    final revision = ++_controllerChangeRevision;
    setState(() {});

    // EditableText updates the controller before it invokes onChanged. Delay
    // synchronising the baseline by one microtask so _handleChanged can still
    // distinguish a single key press from paste/autofill. A truly external
    // controller update has no onChanged callback and therefore owns the same
    // revision when this microtask runs.
    scheduleMicrotask(() {
      if (!mounted || revision != _controllerChangeRevision) return;
      _previousLength = length;
    });
  }

  void _playError() {
    HapticFeedback.heavyImpact();
    if (!_reduceMotion) {
      _shakeController.forward(from: 0);
    }
    // بعد الاهتزاز: مسح تلقائي وإعادة التركيز ليعيد المستخدم المحاولة فوراً.
    _errorClearTimer?.cancel();
    _errorClearTimer = Timer(
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 460),
      () {
        if (!mounted) return;
        widget.controller.clear();
        if (widget.enabled) _focusNode.requestFocus();
      },
    );
  }

  void _playSuccess() {
    HapticFeedback.mediumImpact();
    _focusNode.unfocus();
  }

  void _handleChanged(String value) {
    _controllerChangeRevision += 1;
    final added = value.length - _previousLength;
    if (added == 1) {
      HapticFeedback.selectionClick();
    } else if (added > 1) {
      // لصق أو ملء تلقائي: تعبئة متسلسلة للخانات الجديدة.
      HapticFeedback.selectionClick();
      _staggerStart = value.length - added;
      if (!_reduceMotion) _fillController.forward(from: 0);
    }
    _previousLength = value.length;
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      widget.onCompleted?.call(value);
    }
  }

  Color _borderColor(bool isActive) {
    return switch (widget.state) {
      AarastOtpFieldState.error => AppTheme.danger,
      AarastOtpFieldState.success => AppTheme.success,
      AarastOtpFieldState.idle =>
        // The plan's colour (the bride's rose), like every focused field.
        isActive && _focusNode.hasFocus
            ? context.accent.primary
            : AppTheme.border,
    };
  }

  Color _fillColor() {
    return switch (widget.state) {
      AarastOtpFieldState.error => AppTheme.dangerSoft,
      AarastOtpFieldState.success => AppTheme.successSoft,
      AarastOtpFieldState.idle => AppTheme.surfaceRaised,
    };
  }

  Widget _buildBox(BuildContext context, int index) {
    final text = widget.controller.text;
    final char = index < text.length ? text[index] : '';
    final isActive =
        widget.state != AarastOtpFieldState.success &&
        index == text.length.clamp(0, widget.length - 1) &&
        text.length < widget.length;
    final isSuccess = widget.state == AarastOtpFieldState.success;

    Widget digit = Text(
      char,
      style: JourneyType.of(
        JourneyType.amount,
        weight: JourneyType.bold,
        height: 1.2,
        color: switch (widget.state) {
          AarastOtpFieldState.error => AppTheme.danger,
          AarastOtpFieldState.success => AppTheme.success,
          AarastOtpFieldState.idle => AppTheme.textPrimary,
        },
      ),
    );

    // تعبئة متسلسلة بعد اللصق/الملء التلقائي.
    if (char.isNotEmpty && index >= _staggerStart && !_reduceMotion) {
      final steps = widget.length - _staggerStart;
      final position = index - _staggerStart;
      final start = steps <= 0 ? 0.0 : position / (steps + 1);
      final end = steps <= 0 ? 1.0 : (position + 2) / (steps + 1);
      final safeStart = math.min(math.max(start, 0.0), 1.0);
      final safeEnd = math.min(math.max(end, safeStart), 1.0);
      digit = ScaleTransition(
        scale: CurvedAnimation(
          parent: _fillController,
          curve: Interval(safeStart, safeEnd, curve: Curves.easeOutBack),
        ),
        child: digit,
      );
    }

    final lastIndex = widget.length - 1;
    return Expanded(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          end: index == lastIndex ? 0 : AarastV3Space.x1,
        ),
        child: AnimatedContainer(
          duration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          height: _boxHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _fillColor(),
            borderRadius: BorderRadius.circular(AarastV3Field.radius),
            border: Border.all(
              color: _borderColor(isActive),
              width: isActive || widget.state != AarastOtpFieldState.idle
                  ? 1.5
                  : 1,
            ),
          ),
          child: isSuccess && char.isEmpty
              ? const Icon(LucideIcons.check, color: AppTheme.success, size: 22)
              : digit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'حقل رمز التحقق المكوّن من ${widget.length} أرقام',
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          // موجة جيبية متخامدة: اهتزاز قوي يخفت تدريجياً حتى السكون.
          final t = _shakeController.value;
          final offset = math.sin(t * math.pi * 5) * 9 * (1 - t);
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: _boxHeight,
            child: Stack(
              children: [
                // حقل الإدخال الحقيقي: شفاف خلف الخانات، يمتد على كامل
                // العرض ليستقبل اللمس واللصق والملء التلقائي من SMS.
                Positioned.fill(
                  child: TextFormField(
                    key: widget.fieldKey,
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled:
                        widget.enabled &&
                        widget.state != AarastOtpFieldState.success,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    showCursor: false,
                    style: const TextStyle(
                      color: Colors.transparent,
                      // The real input is invisible under the boxes.
                      fontSize: _hiddenInputSize,
                    ),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: true,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _handleChanged,
                  ),
                ),
                // الخانات المرئية فوق الحقل — لا تلتقط اللمس حتى تصل
                // كل الإيماءات (تركيز، لصق بالضغط المطوّل) للحقل الحقيقي.
                IgnorePointer(
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.length; i++)
                        _buildBox(context, i),
                    ],
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
