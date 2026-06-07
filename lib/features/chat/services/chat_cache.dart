import 'package:hive_flutter/hive_flutter.dart';
import 'package:merchanic_repair/data/models/message.dart';
import 'package:merchanic_repair/data/models/message_status.dart';

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
      final messagesJson = _dedupeMessages(messages).map((m) => m.toJson()).toList();

      await _box!.put(key, {
        'incident_id': incidentId,
        'conversation_id': messagesJson.isNotEmpty
            ? (messagesJson.last['conversation_id'] ?? messagesJson.first['conversation_id'] ?? 0)
            : 0,
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
      final deduped = _dedupeMessages(messages);

      print(
        '[ChatCache] Loaded ${deduped.length} messages from cache for incident $incidentId',
      );
      return deduped;
    } catch (e) {
      print('[ChatCache] Error loading messages: $e');
      return [];
    }
  }

  /// Agrega un mensaje nuevo al cache (sin reemplazar todo)
  static Future<void> addMessage(Message message) async {
      if (_box == null) return;

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
        final existingMessage = Message.fromJson(
          Map<String, dynamic>.from(messagesList[existingIndex]),
        );
        messagesList[existingIndex] =
            _mergeMessageVersions(existingMessage, message).toJson();
      } else if (_containsDuplicateSystemMessage(messagesList, message)) {
        return;
      } else {
        // Agregar nuevo mensaje
        messagesList.add(message.toJson());
      }

      await _box!.put(key, {
        'incident_id': message.incidentId,
        'conversation_id': message.conversationId,
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
          'conversation_id': data['conversation_id'] ?? 0,
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

  static Future<int?> getConversationId(int incidentId) async {
    if (_box == null) return null;

    try {
      final key = 'incident_$incidentId';
      final Map? data = _box!.get(key);
      final raw = data?['conversation_id'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return null;
    } catch (e) {
      print('[ChatCache] Error reading conversation id: $e');
      return null;
    }
  }

  static List<Message> _dedupeMessages(List<Message> source) {
    final sorted = [...source]
      ..sort(
        (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
          b.createdAt ?? DateTime.now(),
        ),
      );

    final deduped = <Message>[];
    for (final message in sorted) {
      final existingIndex = message.id == null
          ? -1
          : deduped.indexWhere((entry) => entry.id == message.id);

      if (existingIndex != -1) {
        deduped[existingIndex] = _mergeMessageVersions(
          deduped[existingIndex],
          message,
        );
        continue;
      }

      final lastMessage = deduped.isEmpty ? null : deduped.last;
      if (lastMessage != null &&
          _isDuplicateSystemMessage(lastMessage, message)) {
        deduped[deduped.length - 1] = message;
        continue;
      }

      deduped.add(message);
    }

    return deduped;
  }

  static bool _containsDuplicateSystemMessage(
    List<Map> messagesList,
    Message incoming,
  ) {
    final existingMessages = messagesList
        .map((json) => Message.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    return existingMessages.any(
      (existing) => _isDuplicateSystemMessage(existing, incoming),
    );
  }

  static bool _isDuplicateSystemMessage(Message previous, Message incoming) {
    if (previous.type != 'system' || incoming.type != 'system') {
      return false;
    }

    if (
        previous.conversationId != incoming.conversationId ||
        previous.incidentId != incoming.incidentId ||
        previous.senderId != incoming.senderId) {
      return false;
    }

    final previousText = previous.message.trim();
    final incomingText = incoming.message.trim();
    if (previousText.isEmpty || previousText != incomingText) {
      return false;
    }

    final previousTime = previous.createdAt ?? DateTime.now();
    final incomingTime = incoming.createdAt ?? DateTime.now();
    return incomingTime.difference(previousTime).inMinutes.abs() <= 2;
  }

  static Message _mergeMessageVersions(Message current, Message incoming) {
    final mergedStatus = _messageStatusRank(incoming.status) >=
            _messageStatusRank(current.status)
        ? incoming.status
        : current.status;

    return current.copyWith(
      id: incoming.id ?? current.id,
      localId: current.localId ?? incoming.localId,
      senderName: incoming.senderName ?? current.senderName,
      senderRole: incoming.senderRole ?? current.senderRole,
      message: incoming.message.isNotEmpty ? incoming.message : current.message,
      type: incoming.type.isNotEmpty ? incoming.type : current.type,
      createdAt: incoming.createdAt ?? current.createdAt,
      sentAt: incoming.sentAt ?? current.sentAt ?? incoming.createdAt,
      deliveredAt: incoming.deliveredAt ?? current.deliveredAt,
      readAt: incoming.readAt ?? current.readAt,
      status: mergedStatus,
      errorMessage: incoming.errorMessage ?? current.errorMessage,
      isRead: incoming.isRead ?? current.isRead,
      isTemporary: incoming.isTemporary && current.id == null,
    );
  }

  static int _messageStatusRank(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return 0;
      case MessageStatus.sent:
        return 1;
      case MessageStatus.delivered:
        return 2;
      case MessageStatus.read:
        return 3;
      case MessageStatus.failed:
        return -1;
    }
  }
}
