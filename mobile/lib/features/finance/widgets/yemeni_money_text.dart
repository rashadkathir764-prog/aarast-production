import 'package:flutter/material.dart';

import '../models/money_formatters.dart';

class YemeniMoneyText extends StatelessWidget {
  const YemeniMoneyText(
    this.value, {
    required this.currencyCode,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    super.key,
  });

  final num value;
  final TextStyle? style;
  final String currencyCode;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = (style ?? defaultStyle).copyWith(
      color: color ?? style?.color ?? defaultStyle.color,
    );
    final parts = compactMoneyParts(value, currencyCode: currencyCode);

    return Semantics(
      label: parts.semanticText,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // بطاقات الملخص الضيقة قد تمنح المبلغ نحو 50px فقط. نعرض الرمز
            // المختصر هناك، مع إبقاء «مليون» كاملًا بصريًا في المساحات
            // الطبيعية وفي وصف قارئ الشاشة.
            final visualUnit =
                parts.millionUnit != null &&
                    constraints.hasBoundedWidth &&
                    constraints.maxWidth < 96
                ? 'م'
                : parts.millionUnit;

            Text token(String value) => Text(
              value,
              style: effectiveStyle,
              textDirection: value == parts.number
                  ? TextDirection.ltr
                  : TextDirection.rtl,
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: overflow,
            );

            final row = Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              textDirection: TextDirection.ltr,
              children: [
                token(parts.number),
                if (visualUnit != null) ...[
                  const SizedBox(width: 4),
                  token(visualUnit),
                ],
                const SizedBox(width: 5),
                token(parts.currency),
              ],
            );

            if (!constraints.hasBoundedWidth) return row;
            return FittedBox(fit: BoxFit.scaleDown, child: row);
          },
        ),
      ),
    );
  }
}
