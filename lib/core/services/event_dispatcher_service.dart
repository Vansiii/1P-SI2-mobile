// Event dispatcher service for the Flutter mobile application.
//
// Responsibilities (Requirements 2.8, 2.11):
// - Subscribes to [WebSocketService.events] and parses raw JSON into typed
//   [RealTimeEvent] instances using [RealTimeEvent.fromJson] and [EventValidator].
// - Deduplicates events using an [EventCache] with a 1-hour TTL.
// - Routes typed events to per-type broadcast [StreamController]s.
// - Queues incoming events while disconnected and drains the queue on
//   reconnection (offline queue management).
// - Exposes [getStream<T>] for subscribing to a specific event type.
// - Disposes all resources cleanly via [dispose].

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';

import '../models/realtime_event.dart';
// Use the legacy WebSocketService that actually connects to WebSocket endpoints
import '../../services/websocket_service.dart';
// Import ConnectionStatus for connection state handling
import '../websocket/connection_status.dart';

// ── EventCache ────────────────────────────────────────────────────────────────

/// Stores processed event IDs with their processing timestamps.
///
/// [contains] returns `true` only when the event was processed within [ttl].
/// [cleanup] removes entries older than [ttl] to bound memory usage.
class EventCache {
  EventCache({this.ttl = const Duration(hours: 1)});

  /// Time-to-live for each cache entry.
  final Duration ttl;

  final Map<String, DateTime> _entries = {};

  /// Records [eventId] as processed at [timestamp].
  void add(String eventId, DateTime timestamp) {
    _entries[eventId] = timestamp;
  }

  /// Returns `true` if [eventId] was processed within [ttl] of now.
  bool contains(String eventId) {
    final ts = _entries[eventId];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < ttl;
  }

  /// Removes all entries older than [ttl].
  void cleanup() {
    final cutoff = DateTime.now().subtract(ttl);
    _entries.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  /// Number of entries currently in the cache (for diagnostics).
  int get size => _entries.length;
}

// ── EventDispatcherService ────────────────────────────────────────────────────

/// Routes typed [RealTimeEvent]s from [WebSocketService] to per-type streams.
///
/// Usage:
/// ```dart
/// final dispatcher = EventDispatcherService();
/// dispatcher.initialize();
///
/// dispatcher
///   .getStream<IncidentCreatedEvent>('incident.created')
///   .listen((e) { /* handle */ });
///
/// // On widget/service disposal:
/// dispatcher.dispose();
/// ```
class EventDispatcherService {
  EventDispatcherService({
    WebSocketService? webSocketService,
    EventCache? cache,
  }) : _webSocketService =
           webSocketService ?? WebSocketService(StorageService()),
       _cache = cache ?? EventCache();

  final WebSocketService _webSocketService;
  final EventCache _cache;
  final EventValidator _validator = const EventValidator();

  // ── Internal state ─────────────────────────────────────────────────────────

  /// Per-event-type broadcast controllers.
  final Map<String, StreamController<RealTimeEvent>> _controllers = {};

  /// Events received while disconnected, waiting to be processed.
  final List<Map<String, dynamic>> _offlineQueue = [];

  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  StreamSubscription<ConnectionStatus>? _stateSubscription;

  bool _disposed = false;
  bool _isConnected = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Starts listening to [WebSocketService.events] and connection state.
  ///
  /// Must be called once before subscribing to any typed streams.
  void initialize() {
    if (_disposed) {
      debugPrint(
        '[EventDispatcherService] initialize() called after dispose — ignored.',
      );
      return;
    }

    // Track connection state to manage the offline queue.
    _stateSubscription = _webSocketService.connectionState.listen(
      _onConnectionStateChanged,
    );

    // Seed initial connected state.
    _isConnected = _webSocketService.isConnected;

    // Subscribe to raw events.
    _eventSubscription = _webSocketService.events.listen(
      _onRawEvent,
      onError: (Object err) {
        debugPrint('[EventDispatcherService] events stream error: $err');
      },
    );

    debugPrint('[EventDispatcherService] Initialized.');
  }

  /// Returns a typed broadcast stream for [eventType].
  ///
  /// Multiple calls with the same [eventType] return the same stream.
  /// [T] should be the concrete [RealTimeEvent] subclass for that type.
  Stream<T> getStream<T extends RealTimeEvent>(String eventType) {
    return _controllerFor(eventType).stream.cast<T>();
  }

  /// Number of events currently queued for offline delivery.
  int get offlineQueueLength => _offlineQueue.length;

  /// Releases all resources.
  ///
  /// After calling [dispose] this service must not be used again.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _eventSubscription?.cancel();
    _stateSubscription?.cancel();

    for (final controller in _controllers.values) {
      if (!controller.isClosed) controller.close();
    }
    _controllers.clear();
    _offlineQueue.clear();

    debugPrint('[EventDispatcherService] Disposed — all resources released.');
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Returns (or lazily creates) the broadcast controller for [eventType].
  StreamController<RealTimeEvent> _controllerFor(String eventType) {
    return _controllers.putIfAbsent(
      eventType,
      () => StreamController<RealTimeEvent>.broadcast(),
    );
  }

  /// Handles connection state changes to manage the offline queue.
  void _onConnectionStateChanged(ConnectionStatus status) {
    final wasConnected = _isConnected;
    _isConnected = status == ConnectionStatus.connected;

    if (!wasConnected && _isConnected) {
      debugPrint(
        '[EventDispatcherService] Reconnected — draining offline queue '
        '(${_offlineQueue.length} events).',
      );
      _drainOfflineQueue();
    }
  }

  /// Processes a raw JSON event from the WebSocket.
  ///
  /// When disconnected, the event is added to [_offlineQueue] instead.
  void _onRawEvent(Map<String, dynamic> raw) {
    if (_disposed) return;

    if (!_isConnected) {
      _enqueueOffline(raw);
      return;
    }

    _processRawEvent(raw);
  }

  /// Parses, validates, deduplicates, and routes a single raw event map.
  void _processRawEvent(Map<String, dynamic> raw) {
    // ── 1. Parse ──────────────────────────────────────────────────────────
    RealTimeEvent event;
    try {
      // Validate schema first; returns null for invalid events.
      final validation = _validator.validate(raw);
      if (!validation.isValid) {
        debugPrint(
          '[EventDispatcherService] Invalid event schema — skipping. '
          'Errors: ${validation.errors}',
        );
        return;
      }

      event = RealTimeEvent.fromJson(raw);
    } on UnknownEventTypeException catch (e) {
      debugPrint('[EventDispatcherService] Unknown event type: $e — skipping.');
      return;
    } catch (e) {
      debugPrint(
        '[EventDispatcherService] Failed to parse event: $e — skipping.',
      );
      return;
    }

    // ── 2. Deduplicate ────────────────────────────────────────────────────
    if (_cache.contains(event.eventId)) {
      debugPrint(
        '[EventDispatcherService] Duplicate event ${event.eventId} '
        '(${event.eventType}) — skipping.',
      );
      return;
    }

    final now = DateTime.now();
    _cache.add(event.eventId, now);

    // Periodically clean up stale cache entries.
    if (_cache.size % 50 == 0) {
      _cache.cleanup();
    }

    // ── 3. Route ──────────────────────────────────────────────────────────
    _routeEvent(event);
  }

  /// Emits [event] to the appropriate typed stream controller.
  void _routeEvent(RealTimeEvent event) {
    final controller = _controllerFor(event.eventType);
    if (!controller.isClosed) {
      controller.add(event);
      debugPrint(
        '[EventDispatcherService] Routed ${event.eventType} '
        '(id: ${event.eventId}).',
      );
    }
  }

  /// Adds a raw event to the offline queue (bounded to 100 entries).
  void _enqueueOffline(Map<String, dynamic> raw) {
    const maxQueueSize = 100;
    if (_offlineQueue.length >= maxQueueSize) {
      debugPrint(
        '[EventDispatcherService] Offline queue full ($maxQueueSize) — '
        'dropping oldest event.',
      );
      _offlineQueue.removeAt(0);
    }
    _offlineQueue.add(raw);
    debugPrint(
      '[EventDispatcherService] Queued event offline '
      '(queue size: ${_offlineQueue.length}).',
    );
  }

  /// Processes all queued offline events in FIFO order.
  void _drainOfflineQueue() {
    final snapshot = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();

    for (final raw in snapshot) {
      if (_disposed) break;
      _processRawEvent(raw);
    }

    debugPrint(
      '[EventDispatcherService] Offline queue drained '
      '(${snapshot.length} events processed).',
    );
  }
}
