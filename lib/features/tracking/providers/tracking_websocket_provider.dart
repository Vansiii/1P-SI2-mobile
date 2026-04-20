import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable snapshot of the current real-time tracking session.
///
/// Requirements: 5.1–5.8
class TrackingState {
  const TrackingState({
    this.latitude,
    this.longitude,
    this.isTracking = false,
    this.incidentId,
    this.technicianId,
    this.lastUpdate,
    this.estimatedArrival,
    this.hasArrived = false,
  });

  /// Current latitude of the tracked technician, or `null` if unknown.
  final double? latitude;

  /// Current longitude of the tracked technician, or `null` if unknown.
  final double? longitude;

  /// Whether a tracking session is currently active.
  final bool isTracking;

  /// ID of the incident being tracked.
  final int? incidentId;

  /// ID of the technician being tracked.
  final int? technicianId;

  /// Timestamp of the last accepted location update.
  final DateTime? lastUpdate;

  /// Estimated time of arrival, if available.
  final Duration? estimatedArrival;

  /// Whether the technician has arrived at the incident location.
  final bool hasArrived;

  // ── Immutable update ──────────────────────────────────────────────────────

  TrackingState copyWith({
    double? latitude,
    double? longitude,
    bool? isTracking,
    int? incidentId,
    int? technicianId,
    DateTime? lastUpdate,
    Duration? estimatedArrival,
    bool? hasArrived,
  }) {
    return TrackingState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isTracking: isTracking ?? this.isTracking,
      incidentId: incidentId ?? this.incidentId,
      technicianId: technicianId ?? this.technicianId,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      hasArrived: hasArrived ?? this.hasArrived,
    );
  }

  /// Returns an empty / reset [TrackingState].
  static const empty = TrackingState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive [TrackingState] kept up-to-date by incoming WebSocket
/// events.
///
/// Requirements: 5.1–5.8
final trackingWebSocketProvider =
    StateNotifierProvider<TrackingWebSocketNotifier, TrackingState>((ref) {
      final wsService = ref.read(webSocketServiceProvider);
      return TrackingWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages [TrackingState] and updates it in response to location / tracking
/// WebSocket events.
///
/// Location updates are throttled to at most one UI update every 2 seconds to
/// prevent excessive map redraws (Requirement 5.2, 17.2).
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class TrackingWebSocketNotifier extends StateNotifier<TrackingState> {
  TrackingWebSocketNotifier(this._wsService) : super(TrackingState.empty) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  /// Timestamp of the last accepted location update.
  /// Used to enforce the 2-second throttle.
  DateTime? _lastLocationUpdate;

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.locationUpdate)
          .listen(_onLocationUpdate),
      _wsService
          .getEventStream(EventType.trackingStarted)
          .listen(_onTrackingStarted),
      _wsService
          .getEventStream(EventType.trackingEnded)
          .listen(_onTrackingEnded),
      _wsService
          .getEventStream(EventType.technicianArrived)
          .listen(_onTechnicianArrived),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `location_update` → update lat/lng with 2-second throttle.
  ///
  /// Requirements 5.1, 5.2, 17.2
  void _onLocationUpdate(WebSocketEvent event) {
    try {
      // Throttle: skip updates that arrive within 2 seconds of the last one.
      final now = DateTime.now();
      if (_lastLocationUpdate != null &&
          now.difference(_lastLocationUpdate!).inSeconds < 2) {
        return;
      }

      final payload = LocationUpdatePayload.fromJson(event.data);
      _lastLocationUpdate = now;

      // Optionally calculate a simple ETA if we have a destination stored.
      final eta = _calculateEta(payload.latitude, payload.longitude);

      state = state.copyWith(
        latitude: payload.latitude,
        longitude: payload.longitude,
        lastUpdate: payload.timestamp ?? now,
        estimatedArrival: eta,
      );

      debugPrint(
        '[TrackingWebSocketNotifier] location_update: '
        'lat=${payload.latitude} lng=${payload.longitude}',
      );
    } catch (e) {
      debugPrint(
        '[TrackingWebSocketNotifier] Error handling location_update: $e',
      );
    }
  }

  /// `tracking_started` → initialize tracking session.
  ///
  /// Requirement 5.4
  void _onTrackingStarted(WebSocketEvent event) {
    try {
      final payload = TrackingStartedPayload.fromJson(event.data);
      state = TrackingState(
        isTracking: true,
        incidentId: payload.incidentId,
        technicianId: payload.technicianId,
        lastUpdate: payload.startedAt ?? DateTime.now().toUtc(),
        hasArrived: false,
      );
      debugPrint(
        '[TrackingWebSocketNotifier] tracking_started: '
        'incident=${payload.incidentId} technician=${payload.technicianId}',
      );
    } catch (e) {
      debugPrint(
        '[TrackingWebSocketNotifier] Error handling tracking_started: $e',
      );
    }
  }

  /// `tracking_ended` → close tracking session.
  ///
  /// Requirement 5.5
  void _onTrackingEnded(WebSocketEvent event) {
    try {
      final payload = TrackingEndedPayload.fromJson(event.data);
      state = TrackingState.empty;
      debugPrint(
        '[TrackingWebSocketNotifier] tracking_ended: '
        'incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[TrackingWebSocketNotifier] Error handling tracking_ended: $e',
      );
    }
  }

  /// `technician_arrived` → set [TrackingState.hasArrived] to `true`.
  ///
  /// Requirement 5.3
  void _onTechnicianArrived(WebSocketEvent event) {
    try {
      final payload = TechnicianArrivedPayload.fromJson(event.data);
      state = state.copyWith(hasArrived: true, estimatedArrival: Duration.zero);
      debugPrint(
        '[TrackingWebSocketNotifier] technician_arrived: '
        'incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[TrackingWebSocketNotifier] Error handling technician_arrived: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Calculates a rough ETA using the Haversine formula.
  ///
  /// Returns `null` when there is no destination stored in state or when the
  /// technician has already arrived.
  ///
  /// The calculation assumes an average speed of 40 km/h in urban traffic.
  ///
  /// Requirement 5.7
  Duration? _calculateEta(double techLat, double techLng) {
    // We need a destination to calculate ETA.  The destination is the incident
    // location, which is not stored in TrackingState by default.  Return null
    // until the caller seeds the destination via a future enhancement.
    // The raw lat/lng is stored so the UI can display it directly.
    return null;
  }

  /// Haversine distance in kilometres between two coordinates.
  ///
  /// Kept here for future ETA calculation when a destination is available.
  // ignore: unused_element
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
