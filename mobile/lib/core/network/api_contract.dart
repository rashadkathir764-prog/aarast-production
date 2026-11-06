import 'package:flutter/foundation.dart';

/// D93 (RA-BE-01): the number of the API contract this app was built for,
/// sent with every request. Raised only when the server must break a
/// contract an older app relies on; the server then answers apps below its
/// MIN_CLIENT_CONTRACT with 426 «حدّث التطبيق» instead of refusing their
/// writes one by one.
const int apiContractVersion = 1;

/// The header that carries [apiContractVersion].
const String apiContractHeader = 'X-Aarast-Contract';

/// The server's code for an app older than its minimum contract.
const String appUpdateRequiredCode = 'APP_UPDATE_REQUIRED';

/// Raised once the server says this app is too old. The app shows «حدّث
/// التطبيق» over everything, and the offline queue stops sending (its
/// changes stay on the phone for the updated app to send).
final ValueNotifier<bool> appUpdateRequired = ValueNotifier(false);

/// The app's page on Google Play, where «حدّث التطبيق» leads.
const String appStoreUrl =
    'https://play.google.com/store/apps/details?id=com.aarast.aarast_mobile';
