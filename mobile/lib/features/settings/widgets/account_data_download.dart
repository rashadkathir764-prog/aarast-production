import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../data/settings_api.dart';

/// Opens a link to a download in the phone's browser; tests replace it.
typedef DownloadLinkOpener = Future<bool> Function(Uri link);

Future<bool> _openInBrowser(Uri link) =>
    launchUrl(link, mode: LaunchMode.externalApplication);

/// D63 (w40 «نزّل بياناتي», w05 «نزّلها»): asks the server for a one-time
/// link to the account's own data and opens it in the phone's browser,
/// which saves the file. The link works once, for fifteen minutes.
Future<void> downloadAccountData(
  BuildContext context, {
  DownloadLinkOpener open = _openInBrowser,
}) async {
  final api = context.read<SettingsApi>();
  try {
    final link = await api.createDataExport();
    final opened = await open(link);
    if (!context.mounted) return;
    if (opened) {
      AarastToast.showSuccess(
        context,
        context.say(
          'فتحنا ملف بياناتك في المتصفح. احفظه عندك.',
          'فتحنا ملف بياناتك في المتصفح. احفظيه عندك.',
        ),
      );
    } else {
      AarastToast.showError(context, 'ما قدرنا نفتح المتصفح. جرّب مرة ثانية.');
    }
  } on ApiException catch (error) {
    if (context.mounted) AarastToast.showError(context, error.message);
  } on FormatException {
    if (context.mounted) {
      AarastToast.showError(context, 'ما وصلنا رابط الملف. جرّب مرة ثانية.');
    }
  }
}
