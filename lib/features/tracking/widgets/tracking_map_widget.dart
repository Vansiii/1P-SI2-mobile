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
import 'package:latlong2/latlong.dart' hide Path;
import 'package:permission_handler/permission_handler.dart';

import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/features/tracking/providers/tracking_realtime_provider.dart';
import 'package:merchanic_repair/widgets/map/cached_osm_tile_layer.dart';
import 'package:merchanic_repair/widgets/map/map_compass_button.dart';
import 'package:merchanic_repair/widgets/map/smart_map_marker.dart';

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

    // Default center: Cochabamba — fallback when no location yet.
    final center = (trackingState?.hasLocation ?? false)
        ? LatLng(trackingState!.latitude!, trackingState.longitude!)
        : const LatLng(-17.3935, -66.1570);

    final markers = <Marker>[];

    if (trackingState?.hasLocation ?? false) {
      markers.add(
        Marker(
          point: LatLng(trackingState!.latitude!, trackingState.longitude!),
          width: SmartMapMarker.markerWidth,
          height: SmartMapMarker.markerHeight,
          alignment: Alignment.topCenter,
          child: _TechnicianMarker(
            heading: trackingState.heading,
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initialZoom,
            minZoom: 5.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // OpenStreetMap tile layer.
            const CachedOsmTileLayer(),

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
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderColor: AppColors.primary.withValues(alpha: 0.35),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

            // Technician marker.
            MarkerLayer(markers: markers),
          ],
        ),

        // Compass button (shown when rotated)
        Positioned(
          top: 12,
          right: 12,
          child: MapCompassButton(
            mapController: _mapController,
            top: 0,
            right: 0,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Technician marker
// ─────────────────────────────────────────────────────────────────────────────

class _TechnicianMarker extends StatelessWidget {
  const _TechnicianMarker({this.heading});

  final double? heading;

  @override
  Widget build(BuildContext context) {
    return SmartMapMarker(
      primaryColor: AppColors.primary,
      icon: Icons.navigation_rounded,
      heading: heading,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Session status pulse indicator.
          _PulsingDot(color: sessionColor),
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
            _InfoPill(
              icon: Icons.access_time_rounded,
              text: '${state.etaMinutes} min',
            ),
            const SizedBox(width: 8),
          ],

          // Distance chip.
          if (state.distanceMeters != null)
            _InfoPill(
              icon: Icons.straighten_rounded,
              text: _formatDistance(state.distanceMeters!),
            ),

          // Coordinates fallback.
          if (state.etaMinutes == null &&
              state.distanceMeters == null &&
              state.hasLocation)
            Text(
              '${state.latitude!.toStringAsFixed(4)}, ${state.longitude!.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Small UI helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Animated pulsing dot for session status.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Compact info pill for ETA / distance.
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

