import 'package:flutter/material.dart';
import '../../data/models/cancellation_request.dart';

/// Widget que muestra una solicitud de cancelación pendiente
/// con opciones para aceptar o rechazar
class CancellationRequestCard extends StatelessWidget {
  final CancellationRequest cancellationRequest;
  final bool isOwnRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isLoading;

  const CancellationRequestCard({
    Key? key,
    required this.cancellationRequest,
    required this.isOwnRequest,
    this.onAccept,
    this.onReject,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isClient = cancellationRequest.requestedBy == 'client';
    final requesterName = isClient ? 'el cliente' : 'el taller';
    final receiverName = isClient ? 'el taller' : 'el cliente';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOwnRequest
              ? [const Color(0xFFDBEAFE), const Color(0xFFBFDBFE)]
              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isOwnRequest
              ? const Color(0xFF3B82F6)
              : const Color(0xFFF59E0B),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
                (isOwnRequest
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFF59E0B))
                    .withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOwnRequest
                      ? 'Solicitud de Cancelación Enviada'
                      : 'Solicitud de Cancelación Recibida',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isOwnRequest
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOwnRequest
                      ? 'Esperando respuesta de $receiverName'
                      : '$requesterName solicita cancelar el servicio',
                  style: TextStyle(
                    fontSize: 13,
                    color: isOwnRequest
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Motivo:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cancellationRequest.reason,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isOwnRequest && onAccept != null && onReject != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : onAccept,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.check, size: 16),
                          label: const Text('Aceptar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : onReject,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Rechazar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isOwnRequest) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeRemaining(
                          cancellationRequest.timeUntilExpiration,
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative || duration == Duration.zero) {
      return 'Expirada';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return 'Expira en ${hours}h ${minutes}m';
    } else {
      return 'Expira en ${minutes}m';
    }
  }
}
