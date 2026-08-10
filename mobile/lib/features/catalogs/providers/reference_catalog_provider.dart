import 'package:flutter/foundation.dart';

import '../data/reference_catalog_api.dart';
import '../models/reference_catalog.dart';

class ReferenceCatalogProvider extends ChangeNotifier {
  ReferenceCatalogProvider(this._api);

  final ReferenceCatalogApi _api;
  ReferenceCatalogBootstrap? _bootstrap;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get version => _bootstrap?.version;

  ManagedReferenceCatalog? catalogFor(String key) {
    for (final catalog in _bootstrap?.catalogs ?? const []) {
      if (catalog.key == key) return catalog;
    }
    return null;
  }

  Future<void> load({bool refresh = false}) async {
    if (_isLoading || (!refresh && _bootstrap != null)) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final next = await _api.load();
      if (next != null) _bootstrap = next;
    } catch (_) {
      _errorMessage = 'تعذر تحديث القوائم الآن. نعرض النسخة المحفوظة.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
