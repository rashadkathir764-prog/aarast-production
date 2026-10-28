import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/sync_queue.dart' show nextLocalId;
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../../core/utils/app_clock.dart';
import '../data/rafd_api.dart';
import '../data/rafd_outbox.dart';
import '../models/rafd.dart';

/// D66: the plan owner's rafd book. A gift written in b06 is kept on the
/// phone first and sent when the network allows; the book (e09), the
/// thanks (e10) and b05's card read the server's entries with the waiting
/// ones on top.
class RafdProvider extends ChangeNotifier with SessionScopedNotifier {
  RafdProvider({
    required this.api,
    required this.outbox,
    required this.userId,
  });

  final RafdApi api;
  final RafdOutbox outbox;

  /// The signed-in account; its waiting entries are its own.
  final String? userId;

  RafdBook? _book;
  bool _isLoading = false;
  bool _flushing = false;
  String? _errorMessage;
  int _loadGeneration = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// The entries written on this phone that wait for the network.
  List<RafdEntry> pendingOf(String weddingPlanId) {
    final user = userId;
    if (user == null) return const [];
    return outbox.read(user, weddingPlanId);
  }

  /// The book with the waiting entries on top, once the server's is read.
  RafdBook? bookOf(String weddingPlanId) {
    final book = _book;
    if (book == null || book.weddingPlanId != weddingPlanId) return null;
    return book.withPending(pendingOf(weddingPlanId));
  }

  Future<void> load(String weddingPlanId) async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    if (_book?.weddingPlanId != weddingPlanId) _book = null;
    notifyListeners();
    await flush(weddingPlanId);
    try {
      final book = await api.list(weddingPlanId);
      if (generation != _loadGeneration || isSessionDisposed) return;
      _book = book;
    } on ApiException catch (error) {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _errorMessage = error.message;
      }
    } finally {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// b06 «حفظ وسجّل التالي»: kept on the phone at once, then sent.
  Future<void> record(
    String weddingPlanId, {
    required String giverName,
    required num amount,
  }) async {
    final user = userId;
    if (user == null) {
      throw const ApiException('سجّل دخولك عشان ينحفظ الرفد.');
    }
    final entry = RafdEntry(
      clientId: nextLocalId('rafd'),
      giverName: giverName.trim(),
      amount: amount,
      recordedAt: appNow(),
      pending: true,
    );
    await outbox.write(user, weddingPlanId, [
      ...outbox.read(user, weddingPlanId),
      entry,
    ]);
    notifyListeners();
    await flush(weddingPlanId);
  }

  /// Sends the waiting entries as one batch. A lost network keeps them for
  /// the next try; a refusal keeps them too and says so (a gift is never
  /// dropped silently). After a send the book is read again.
  Future<void> flush(String weddingPlanId) async {
    final user = userId;
    if (user == null || _flushing) return;
    final waiting = outbox.read(user, weddingPlanId);
    if (waiting.isEmpty) return;
    _flushing = true;
    try {
      for (var start = 0; start < waiting.length; start += _batchSize) {
        final batch = waiting.skip(start).take(_batchSize).toList();
        await api.sendBatch(weddingPlanId, batch);
        final sent = {for (final entry in batch) entry.clientId};
        await outbox.write(user, weddingPlanId, [
          for (final left in outbox.read(user, weddingPlanId))
            if (!sent.contains(left.clientId)) left,
        ]);
      }
      final book = await api.list(weddingPlanId);
      if (!isSessionDisposed) _book = book;
    } on ApiException catch (error) {
      if (!error.isAmbiguousMutationFailure && !isSessionDisposed) {
        _errorMessage = 'الرفد محفوظ في جوالك وما وصل: ${error.message}';
      }
    } finally {
      _flushing = false;
      if (!isSessionDisposed) notifyListeners();
    }
  }

  /// e10: [entries] were sent their thanks from WhatsApp.
  Future<void> markThanked(String weddingPlanId, List<RafdEntry> entries) async {
    final ids = [
      for (final entry in entries)
        if (entry.id != null) entry.id!,
    ];
    if (ids.isEmpty) return;
    await api.markThanked(weddingPlanId, ids);
    final book = await api.list(weddingPlanId);
    if (isSessionDisposed) return;
    _book = book;
    notifyListeners();
  }

  /// e09: an entry written by mistake goes; one still on the phone leaves
  /// the phone.
  Future<void> remove(String weddingPlanId, RafdEntry entry) async {
    final user = userId;
    if (entry.pending) {
      if (user == null) return;
      await outbox.write(user, weddingPlanId, [
        for (final left in outbox.read(user, weddingPlanId))
          if (left.clientId != entry.clientId) left,
      ]);
      notifyListeners();
      return;
    }
    await api.remove(weddingPlanId, entry.id!);
    final book = await api.list(weddingPlanId);
    if (isSessionDisposed) return;
    _book = book;
    notifyListeners();
  }

  static const _batchSize = 100;
}
