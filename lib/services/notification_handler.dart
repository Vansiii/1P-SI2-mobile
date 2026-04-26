import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Handler para gestionar diferentes tipos de notificaciones push.
/// Usa GoRouter para navegación, compatible con el router de la app.
class NotificationHandler {
  /// Manejar notificación recibida
  static void handleNotification(RemoteMessage message, BuildContext? context) {
    final data = message.data;
    final type = data['type'] as String?;

    debugPrint('📱 Handling notification type: $type');

    if (context == null) {
      debugPrint('⚠️ Context is null, cannot navigate');
      return;
    }

    switch (type) {
      case 'chat_message':
        _handleChatMessage(data, context);
        break;

      case 'cancellation_request':
        _handleCancellationRequest(data, context);
        break;

      case 'cancellation_response':
        _handleCancellationResponse(data, context);
        break;

      case 'incident_assigned':
      case 'incident_assignment':
        _handleIncidentAssigned(data, context);
        break;

      case 'incident_status_changed':
      case 'incident_accepted':
        _handleIncidentStatusChanged(data, context);
        break;

      case 'technician_assigned':
        _handleIncidentStatusChanged(data, context);
        break;

      case 'technician_arrived':
        _handleTechnicianArrived(data, context);
        break;

      case 'service_completed':
        _handleServiceCompleted(data, context);
        break;

      default:
        debugPrint('⚠️ Unknown notification type: $type');
        // Navegar a incidentes como fallback si hay incident_id
        final incidentId = int.tryParse(data['incident_id'] ?? '');
        if (incidentId != null) {
          context.push('/incidents/$incidentId');
        }
    }
  }

  /// Manejar notificación de mensaje de chat
  static void _handleChatMessage(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    if (incidentId == null) return;

    // Navegar al detalle del incidente (el chat está dentro del detalle)
    context.push('/incidents/$incidentId');
  }

  /// Manejar notificación de solicitud de cancelación
  static void _handleCancellationRequest(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    if (incidentId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Solicitud de Cancelación'),
          ],
        ),
        content: const Text(
          'Has recibido una solicitud de cancelación. '
          'Abre el incidente para ver los detalles y responder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Después'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/incidents/$incidentId');
            },
            child: const Text('Ver Incidente'),
          ),
        ],
      ),
    );
  }

  /// Manejar notificación de respuesta a cancelación
  static void _handleCancellationResponse(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    final accept = data['accept'] == 'true';

    if (incidentId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              accept ? Icons.check_circle : Icons.cancel,
              color: accept ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(accept ? 'Cancelación Aceptada' : 'Cancelación Rechazada'),
          ],
        ),
        content: Text(
          accept
              ? 'La cancelación fue aceptada. El sistema buscará un nuevo taller automáticamente.'
              : 'La cancelación fue rechazada. El servicio continúa normalmente.',
        ),
        actions: [
          if (accept)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/incidents');
              },
              child: const Text('Ver Incidentes'),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/incidents/$incidentId');
              },
              child: const Text('Ver Incidente'),
            ),
        ],
      ),
    );
  }

  /// Manejar notificación de incidente asignado
  static void _handleIncidentAssigned(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    if (incidentId == null) return;

    context.push('/incidents/$incidentId');
  }

  /// Manejar notificación de cambio de estado
  static void _handleIncidentStatusChanged(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    if (incidentId == null) return;

    context.push('/incidents/$incidentId');
  }

  /// Manejar notificación de técnico llegó
  static void _handleTechnicianArrived(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    if (incidentId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text('Técnico Llegó'),
          ],
        ),
        content: const Text('El técnico ha llegado a tu ubicación.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/incidents/$incidentId');
            },
            child: const Text('Ver Incidente'),
          ),
        ],
      ),
    );
  }

  /// Manejar notificación de servicio completado
  static void _handleServiceCompleted(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    if (incidentId == null) return;

    context.push('/incidents/$incidentId');
  }

  /// Obtener icono según tipo de notificación
  static IconData getIconForType(String? type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat;
      case 'cancellation_request':
        return Icons.warning;
      case 'cancellation_response':
        return Icons.check_circle;
      case 'incident_assigned':
      case 'incident_assignment':
        return Icons.assignment;
      case 'incident_status_changed':
      case 'incident_accepted':
        return Icons.update;
      case 'technician_assigned':
        return Icons.person_pin;
      case 'technician_arrived':
        return Icons.location_on;
      case 'service_completed':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications;
    }
  }

  /// Obtener color según tipo de notificación
  static Color getColorForType(String? type) {
    switch (type) {
      case 'chat_message':
        return Colors.blue;
      case 'cancellation_request':
        return Colors.orange;
      case 'cancellation_response':
        return Colors.green;
      case 'incident_assigned':
      case 'incident_assignment':
        return Colors.purple;
      case 'incident_status_changed':
      case 'incident_accepted':
        return Colors.teal;
      case 'technician_assigned':
        return Colors.indigo;
      case 'technician_arrived':
        return Colors.blue;
      case 'service_completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
