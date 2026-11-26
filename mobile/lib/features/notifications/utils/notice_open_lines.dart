import 'package:flutter/widgets.dart';

import '../../../core/l10n/aarast_text.dart';

/// A push tap whose notice the server no longer has for this account: the
/// inbox opens and says it in one line.
String get noticeGoneLine => aarastText.noticeGone;

/// A push tap with no network and no copy of its notice on the phone: the
/// inbox opens (its own copy, if any) and says why the notice did not.
String noticeUnreachableLine(BuildContext context) =>
    context.text.noticeUnreachable(context.gender);
