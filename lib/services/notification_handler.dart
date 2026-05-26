import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Handler para gestionar diferentes tipos de notificaciones push.
/// Usa GoRouter para navegación, compatible con el router de la app.
class NotificationHandler {
  /// Manejar notificación recibida
  static void handleNotification(RemoteMessage message, GoRouter router) {
    final data = message.data;
    final type = data['type'] as String? ?? data['event_type'] as String?;

    debugPrint('📱 Handling notification type: $type');

    switch (type) {
      case 'chat_message':
      case 'chat.message_sent':
        _handleChatMessage(data, router);
        break;

      case 'cancellation_request':
        _handleCancellationRequest(data, router);
        break;

      case 'cancellation_response':
        _handleCancellationResponse(data, router);
        break;

      case 'incident_assigned':
      case 'incident_assignment':
      case 'incident.assigned':
        _handleIncidentAssigned(data, router);
        break;

      case 'incident_status_changed':
      case 'incident_accepted':
      case 'incident.status_changed':
        _handleIncidentStatusChanged(data, router);
        break;

      case 'technician_assigned':
      case 'incident.technician_assigned':
        _handleIncidentStatusChanged(data, router);
        break;

      case 'technician_arrived':
      case 'incident.technician_arrived':
        _handleTechnicianArrived(data, router);
        break;

      case 'service_completed':
      case 'incident.work_completed':
        _handleServiceCompleted(data, router);
        break;

      case 'incident.analysis_completed':
      case 'incident.analysis_started':
      case 'incident.analysis_failed':
      case 'incident.updated':
        _handleIncidentStatusChanged(data, router);
        break;

      default:
        debugPrint('⚠️ Unknown notification type: $type');
    }
  }

  /// Obtener un BuildContext del router para mostrar diálogos
  static BuildContext? _dialogContext(GoRouter router) {
    return router.routerDelegate.navigatorKey.currentContext;
  }

  /// Manejar notificación de mensaje de chat — solo log, sin navegación automática
  static void _handleChatMessage(
    Map<String, dynamic> data,
    GoRouter router,
  ) {
    debugPrint('📱 Chat message notification received (no auto-navigation)');
  }

  /// Manejar notificación de solicitud de cancelación
  static void _handleCancellationRequest(
    Map<String, dynamic> data,
    GoRouter router,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    if (incidentId == null) return;

    final ctx = _dialogContext(router);
    if (ctx == null) return;

    showDialog(
      context: ctx,
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
              router.push('/incidents/$incidentId');
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
    GoRouter router,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    final accept = data['accept'] == 'true';

    if (incidentId == null) return;

    final ctx = _dialogContext(router);
    if (ctx == null) return;

    showDialog(
      context: ctx,
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
                router.go('/incidents');
              },
              child: const Text('Ver Incidentes'),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                router.push('/incidents/$incidentId');
              },
              child: const Text('Ver Incidente'),
            ),
        ],
      ),
    );
  }

  /// Manejar notificación de incidente asignado — solo log, sin navegación automática
  static void _handleIncidentAssigned(
    Map<String, dynamic> data,
    GoRouter router,
  ) {
    debugPrint('📱 Incident assigned notification received (no auto-navigation)');
  }

  /// Manejar notificación de cambio de estado — solo log, sin navegación automática
  static void _handleIncidentStatusChanged(
    Map<String, dynamic> data,
    GoRouter router,
  ) {
    debugPrint('📱 Incident status changed notification received (no auto-navigation)');
  }

  /// Manejar notificación de técnico llegó
  static void _handleTechnicianArrived(
    Map<String, dynamic> data,
    GoRouter router,
  ) {
    final incidentId = int.tryParse(data['incident_id'] ?? '');
    if (incidentId == null) return;

    final ctx = _dialogContext(router);
    if (ctx == null) return;

    showDialog(
      context: ctx,
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
              router.push('/incidents/$incidentId');
            },
            child: const Text('Ver Incidente'),
          ),
        ],
      ),
    );
  }

  /// Manejar notificación de servicio completado — solo log, sin navegación automática
  static void _handleServiceCompleted(
    Map<String, dynamic> data,
    GoRouter router,
  ) {
    debugPrint('📱 Service completed notification received (no auto-navigation)');
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
