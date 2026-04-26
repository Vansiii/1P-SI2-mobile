import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:merchanic_repair/data/models/message.dart';

/// Sistema de cache local para mensajes del chat usando Hive
class ChatCache {
  static const String _messagesBoxName = 'chat_messages';
  static const String _metadataBoxName = 'chat_metadata';

  late Box<Map> _messagesBox;
  late Box<Map> _metadataBox;

  bool _initialized = false;

  /// Inicializar Hive y abrir boxes
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();

      _messagesBox = await Hive.openBox<Map>(_messagesBoxName);
      _metadataBox = await Hive.openBox<Map>(_metadataBoxName);

      _initialized = true;
      debugPrint('✅ ChatCache initialized');
    } catch (e) {
      debugPrint('❌ Error initializing ChatCache: $e');
      rethrow;
    }
  }

  /// Verificar si está inicializado
  bool get isInitialized => _initialized;

  /// Guardar mensajes de un incidente
  Future<void> saveMessages(int incidentId, List<Message> messages) async {
    if (!_initialized) {
      debugPrint('⚠️ ChatCache not initialized, skipping save');
      return;
    }

    try {
      final key = 'incident_$incidentId';
      final messagesJson = messages.map((m) => m.toJson()).toList();

      await _messagesBox.put(key, {
        'incident_id': incidentId,
        'messages': messagesJson,
        'cached_at': DateTime.now().toIso8601String(),
      });

      // Actualizar metadata
      await _updateMetadata(incidentId, messages);

      debugPrint(
        '✅ Cached ${messages.length} messages for incident $incidentId',
      );
    } catch (e) {
      debugPrint('❌ Error saving messages to cache: $e');
    }
  }

  /// Obtener mensajes de un incidente
  Future<List<Message>?> getMessages(int incidentId) async {
    if (!_initialized) {
      debugPrint('⚠️ ChatCache not initialized');
      return null;
    }

    try {
      final key = 'incident_$incidentId';
      final data = _messagesBox.get(key);

      if (data == null) {
        debugPrint('ℹ️ No cached messages for incident $incidentId');
        return null;
      }

      final messagesList = data['messages'] as List;
      final messages = messagesList
          .map((json) => Message.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      debugPrint(
        '✅ Loaded ${messages.length} messages from cache for incident $incidentId',
      );
      return messages;
    } catch (e) {
      debugPrint('❌ Error loading messages from cache: $e');
      return null;
    }
  }

  /// Agregar un mensaje nuevo al cache
  Future<void> addMessage(int incidentId, Message message) async {
    if (!_initialized) return;

    try {
      final messages = await getMessages(incidentId) ?? [];

      // Evitar duplicados por ID del servidor
      if (message.id != null && messages.any((m) => m.id == message.id)) {
        debugPrint('⚠️ Message ${message.id} already in cache, skipping');
        return;
      }

      // Evitar duplicados por ID local
      if (message.localId != null &&
          messages.any((m) => m.localId == message.localId)) {
        debugPrint('⚠️ Message ${message.localId} already in cache, skipping');
        return;
      }

      messages.add(message);
      await saveMessages(incidentId, messages);
    } catch (e) {
      debugPrint('❌ Error adding message to cache: $e');
    }
  }

  /// Actualizar un mensaje en el cache
  Future<void> updateMessage(int incidentId, Message updatedMessage) async {
    if (!_initialized) return;

    try {
      final messages = await getMessages(incidentId) ?? [];

      final index = messages.indexWhere((m) {
        // Buscar por ID del servidor
        if (updatedMessage.id != null && m.id == updatedMessage.id) {
          return true;
        }
        // Buscar por ID local
        if (updatedMessage.localId != null &&
            m.localId == updatedMessage.localId) {
          return true;
        }
        return false;
      });

      if (index != -1) {
        messages[index] = updatedMessage;
        await saveMessages(incidentId, messages);
        debugPrint('✅ Updated message in cache');
      } else {
        debugPrint('⚠️ Message not found in cache for update');
      }
    } catch (e) {
      debugPrint('❌ Error updating message in cache: $e');
    }
  }

  /// Eliminar un mensaje del cache
  Future<void> deleteMessage(int incidentId, int messageId) async {
    if (!_initialized) return;

    try {
      final messages = await getMessages(incidentId) ?? [];
      messages.removeWhere((m) => m.id == messageId);
      await saveMessages(incidentId, messages);
      debugPrint('✅ Deleted message from cache');
    } catch (e) {
      debugPrint('❌ Error deleting message from cache: $e');
    }
  }

  /// Obtener metadata de un incidente
  Future<ChatMetadata?> getMetadata(int incidentId) async {
    if (!_initialized) return null;

    try {
      final key = 'metadata_$incidentId';
      final data = _metadataBox.get(key);

      if (data == null) return null;

      return ChatMetadata.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('❌ Error loading metadata: $e');
      return null;
    }
  }

  /// Actualizar metadata de un incidente
  Future<void> _updateMetadata(int incidentId, List<Message> messages) async {
    try {
      if (messages.isEmpty) return;

      // Buscar el último mensaje con ID del servidor
      final messagesWithId = messages.where((m) => m.id != null).toList();
      if (messagesWithId.isEmpty) return;

      messagesWithId.sort(
        (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
          b.createdAt ?? DateTime.now(),
        ),
      );
      final lastMessage = messagesWithId.last;

      final metadata = ChatMetadata(
        incidentId: incidentId,
        lastMessageId: lastMessage.id,
        lastMessageAt: lastMessage.createdAt ?? DateTime.now(),
        lastSyncAt: DateTime.now(),
        messageCount: messages.length,
      );

      final key = 'metadata_$incidentId';
      await _metadataBox.put(key, metadata.toJson());
    } catch (e) {
      debugPrint('❌ Error updating metadata: $e');
    }
  }

  /// Limpiar cache de un incidente
  Future<void> clearIncident(int incidentId) async {
    if (!_initialized) return;

    try {
      await _messagesBox.delete('incident_$incidentId');
      await _metadataBox.delete('metadata_$incidentId');
      debugPrint('✅ Cleared cache for incident $incidentId');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Limpiar todo el cache
  Future<void> clearAll() async {
    if (!_initialized) return;

    try {
      await _messagesBox.clear();
      await _metadataBox.clear();
      debugPrint('✅ Cleared all cache');
    } catch (e) {
      debugPrint('❌ Error clearing all cache: $e');
    }
  }

  /// Cerrar boxes
  Future<void> close() async {
    if (!_initialized) return;

    try {
      await _messagesBox.close();
      await _metadataBox.close();
      _initialized = false;
      debugPrint('✅ ChatCache closed');
    } catch (e) {
      debugPrint('❌ Error closing ChatCache: $e');
    }
  }

  /// Obtener estadísticas del cache
  Map<String, dynamic> getStats() {
    if (!_initialized) {
      return {'initialized': false};
    }

    return {
      'initialized': true,
      'messages_count': _messagesBox.length,
      'metadata_count': _metadataBox.length,
    };
  }
}

/// Metadata de un chat
class ChatMetadata {
  final int incidentId;
  final int? lastMessageId;
  final DateTime lastMessageAt;
  final DateTime lastSyncAt;
  final int messageCount;

  ChatMetadata({
    required this.incidentId,
    this.lastMessageId,
    required this.lastMessageAt,
    required this.lastSyncAt,
    required this.messageCount,
  });

  factory ChatMetadata.fromJson(Map<String, dynamic> json) {
    return ChatMetadata(
      incidentId: json['incident_id'],
      lastMessageId: json['last_message_id'],
      lastMessageAt: DateTime.parse(json['last_message_at']),
      lastSyncAt: DateTime.parse(json['last_sync_at']),
      messageCount: json['message_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'incident_id': incidentId,
      'last_message_id': lastMessageId,
      'last_message_at': lastMessageAt.toIso8601String(),
      'last_sync_at': lastSyncAt.toIso8601String(),
      'message_count': messageCount,
    };
  }
}
