/// D63 (w40 «أرسل تقارير الأعطال»): whether this phone sends crash and
/// error reports. The choice is kept with the device's other preferences
/// (`DevicePreferences.crashReports`) and mirrored here, because the error
/// reporter starts before those preferences are read. Off, nothing automatic
/// leaves the phone; a diagnostic report sent by hand from support still asks
/// its own consent each time.
abstract final class CrashReportSwitch {
  static bool _enabled = true;

  static bool get enabled => _enabled;

  static void set(bool value) => _enabled = value;
}
