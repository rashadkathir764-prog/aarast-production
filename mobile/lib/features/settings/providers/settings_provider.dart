import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/settings_api.dart';
import '../models/user_settings.dart';

class SettingsProvider extends ChangeNotifier {
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

  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final settings = await _api.getSettings();
      _settings = settings;
      _draft = settings;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل الإعدادات.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      _successMessage = 'لا توجد تغييرات للحفظ.';
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
      _errorMessage = 'تعذر حفظ الإعدادات.';
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
