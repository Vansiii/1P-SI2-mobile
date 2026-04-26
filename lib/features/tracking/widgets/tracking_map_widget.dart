// Tracking map widget with real-time location updates.
//
// Displays a flutter_map with the technician's current position marker,
// updates the marker when location events arrive, and shows ETA / distance
// information.  Location permission is handled gracefully.
//
// Requirements: 6.1, 6.5, 6.8, 6.13, 2.10

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/features/tracking/providers/tracking_realtime_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a real-time map for [incidentId].
///
/// - Shows the technician's location marker, updated via [TrackingRealtimeNotifier].
/// - Displays ETA and distance information when available.
/// - Handles location permission gracefully (shows prompt when denied).
/// - Throttling is enforced in the provider (max 1 update / 2 s).
///
/// ```dart
/// TrackingMapWidget(incidentId: incident.id)
/// ```
class TrackingMapWidget extends ConsumerStatefulWidget {
  const TrackingMapWidget({
    super.key,
    required this.incidentId,
    this.height = 300,
    this.initialZoom = 14.0,
  });

  final int incidentId;
  final double height;
  final double initialZoom;

  @override
  ConsumerState<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends ConsumerState<TrackingMapWidget> {
  final MapController _mapController = MapController();
  bool _locationPermissionGranted = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    if (mounted) {
      setState(() {
        _locationPermissionGranted = status.isGranted;
        _permissionChecked = true;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (mounted) {
      setState(() {
        _locationPermissionGranted = status.isGranted;
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(
      trackingRealtimeStateProvider(widget.incidentId),
    );

    // Move map camera when a new location arrives.
    ref.listen(trackingRealtimeStateProvider(widget.incidentId), (prev, next) {
      if (next != null && next.hasLocation) {
        final prevLat = prev?.latitude;
        final prevLng = prev?.longitude;
        if (prevLat != next.latitude || prevLng != next.longitude) {
          _mapController.move(
            LatLng(next.latitude!, next.longitude!),
            _mapController.camera.zoom,
          );
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Map ──────────────────────────────────────────────────────────────
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildMap(trackingState),
          ),
        ),

        // ── Info bar ─────────────────────────────────────────────────────────
        if (trackingState != null) ...[
          const SizedBox(height: 8),
          _TrackingInfoBar(state: trackingState),
        ],
      ],
    );
  }

  Widget _buildMap(TrackingRealtimeState? trackingState) {
    // Show permission prompt if not yet granted.
    if (_permissionChecked && !_locationPermissionGranted) {
      return _PermissionPrompt(onRequest: _requestLocationPermission);
    }

    // Default center: Bogotá, Colombia — fallback when no location yet.
    final center = (trackingState?.hasLocation ?? false)
        ? LatLng(trackingState!.latitude!, trackingState.longitude!)
        : const LatLng(4.7110, -74.0721);

    final markers = <Marker>[];

    if (trackingState?.hasLocation ?? false) {
      markers.add(
        Marker(
          point: LatLng(trackingState!.latitude!, trackingState.longitude!),
          width: 48,
          height: 48,
          child: _TechnicianMarker(
            heading: trackingState.heading,
            accuracy: trackingState.accuracy,
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: widget.initialZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // OpenStreetMap tile layer — no API key required.
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mecanicoYa.app',
        ),

        // Accuracy circle (GPS precision indicator).
        if ((trackingState?.hasLocation ?? false) &&
            trackingState!.accuracy != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(
                  trackingState.latitude!,
                  trackingState.longitude!,
                ),
                radius: trackingState.accuracy!,
                useRadiusInMeter: true,
                color: AppColors.primary.withValues(alpha: 0.12),
                borderColor: AppColors.primary.withValues(alpha: 0.4),
                borderStrokeWidth: 1,
              ),
            ],
          ),

        // Technician marker.
        MarkerLayer(markers: markers),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Technician marker
// ─────────────────────────────────────────────────────────────────────────────

class _TechnicianMarker extends StatelessWidget {
  const _TechnicianMarker({this.heading, this.accuracy});

  final double? heading;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      // Rotate icon to show heading direction when available.
      angle: heading != null ? (heading! * 3.14159265 / 180) : 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info bar
// ─────────────────────────────────────────────────────────────────────────────

class _TrackingInfoBar extends StatelessWidget {
  const _TrackingInfoBar({required this.state});

  final TrackingRealtimeState state;

  @override
  Widget build(BuildContext context) {
    final sessionColor = _sessionColor(state.sessionStatus);
    final sessionLabel = _sessionLabel(state.sessionStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          // Session status indicator.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: sessionColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            sessionLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sessionColor,
            ),
          ),

          const Spacer(),

          // ETA chip.
          if (state.etaMinutes != null) ...[
            const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              'ETA: ${state.etaMinutes} min',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Distance chip.
          if (state.distanceMeters != null) ...[
            const Icon(Icons.straighten, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              _formatDistance(state.distanceMeters!),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
          ],

          // Coordinates fallback when no ETA/distance yet.
          if (state.etaMinutes == null &&
              state.distanceMeters == null &&
              state.hasLocation) ...[
            Text(
              '${state.latitude!.toStringAsFixed(4)}, '
              '${state.longitude!.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Color _sessionColor(TrackingSessionStatus status) {
    switch (status) {
      case TrackingSessionStatus.active:
        return AppColors.success;
      case TrackingSessionStatus.ended:
        return AppColors.textMuted;
      case TrackingSessionStatus.inactive:
        return AppColors.warning;
    }
  }

  String _sessionLabel(TrackingSessionStatus status) {
    switch (status) {
      case TrackingSessionStatus.active:
        return 'Seguimiento activo';
      case TrackingSessionStatus.ended:
        return 'Seguimiento finalizado';
      case TrackingSessionStatus.inactive:
        return 'Sin seguimiento';
    }
  }

  String _formatDistance(double metres) {
    if (metres >= 1000) {
      return '${(metres / 1000).toStringAsFixed(1)} km';
    }
    return '${metres.toStringAsFixed(0)} m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission prompt
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gray100,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                'Permiso de ubicación requerido',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Para ver la ubicación del técnico necesitamos acceso a tu ubicación.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRequest,
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: const Text('Permitir ubicación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
