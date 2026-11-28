import 'package:flutter/foundation.dart';

import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/settings_api.dart';
import '../models/preference_coverage.dart';
import '../models/reminder_schedule.dart';
import '../models/user_settings.dart';

/// The account's notification switches and the server's answer on when
/// they come and what each covers. The pages say every word themselves
/// (lib/l10n/parts/settings.arb); this holds the state only.
class SettingsProvider extends ChangeNotifier with SessionScopedNotifier {
  SettingsProvider(this._api);

  final SettingsApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _loadFailed = false;
  UserSettings? _settings;
  UserSettings? _draft;

  bool get isLoading => _isLoading;

  /// A switch is being saved: every switch rests until it is done.
  bool get isSubmitting => _isSubmitting;

  /// The switches could not be read and the phone has no copy.
  bool get loadFailed => _loadFailed;
  UserSettings? get settings => _settings;
  UserSettings? get draft => _draft;
  bool get hasChanges =>
      _settings != null && _draft != null && !_settings!.sameValues(_draft!);

  /// D85: the copy stays because the server did not answer.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// The server's reminder table, for the «متى يصلك» lines; null while the
  /// phone has neither a copy nor an answer (the lines are left out).
  ReminderSchedule? get schedule => _notificationSchedule?.reminders;

  /// What each switch covers, for the «يشمل» lines; null as [schedule].
  PreferenceCoverage? get coverage => _notificationSchedule?.coverage;
  NotificationSchedule? _notificationSchedule;

  /// D85: the phone's copy shows at once; the server's answer replaces it.
  Future<void> loadSettings() async {
    await Future.wait([_loadSettings(), _loadSchedule()]);
  }

  /// The answer is the server's and the same for everyone: a failure
  /// leaves the copy (or no lines), never an error on the page.
  Future<void> _loadSchedule() => readCachedFirst<NotificationSchedule>(
    cached: _api.cachedNotificationSchedule,
    remote: () async {
      final answer = await _api.getNotificationSchedule();
      if (answer.isEmpty) {
        throw const FormatException('Unreadable notification schedule');
      }
      return answer;
    },
    isEmpty: (answer) => answer.isEmpty,
    apply: (answer) => _notificationSchedule = answer,
    state: ({required loading, required stale, error}) => notifyListeners(),
    describe: (error) => '',
  );

  Future<void> _loadSettings() async {
    await readCachedFirst<UserSettings>(
      cached: _api.cachedSettings,
      remote: _api.getSettings,
      apply: (settings) {
        _settings = settings;
        _draft = settings;
      },
      state: ({required loading, required stale, error}) {
        _isLoading = loading;
        _isStale = stale;
        _loadFailed = error != null;
        notifyListeners();
      },
      describe: (error) => error.runtimeType.toString(),
    );
  }

  void updateDraft(UserSettings settings) {
    _draft = settings;
    notifyListeners();
  }

  /// Saves the draft; false when the server refused it or could not be
  /// reached without a queue. Without a network the change is kept on the
  /// phone and sent later (D85), which counts as saved.
  Future<bool> saveSettings() async {
    final draft = _draft;
    if (draft == null) return false;
    if (!hasChanges) return true;

    _isSubmitting = true;
    notifyListeners();

    try {
      final saved = await _api.updateSettings(draft);
      _settings = saved;
      _draft = saved;
      return true;
    } on Object {
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
