// Real-time tracking provider using EventDispatcherService.
//
// Subscribes to typed tracking events from [EventDispatcherService] and
// maintains technician location per incident.
//
// Location updates are throttled to at most one UI update every 2 seconds
// for battery efficiency (Requirement 2.10, 6.8).
//
// Requirements: 6.1, 6.5, 6.8, 6.13, 2.10

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/models/realtime_event.dart';
import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_realtime_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State model
// ─────────────────────────────────────────────────────────────────────────────

/// Tracking session status.
enum TrackingSessionStatus { inactive, active, ended }

/// Immutable snapshot of real-time tracking data for a single incident.
class TrackingRealtimeState {
  const TrackingRealtimeState({
    required this.incidentId,
    this.technicianId,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.etaMinutes,
    this.distanceMeters,
    this.sessionStatus = TrackingSessionStatus.inactive,
    this.lastUpdatedAt,
  });

  final int incidentId;
  final int? technicianId;

  /// Current technician latitude, or `null` if not yet received.
  final double? latitude;

  /// Current technician longitude, or `null` if not yet received.
  final double? longitude;

  /// GPS accuracy in metres, if available.
  final double? accuracy;

  /// Heading in degrees (0–360), if available.
  final double? heading;

  /// Speed in m/s, if available.
  final double? speed;

  /// Estimated time of arrival in minutes, from route_updated events.
  final int? etaMinutes;

  /// Distance to destination in metres, from route_updated events.
  final double? distanceMeters;

  final TrackingSessionStatus sessionStatus;

  /// ISO-8601 timestamp of the last accepted location update.
  final String? lastUpdatedAt;

  bool get hasLocation => latitude != null && longitude != null;

  TrackingRealtimeState copyWith({
    int? technicianId,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? heading,
    double? speed,
    int? etaMinutes,
    double? distanceMeters,
    TrackingSessionStatus? sessionStatus,
    String? lastUpdatedAt,
  }) {
    return TrackingRealtimeState(
      incidentId: incidentId,
      technicianId: technicianId ?? this.technicianId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  String toString() =>
      'TrackingRealtimeState(incident: $incidentId, '
      'lat: $latitude, lng: $longitude, eta: ${etaMinutes}min)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Maintains a map of [TrackingRealtimeState] keyed by incident ID.
///
/// Subscribes to all tracking-domain event types from [EventDispatcherService]
/// and updates state accordingly.  Location updates are throttled to at most
/// one accepted update per 2 seconds per incident (battery efficiency).
class TrackingRealtimeNotifier
    extends StateNotifier<Map<int, TrackingRealtimeState>> {
  TrackingRealtimeNotifier(this._dispatcher) : super({}) {
    _subscribe();
  }

  final EventDispatcherService _dispatcher;
  final List<StreamSubscription<RealTimeEvent>> _subscriptions = [];

  /// Per-incident timestamp of the last accepted location update.
  /// Used to enforce the 2-second throttle (Requirement 2.10, 6.8).
  final Map<int, DateTime> _lastLocationUpdate = {};

  /// Minimum interval between accepted location updates.
  static const _throttleDuration = Duration(seconds: 2);

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _dispatcher
          .getStream<TrackingLocationUpdatedEvent>('tracking.location_updated')
          .listen(_onLocationUpdated),
      _dispatcher
          .getStream<TrackingSessionStartedEvent>('tracking.session_started')
          .listen(_onSessionStarted),
      _dispatcher
          .getStream<TrackingSessionEndedEvent>('tracking.session_ended')
          .listen(_onSessionEnded),
      _dispatcher
          .getStream<TrackingRouteUpdatedEvent>('tracking.route_updated')
          .listen(_onRouteUpdated),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `tracking.location_updated` → update lat/lng with 2-second throttle.
  ///
  /// Requirements 6.1, 6.8, 2.10
  void _onLocationUpdated(TrackingLocationUpdatedEvent e) {
    final now = DateTime.now();
    final last = _lastLocationUpdate[e.incidentId];

    // Throttle: skip updates arriving within 2 seconds of the last accepted one.
    if (last != null && now.difference(last) < _throttleDuration) {
      debugPrint(
        '[TrackingRealtimeNotifier] throttled location_updated for '
        'incident=${e.incidentId}',
      );
      return;
    }

    _lastLocationUpdate[e.incidentId] = now;

    _patch(
      e.incidentId,
      technicianId: e.technicianId,
      latitude: e.latitude,
      longitude: e.longitude,
      accuracy: e.accuracy,
      heading: e.heading,
      speed: e.speed,
      lastUpdatedAt: e.updatedAt ?? now.toIso8601String(),
    );

    debugPrint(
      '[TrackingRealtimeNotifier] location_updated: '
      'incident=${e.incidentId} lat=${e.latitude} lng=${e.longitude}',
    );
  }

  /// `tracking.session_started` → mark session as active.
  ///
  /// Requirement 6.2
  void _onSessionStarted(TrackingSessionStartedEvent e) {
    _patch(
      e.incidentId,
      technicianId: e.technicianId,
      sessionStatus: TrackingSessionStatus.active,
      lastUpdatedAt: e.startedAt,
    );
    debugPrint(
      '[TrackingRealtimeNotifier] session_started: incident=${e.incidentId}',
    );
  }

  /// `tracking.session_ended` → mark session as ended.
  ///
  /// Requirement 6.3
  void _onSessionEnded(TrackingSessionEndedEvent e) {
    _patch(
      e.incidentId,
      sessionStatus: TrackingSessionStatus.ended,
      lastUpdatedAt: e.endedAt,
    );
    debugPrint(
      '[TrackingRealtimeNotifier] session_ended: incident=${e.incidentId}',
    );
  }

  /// `tracking.route_updated` → update ETA and distance.
  ///
  /// Requirement 6.4, 6.13
  void _onRouteUpdated(TrackingRouteUpdatedEvent e) {
    _patch(
      e.incidentId,
      technicianId: e.technicianId,
      etaMinutes: e.etaMinutes,
      distanceMeters: e.distanceMeters,
      lastUpdatedAt: e.updatedAt,
    );
    debugPrint(
      '[TrackingRealtimeNotifier] route_updated: '
      'incident=${e.incidentId} eta=${e.etaMinutes}min '
      'dist=${e.distanceMeters}m',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _patch(
    int incidentId, {
    int? technicianId,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? heading,
    double? speed,
    int? etaMinutes,
    double? distanceMeters,
    TrackingSessionStatus? sessionStatus,
    String? lastUpdatedAt,
  }) {
    final existing =
        state[incidentId] ?? TrackingRealtimeState(incidentId: incidentId);

    state = {
      ...state,
      incidentId: existing.copyWith(
        technicianId: technicianId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        heading: heading,
        speed: speed,
        etaMinutes: etaMinutes,
        distanceMeters: distanceMeters,
        sessionStatus: sessionStatus,
        lastUpdatedAt: lastUpdatedAt,
      ),
    };
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _lastLocationUpdate.clear();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the full map of [TrackingRealtimeState] keyed by incident ID.
final trackingRealtimeProvider =
    StateNotifierProvider<
      TrackingRealtimeNotifier,
      Map<int, TrackingRealtimeState>
    >((ref) {
      final dispatcher = ref.watch(eventDispatcherServiceProvider);
      return TrackingRealtimeNotifier(dispatcher);
    });

/// Convenience provider: returns the [TrackingRealtimeState] for a single
/// incident, or `null` if no tracking event has been received for it yet.
final trackingRealtimeStateProvider =
    Provider.family<TrackingRealtimeState?, int>((ref, incidentId) {
      return ref.watch(trackingRealtimeProvider)[incidentId];
    });
