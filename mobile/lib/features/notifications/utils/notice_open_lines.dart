import 'package:flutter/widgets.dart';

import '../../../core/experience_v3/aarast_v3.dart';

/// A push tap whose notice the server no longer has for this account: the
/// inbox opens and says it in one line.
const noticeGoneLine = 'لم يعد هذا متاحًا';

/// A push tap with no network and no copy of its notice on the phone: the
/// inbox opens (its own copy, if any) and says why the notice did not.
String noticeUnreachableLine(BuildContext context) => context.say(
  'لا اتصال بالشبكة، جرّب فتحه بعد قليل.',
  'لا اتصال بالشبكة، جرّبي فتحه بعد قليل.',
);
