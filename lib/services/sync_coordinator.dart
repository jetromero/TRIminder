import 'dart:async';

/// Central coordinator to deduplicate sync triggers and serialize runs.
class SyncCoordinator {
  static final SyncCoordinator _instance = SyncCoordinator._internal();
  factory SyncCoordinator() => _instance;
  SyncCoordinator._internal();

  bool _isSyncing = false;
  Timer? _debounceTimer;
  Completer<bool>? _activeCompleter;

  /// Request a sync. Calls [runner] once after a debounce window and ensures
  /// only one sync runs at a time. Subsequent callers await the same future.
  Future<bool> requestSync(Future<bool> Function() runner, {Duration debounce = const Duration(seconds: 30)}) async {
    // If a sync is currently running, await the existing completer
    if (_isSyncing && _activeCompleter != null) {
      return _activeCompleter!.future;
    }

    // Debounce multiple rapid triggers
    _debounceTimer?.cancel();
    final completer = _activeCompleter ?? Completer<bool>();
    _activeCompleter = completer;

    _debounceTimer = Timer(debounce, () async {
      if (_isSyncing) return; // Another guard
      _isSyncing = true;
      try {
        final ok = await runner();
        if (!completer.isCompleted) completer.complete(ok);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(false);
      } finally {
        _isSyncing = false;
        _activeCompleter = null;
      }
    });

    return completer.future;
  }
}


