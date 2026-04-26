import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A thin caching layer backed by [FlutterSecureStorage] for persisting the
/// last known WebSocket state across app restarts.
///
/// All keys are prefixed with `ws_cache_` to avoid collisions with other
/// secure-storage entries.
class WebSocketCache {
  WebSocketCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _keyPrefix = 'ws_cache_';

  /// Whether the device is currently offline.
  ///
  /// Set this externally (e.g. from a connectivity listener) to control the
  /// [offlineBannerVisible] getter.
  bool isOffline = false;

  /// Returns `true` when the app is offline and the offline banner should be
  /// shown to the user.
  bool get offlineBannerVisible => isOffline;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Stores [jsonValue] under the prefixed [key].
  Future<void> cacheState(String key, String jsonValue) async {
    try {
      await _storage.write(key: '$_keyPrefix$key', value: jsonValue);
    } catch (e) {
      debugPrint('[WebSocketCache] cacheState error for key=$key: $e');
    }
  }

  /// Retrieves the cached JSON string for [key], or `null` if not found.
  Future<String?> getCachedState(String key) async {
    try {
      return await _storage.read(key: '$_keyPrefix$key');
    } catch (e) {
      debugPrint('[WebSocketCache] getCachedState error for key=$key: $e');
      return null;
    }
  }

  /// Removes all entries whose keys start with [_keyPrefix].
  Future<void> clearCache() async {
    try {
      final all = await _storage.readAll();
      for (final entry in all.entries) {
        if (entry.key.startsWith(_keyPrefix)) {
          await _storage.delete(key: entry.key);
        }
      }
      debugPrint('[WebSocketCache] Cache cleared.');
    } catch (e) {
      debugPrint('[WebSocketCache] clearCache error: $e');
    }
  }
}
