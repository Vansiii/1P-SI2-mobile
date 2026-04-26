// Widget to display cancellation request status for an incident.
//
// Shows:
// - Pending cancellation requests with reason
// - Approved cancellation status
// - Rejected cancellation status with reason
//
// Task 3.1-3.3: Display cancellation events in mobile UI

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cancellation_realtime_service.dart';

/// Widget to display cancellation request status for an incident
class CancellationRequestWidget extends ConsumerWidget {
  const CancellationRequestWidget({required this.incidentId, super.key});

  final int incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancellationState = ref.watch(cancellationRealtimeProvider);
    final request = cancellationState.getCancellationRequest(incidentId);

    if (request == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(request.status),
                  color: _getStatusColor(request.status),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusTitle(request.status),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(request.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRequestDetails(request),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestDetails(CancellationRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (request.status == 'pending') ...[
          const Text(
            'Razón de la solicitud:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(request.reason, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'Solicitado: ${_formatDateTime(request.requestedAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
        if (request.status == 'approved') ...[
          const Text(
            'La solicitud de cancelación ha sido aprobada.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Aprobado: ${_formatDateTime(request.resolvedAt ?? request.requestedAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
        if (request.status == 'rejected') ...[
          const Text(
            'Razón del rechazo:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(request.reason, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'Rechazado: ${_formatDateTime(request.resolvedAt ?? request.requestedAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_outlined;
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'Solicitud de Cancelación Pendiente';
      case 'approved':
        return 'Cancelación Aprobada';
      case 'rejected':
        return 'Cancelación Rechazada';
      default:
        return 'Estado de Cancelación';
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}
