import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/settings_api.dart';
import '../models/user_settings.dart';

class SettingsProvider extends ChangeNotifier with SessionScopedNotifier {
  SettingsProvider(this._api);

  final SettingsApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  UserSettings? _settings;
  UserSettings? _draft;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  UserSettings? get settings => _settings;
  UserSettings? get draft => _draft;
  bool get hasChanges =>
      _settings != null && _draft != null && !_settings!.sameValues(_draft!);

  /// D85: the copy stays because the server did not answer.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// D85: the phone's copy shows at once; the server's answer replaces it.
  Future<void> loadSettings() async {
    _successMessage = null;
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
        _errorMessage = error;
        notifyListeners();
      },
      describe: (error) =>
          error is ApiException ? error.message : 'ما قدرنا نجيب الإعدادات.',
    );
  }

  void updateDraft(UserSettings settings) {
    _draft = settings;
    _successMessage = null;
    notifyListeners();
  }

  Future<bool> saveSettings() async {
    final draft = _draft;
    if (draft == null) return false;
    if (!hasChanges) {
      _successMessage = 'ما في تغييرات نحفظها.';
      notifyListeners();
      return true;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final saved = await _api.updateSettings(draft);
      _settings = saved;
      _draft = saved;
      _successMessage = 'تم حفظ الإعدادات.';
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'ما انحفظت الإعدادات الحين. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
