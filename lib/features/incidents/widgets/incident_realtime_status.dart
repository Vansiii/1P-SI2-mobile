// Real-time incident status widget.
//
// Displays a status badge that updates automatically when incident events
// arrive via [IncidentRealtimeNotifier].
//
// Requirements: 4.1, 4.2, 4.3, 4.9, 4.10

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_realtime_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status metadata helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the display label for a status string.
String _statusLabel(String status) {
  switch (status) {
    case 'pending':
    case 'pendiente':
      return 'Pendiente';
    case 'assigned':
    case 'asignado':
      return 'Asignado';
    case 'assignment_accepted':
      return 'Aceptado';
    case 'assignment_rejected':
      return 'Rechazado';
    case 'on_way':
    case 'en_camino':
      return 'En camino';
    case 'arrived':
    case 'en_sitio':
      return 'Técnico llegó';
    case 'completed':
    case 'resuelto':
      return 'Completado';
    case 'cancelled':
    case 'cancelado':
      return 'Cancelado';
    default:
      return status;
  }
}

/// Returns the accent color for a status string.
Color _statusColor(String status) {
  switch (status) {
    case 'pending':
    case 'pendiente':
      return AppColors.warning;
    case 'assigned':
    case 'asignado':
    case 'assignment_accepted':
      return AppColors.info;
    case 'assignment_rejected':
      return AppColors.error;
    case 'on_way':
    case 'en_camino':
      return AppColors.primary;
    case 'arrived':
    case 'en_sitio':
      return AppColors.primary;
    case 'completed':
    case 'resuelto':
      return AppColors.success;
    case 'cancelled':
    case 'cancelado':
      return AppColors.error;
    default:
      return AppColors.textMuted;
  }
}

/// Returns the icon for a status string.
IconData _statusIcon(String status) {
  switch (status) {
    case 'pending':
    case 'pendiente':
      return Icons.hourglass_empty;
    case 'assigned':
    case 'asignado':
    case 'assignment_accepted':
      return Icons.assignment_turned_in_outlined;
    case 'assignment_rejected':
      return Icons.assignment_late_outlined;
    case 'on_way':
    case 'en_camino':
      return Icons.directions_car_outlined;
    case 'arrived':
    case 'en_sitio':
      return Icons.location_on_outlined;
    case 'completed':
    case 'resuelto':
      return Icons.check_circle_outline;
    case 'cancelled':
    case 'cancelado':
      return Icons.cancel_outlined;
    default:
      return Icons.info_outline;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a real-time status badge for [incidentId].
///
/// When a real-time event updates the incident's status the badge animates to
/// the new value without requiring a full widget rebuild from the parent.
///
/// If no real-time state is available yet, [fallbackStatus] is shown instead.
///
/// ```dart
/// IncidentRealtimeWidget(
///   incidentId: incident.id,
///   fallbackStatus: incident.estadoActual,
/// )
/// ```
class IncidentRealtimeWidget extends ConsumerWidget {
  const IncidentRealtimeWidget({
    super.key,
    required this.incidentId,
    this.fallbackStatus = 'pending',
    this.showEta = true,
    this.compact = false,
  });

  final int incidentId;

  /// Status to display when no real-time event has been received yet.
  final String fallbackStatus;

  /// Whether to show the ETA chip when the technician is on the way.
  final bool showEta;

  /// When `true`, renders a smaller inline badge without the ETA row.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeState = ref.watch(incidentRealtimeStateProvider(incidentId));
    final status = realtimeState?.status ?? fallbackStatus;

    if (compact) {
      return _CompactBadge(status: status);
    }

    return _FullBadge(
      status: status,
      realtimeState: realtimeState,
      showEta: showEta,
    );
  }
}

// ── Compact badge ─────────────────────────────────────────────────────────────

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full badge ────────────────────────────────────────────────────────────────

class _FullBadge extends StatelessWidget {
  const _FullBadge({
    required this.status,
    required this.realtimeState,
    required this.showEta,
  });

  final String status;
  final IncidentRealtimeState? realtimeState;
  final bool showEta;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final eta = realtimeState?.estimatedArrivalMinutes;
    final showEtaChip =
        showEta && eta != null && (status == 'on_way' || status == 'en_camino');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_statusIcon(status), size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                _statusLabel(status),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (showEtaChip) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  'ETA: $eta min',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
