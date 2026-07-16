import 'package:flutter/material.dart';

import '../phone/phone_number_utils.dart';

/// عرض موحّد لأرقام الهاتف داخل واجهات أعرست العربية.
///
/// التخزين وواجهات API تبقى بالقيمة المطبّعة كما هي؛ هذا المكوّن يعالج العرض
/// فقط، ويمنع خوارزمية BiDi من نقل علامة `+` أو قلب مجموعات الرقم في RTL.
class AarastPhoneText extends StatelessWidget {
  const AarastPhoneText({
    required this.phone,
    this.style,
    this.textAlign = TextAlign.right,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    super.key,
  });

  final String phone;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final displayPhone = PhoneNumberUtils.display(phone) ?? phone.trim();
    return Text(
      displayPhone,
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel ?? displayPhone,
      style: style,
    );
  }
}
