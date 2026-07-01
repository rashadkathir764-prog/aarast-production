import 'package:flutter/material.dart';

import '../models/money_formatters.dart';

class YemeniMoneyText extends StatelessWidget {
  const YemeniMoneyText(
    this.value, {
    this.style,
    this.color,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    super.key,
  });

  final num value;
  final TextStyle? style;
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

    return Text.rich(
      yemeniMoneyTextSpan(value, style: effectiveStyle),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

TextSpan yemeniMoneyTextSpan(num value, {TextStyle? style}) {
  final parts = compactYemeniMoneyParts(value);
  return TextSpan(
    style: style,
    children: [
      TextSpan(text: parts.number),
      if (parts.millionUnit != null) TextSpan(text: parts.millionUnit),
      const TextSpan(text: ' '),
      TextSpan(text: parts.currency),
    ],
  );
}
