import 'package:hive_flutter/hive_flutter.dart';
import 'package:merchanic_repair/data/models/message.dart';

/// Servicio de cache local para mensajes de chat usando Hive
class ChatCache {
  static const String _boxName = 'chat_messages';
  static Box<Map>? _box;

  /// Inicializa Hive y abre la caja de mensajes
  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<Map>(_boxName);
    } catch (e) {
      print('[ChatCache] Error initializing: $e');
    }
  }

  /// Guarda todos los mensajes de un incidente (reemplaza cache existente)
  static Future<void> saveMessages(
    int incidentId,
    List<Message> messages,
  ) async {
    if (_box == null) return;

    try {
      final key = 'incident_$incidentId';
      final messagesJson = messages
          .where((m) => !m.isTemporary) // No cachear mensajes temporales
          .map((m) => m.toJson())
          .toList();

      await _box!.put(key, {
        'incident_id': incidentId,
        'messages': messagesJson,
        'cached_at': DateTime.now().toIso8601String(),
      });

      print(
        '[ChatCache] Saved ${messagesJson.length} messages for incident $incidentId',
      );
    } catch (e) {
      print('[ChatCache] Error saving messages: $e');
    }
  }

  /// Obtiene mensajes cacheados de un incidente
  static Future<List<Message>> getMessages(int incidentId) async {
    if (_box == null) return [];

    try {
      final key = 'incident_$incidentId';
      final Map? data = _box!.get(key);

      if (data == null) return [];

      final messagesList = data['messages'] as List?;
      if (messagesList == null) return [];

      final messages = messagesList
          .map((json) => Message.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      print(
        '[ChatCache] Loaded ${messages.length} messages from cache for incident $incidentId',
      );
      return messages;
    } catch (e) {
      print('[ChatCache] Error loading messages: $e');
      return [];
    }
  }

  /// Agrega un mensaje nuevo al cache (sin reemplazar todo)
  static Future<void> addMessage(Message message) async {
    if (_box == null || message.isTemporary) return;

    try {
      final key = 'incident_${message.incidentId}';
      final Map? data = _box!.get(key);

      if (data == null) {
        // Si no existe cache, crear uno nuevo
        await saveMessages(message.incidentId, [message]);
        return;
      }

      final messagesList = List<Map>.from(data['messages'] as List? ?? []);

      // Verificar si el mensaje ya existe (por ID)
      final existingIndex = messagesList.indexWhere(
        (m) => m['id'] == message.id,
      );

      if (existingIndex != -1) {
        // Actualizar mensaje existente
        messagesList[existingIndex] = message.toJson();
      } else {
        // Agregar nuevo mensaje
        messagesList.add(message.toJson());
      }

      await _box!.put(key, {
        'incident_id': message.incidentId,
        'messages': messagesList,
        'cached_at': DateTime.now().toIso8601String(),
      });

      print('[ChatCache] Added/updated message ${message.id} to cache');
    } catch (e) {
      print('[ChatCache] Error adding message: $e');
    }
  }

  /// Actualiza el estado de un mensaje en el cache
  static Future<void> updateMessageStatus(
    int incidentId,
    int messageId,
    Map<String, dynamic> updates,
  ) async {
    if (_box == null) return;

    try {
      final key = 'incident_$incidentId';
      final Map? data = _box!.get(key);

      if (data == null) return;

      final messagesList = List<Map>.from(data['messages'] as List? ?? []);
      final messageIndex = messagesList.indexWhere((m) => m['id'] == messageId);

      if (messageIndex != -1) {
        messagesList[messageIndex] = {
          ...messagesList[messageIndex],
          ...updates,
        };

        await _box!.put(key, {
          'incident_id': incidentId,
          'messages': messagesList,
          'cached_at': DateTime.now().toIso8601String(),
        });

        print('[ChatCache] Updated message $messageId status');
      }
    } catch (e) {
      print('[ChatCache] Error updating message status: $e');
    }
  }

  /// Limpia cache de un incidente específico
  static Future<void> clearIncident(int incidentId) async {
    if (_box == null) return;

    try {
      final key = 'incident_$incidentId';
      await _box!.delete(key);
      print('[ChatCache] Cleared cache for incident $incidentId');
    } catch (e) {
      print('[ChatCache] Error clearing incident cache: $e');
    }
  }

  /// Limpia todo el cache de mensajes
  static Future<void> clearAll() async {
    if (_box == null) return;

    try {
      await _box!.clear();
      print('[ChatCache] Cleared all chat cache');
    } catch (e) {
      print('[ChatCache] Error clearing all cache: $e');
    }
  }

  /// Limpia mensajes antiguos (más de 30 días)
  static Future<void> clearOldCache() async {
    if (_box == null) return;

    try {
      final now = DateTime.now();
      final keysToDelete = <String>[];

      for (var key in _box!.keys) {
        final Map? data = _box!.get(key);
        if (data == null) continue;

        final cachedAtStr = data['cached_at'] as String?;
        if (cachedAtStr == null) continue;

        final cachedAt = DateTime.parse(cachedAtStr);
        final age = now.difference(cachedAt);

        if (age.inDays > 30) {
          keysToDelete.add(key.toString());
        }
      }

      for (var key in keysToDelete) {
        await _box!.delete(key);
      }

      print('[ChatCache] Cleared ${keysToDelete.length} old caches');
    } catch (e) {
      print('[ChatCache] Error clearing old cache: $e');
    }
  }

  /// Obtiene el tamaño del cache en bytes (aproximado)
  static int getCacheSize() {
    if (_box == null) return 0;
    return _box!.length;
  }

  /// Cierra la caja de Hive
  static Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
