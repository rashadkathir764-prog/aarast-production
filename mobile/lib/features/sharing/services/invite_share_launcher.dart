import 'package:url_launcher/url_launcher.dart';

abstract interface class InviteShareLauncher {
  Future<bool> openWhatsApp(Uri uri);
}

class UrlLauncherInviteShareLauncher implements InviteShareLauncher {
  const UrlLauncherInviteShareLauncher();

  @override
  Future<bool> openWhatsApp(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
