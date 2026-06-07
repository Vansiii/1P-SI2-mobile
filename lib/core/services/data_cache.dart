import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class DataCache {
  static const String _boxName = 'offline_data_cache';
  static Box<Map>? _box;
  static int? _currentUserId;

  static int? get currentUserId => _currentUserId;
  static set currentUserId(int? id) => _currentUserId = id;

  static Future<void> init() async {
    try {
      _box = await Hive.openBox<Map>(_boxName);
    } catch (e) {
      print('[DataCache] Init error: $e');
    }
  }

  static String scopedKey(String key, int userId) => '${key}_$userId';

  static Future<void> putScoped(String key, int userId, dynamic data) async {
    await put(scopedKey(key, userId), data);
  }

  static dynamic getScoped(String key, int userId) {
    return get(scopedKey(key, userId));
  }

  static Future<void> putWithTtl(
    String key,
    dynamic data, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    if (_box == null) return;
    try {
      await _box!.put(key, {
        'data': jsonEncode(data),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
        'ttl_hours': ttl.inHours,
      });
    } catch (e) {
      print('[DataCache] Save error for $key: $e');
    }
  }

  static Future<void> putScopedWithTtl(
    String key,
    int userId,
    dynamic data, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    await putWithTtl(scopedKey(key, userId), data, ttl: ttl);
  }

  static dynamic getWithTtl(String key) {
    if (_box == null) return null;
    try {
      final entry = _box!.get(key);
      if (entry == null) return null;
      final cachedAt = DateTime.tryParse(entry['cached_at'] as String? ?? '');
      if (cachedAt == null) return null;
      final ttlHours = entry['ttl_hours'] as int? ?? 24;
      if (DateTime.now().toUtc().difference(cachedAt).inHours > ttlHours) {
        return null;
      }
      return jsonDecode(entry['data'] as String);
    } catch (e) {
      print('[DataCache] TTL load error for $key: $e');
      return null;
    }
  }

  static dynamic getScopedWithTtl(String key, int userId) {
    return getWithTtl(scopedKey(key, userId));
  }

  static Future<void> put(String key, dynamic data) async {
    await putWithTtl(key, data);
  }

  static dynamic get(String key) {
    return getWithTtl(key);
  }

  static Future<void> clear() async {
    if (_box == null) return;
    await _box!.clear();
  }

  static Future<void> removeScoped(String key, int userId) async {
    if (_box == null) return;
    await _box!.delete(scopedKey(key, userId));
  }
}
