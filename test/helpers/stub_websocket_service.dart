import 'dart:async';

import 'package:merchanic_repair/core/websocket/connection_status.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

/// A test stub for [WebSocketService] that allows emitting events directly
/// without a real WebSocket connection.
///
/// Usage:
/// ```dart
/// final stub = StubWebSocketService();
/// stub.emit(EventType.incidentCreated, {'incident_id': 1, ...});
/// ```
class StubWebSocketService extends WebSocketService {
  final Map<EventType, StreamController<WebSocketEvent>> _stubControllers = {};

  StubWebSocketService() : super();

  /// Emits a [WebSocketEvent] of [type] with [data] to all listeners.
  void emit(EventType type, Map<String, dynamic> data) {
    _stubControllers.putIfAbsent(
      type,
      () => StreamController<WebSocketEvent>.broadcast(),
    );
    _stubControllers[type]!.add(
      WebSocketEvent(
        type: type,
        data: data,
        timestamp: DateTime.utc(2024, 1, 1),
      ),
    );
  }

  @override
  Stream<WebSocketEvent> getEventStream(EventType type) {
    _stubControllers.putIfAbsent(
      type,
      () => StreamController<WebSocketEvent>.broadcast(),
    );
    return _stubControllers[type]!.stream;
  }

  @override
  Stream<ConnectionStatus> get connectionStatus => const Stream.empty();

  @override
  bool get isConnected => false;

  void closeStubControllers() {
    for (final c in _stubControllers.values) {
      c.close();
    }
    _stubControllers.clear();
  }
}
