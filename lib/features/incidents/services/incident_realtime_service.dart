// Incident real-time service for handling incident events.
//
// Responsibilities:
// - Subscribe to all incident.* events from EventDispatcherService
// - Show local notifications when events are received
// - Update incident list automatically via IncidentsNotifier
//
// Tasks: 1.1-1.13 - Complete incident event handling

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/models/realtime_event.dart';
import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_realtime_provider.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_provider.dart';
import 'package:merchanic_repair/features/incidents/data/models/incident_model.dart';
import 'package:merchanic_repair/services/notification_service.dart';

/// Provider for the incident realtime service
final incidentRealtimeServiceProvider = Provider<IncidentRealtimeService>((
  ref,
) {
  final eventDispatcher = ref.watch(eventDispatcherServiceProvider);
  final incidentsNotifier = ref.read(incidentsProvider.notifier);
  final notificationService = NotificationService();

  final service = IncidentRealtimeService(
    eventDispatcher: eventDispatcher,
    incidentsNotifier: incidentsNotifier,
    notificationService: notificationService,
  );

  // Initialize the service
  service.initialize();

  // Cleanup on dispose
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Service for handling real-time incident events.
///
/// Subscribes to all incident.* events and:
/// - Shows local notifications
/// - Updates the incident list automatically
/// - Manages UI state for analysis and other operations
class IncidentRealtimeService {
  IncidentRealtimeService({
    required EventDispatcherService eventDispatcher,
    required IncidentsNotifier incidentsNotifier,
    required NotificationService notificationService,
  }) : _eventDispatcher = eventDispatcher,
       _incidentsNotifier = incidentsNotifier,
       _notificationService = notificationService;

  final EventDispatcherService _eventDispatcher;
  final IncidentsNotifier _incidentsNotifier;
  final NotificationService _notificationService;

  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  /// Initialize the service and subscribe to all incident events
  void initialize() {
    if (_disposed) {
      debugPrint(
        '[IncidentRealtimeService] initialize() called after dispose — ignored.',
      );
      return;
    }

    // Subscribe to all incident events
    _subscriptions.addAll([
      _eventDispatcher
          .getStream<IncidentCreatedEvent>('incident.created')
          .listen(_onIncidentCreated),
      _eventDispatcher
          .getStream<IncidentAssignedEvent>('incident.assigned')
          .listen(_onIncidentAssigned),
      _eventDispatcher
          .getStream<IncidentAssignmentAcceptedEvent>(
            'incident.assignment_accepted',
          )
          .listen(_onAssignmentAccepted),
      _eventDispatcher
          .getStream<IncidentAssignmentRejectedEvent>(
            'incident.assignment_rejected',
          )
          .listen(_onAssignmentRejected),
      _eventDispatcher
          .getStream<IncidentAssignmentTimeoutEvent>(
            'incident.assignment_timeout',
          )
          .listen(_onAssignmentTimeout),
      _eventDispatcher
          .getStream<IncidentStatusChangedEvent>('incident.status_changed')
          .listen(_onStatusChanged),
      _eventDispatcher
          .getStream<IncidentTechnicianOnWayEvent>('incident.technician_on_way')
          .listen(_onTechnicianOnWay),
      _eventDispatcher
          .getStream<IncidentTechnicianArrivedEvent>(
            'incident.technician_arrived',
          )
          .listen(_onTechnicianArrived),
      _eventDispatcher
          .getStream<IncidentWorkStartedEvent>('incident.work_started')
          .listen(_onWorkStarted),
      _eventDispatcher
          .getStream<IncidentWorkCompletedEvent>('incident.work_completed')
          .listen(_onWorkCompleted),
      _eventDispatcher
          .getStream<IncidentCancelledEvent>('incident.cancelled')
          .listen(_onIncidentCancelled),
      _eventDispatcher
          .getStream<IncidentPhotosUploadedEvent>('incident.photos_uploaded')
          .listen(_onPhotosUploaded),
      _eventDispatcher
          .getStream<IncidentAnalysisStartedEvent>('incident.analysis_started')
          .listen(_onAnalysisStarted),
      _eventDispatcher
          .getStream<IncidentAnalysisCompletedEvent>(
            'incident.analysis_completed',
          )
          .listen(_onAnalysisCompleted),
      _eventDispatcher
          .getStream<IncidentAnalysisFailedEvent>('incident.analysis_failed')
          .listen(_onAnalysisFailed),
    ]);

    debugPrint(
      '[IncidentRealtimeService] Initialized and subscribed to all incident events',
    );
  }

  // ── Event Handlers ─────────────────────────────────────────────────────────

  /// Handle incident.created event
  Future<void> _onIncidentCreated(IncidentCreatedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] incident.created received: '
      'id=${event.incidentId}, description=${event.description}',
    );

    try {
      // 1. Show local notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Nuevo Incidente #${event.incidentId}',
        body: event.description.isNotEmpty
            ? event.description
            : 'Se ha creado un nuevo incidente',
      );

      // 2. Update incident list
      final incident = IncidentModel(
        id: event.incidentId,
        clientId: event.clientId,
        vehiculoId: 0,
        tallerId: null,
        tecnicoId: null,
        latitude: event.latitude ?? 0.0,
        longitude: event.longitude ?? 0.0,
        direccionReferencia: event.address,
        descripcion: event.description,
        esAmbiguo: false,
        estadoActual: event.status.isNotEmpty ? event.status : 'pending',
        assignmentMode: 'auto',
        createdAt: DateTime.parse(event.createdAt),
        updatedAt: DateTime.parse(event.createdAt),
      );

      _incidentsNotifier.addIncidentFromWebSocket(incident);
    } catch (e, stackTrace) {
      debugPrint(
        '[IncidentRealtimeService] Error handling incident.created: $e\n$stackTrace',
      );
    }
  }

  /// Handle incident.assigned event
  Future<void> _onIncidentAssigned(IncidentAssignedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] incident.assigned received: '
      'id=${event.incidentId}, workshopId=${event.workshopId}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Incidente Asignado #${event.incidentId}',
        body: 'El incidente ha sido asignado a un taller',
      );

      // ✅ Update incident with workshop ID and status
      _incidentsNotifier.updateIncidentFromWebSocket(event.incidentId, {
        'estado_actual': 'asignado',
        'taller_id': event.workshopId,
        'assigned_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[IncidentRealtimeService] Error handling assigned: $e');
    }
  }

  /// Handle incident.assignment_accepted event
  Future<void> _onAssignmentAccepted(
    IncidentAssignmentAcceptedEvent event,
  ) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] assignment_accepted received: '
      'id=${event.incidentId}, workshopId=${event.workshopId}, technicianId=${event.technicianId}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Asignación Aceptada #${event.incidentId}',
        body: 'El taller ha aceptado el incidente',
      );

      // ✅ Update incident with workshop, technician, and status
      final updates = <String, dynamic>{
        'estado_actual': event.technicianId != null ? 'en_proceso' : 'asignado',
      };

      updates['taller_id'] = event.workshopId;

      updates['tecnico_id'] = event.technicianId;

      _incidentsNotifier.updateIncidentFromWebSocket(event.incidentId, updates);
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling assignment_accepted: $e',
      );
    }
  }

  /// Handle incident.assignment_rejected event
  Future<void> _onAssignmentRejected(
    IncidentAssignmentRejectedEvent event,
  ) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] assignment_rejected received: '
      'id=${event.incidentId}, reason=${event.reason}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Asignación Rechazada #${event.incidentId}',
        body: event.reason ?? 'El taller ha rechazado el incidente',
      );

      // ✅ Update incident - clear workshop/technician and set to pending
      _incidentsNotifier.updateIncidentFromWebSocket(event.incidentId, {
        'estado_actual': 'pendiente',
        'taller_id': null,
        'tecnico_id': null,
      });
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling assignment_rejected: $e',
      );
    }
  }

  /// Handle incident.assignment_timeout event (Task 1.6)
  Future<void> _onAssignmentTimeout(
    IncidentAssignmentTimeoutEvent event,
  ) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] assignment_timeout received: '
      'id=${event.incidentId}, workshop=${event.workshopName}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Timeout de Asignación #${event.incidentId}',
        body:
            'El taller ${event.workshopName} no respondió en ${event.timeoutMinutes} minutos',
      );

      // Update incident status
      _incidentsNotifier.updateIncidentStatusFromWebSocket(
        event.incidentId,
        'timeout',
      );
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling assignment_timeout: $e',
      );
    }
  }

  /// Handle incident.status_changed event
  ///
  /// Generic handler for any status change
  Future<void> _onStatusChanged(IncidentStatusChangedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] status_changed received: '
      'id=${event.incidentId}, ${event.oldStatus} -> ${event.newStatus}',
    );

    try {
      // Map status to Spanish labels
      final statusLabels = {
        'pending': 'Pendiente',
        'assigned': 'Asignado',
        'accepted': 'Aceptado',
        'rejected': 'Rechazado',
        'on_way': 'En camino',
        'arrived': 'Técnico llegó',
        'in_progress': 'En progreso',
        'completed': 'Completado',
        'cancelled': 'Cancelado',
        'sin_taller_disponible': 'Sin taller disponible',
      };

      final oldLabel = statusLabels[event.oldStatus] ?? event.oldStatus;
      final newLabel = statusLabels[event.newStatus] ?? event.newStatus;

      // Show notification for important status changes
      if ([
        'completed',
        'cancelled',
        'rejected',
        'sin_taller_disponible',
      ].contains(event.newStatus)) {
        await _notificationService.showIncidentNotification(
          incidentId: event.incidentId,
          title: 'Estado Actualizado #${event.incidentId}',
          body: '$oldLabel → $newLabel',
        );
      }

      // Update incident status
      _incidentsNotifier.updateIncidentStatusFromWebSocket(
        event.incidentId,
        event.newStatus,
      );
    } catch (e) {
      debugPrint('[IncidentRealtimeService] Error handling status_changed: $e');
    }
  }

  /// Handle incident.cancelled event
  ///
  /// Specific handler for incident cancellation
  Future<void> _onIncidentCancelled(IncidentCancelledEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] incident.cancelled received: '
      'id=${event.incidentId}, reason=${event.reason}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Incidente Cancelado #${event.incidentId}',
        body: (event.reason?.isNotEmpty ?? false)
            ? 'Razón: ${event.reason}'
            : 'El incidente ha sido cancelado',
      );

      // ✅ Update incident - clear assignments and set to cancelled
      _incidentsNotifier.updateIncidentFromWebSocket(event.incidentId, {
        'estado_actual': 'cancelado',
        'taller_id': null,
        'tecnico_id': null,
      });
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling incident.cancelled: $e',
      );
    }
  }

  /// Handle incident.technician_on_way event
  Future<void> _onTechnicianOnWay(IncidentTechnicianOnWayEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] technician_on_way received: '
      'id=${event.incidentId}, technicianId=${event.technicianId}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Técnico en Camino #${event.incidentId}',
        body: event.estimatedArrivalMinutes != null
            ? 'Llegará en aproximadamente ${event.estimatedArrivalMinutes} minutos'
            : 'El técnico está en camino',
      );

      // ✅ Update incident with technician and status
      final updates = <String, dynamic>{'estado_actual': 'en_camino'};

      updates['tecnico_id'] = event.technicianId;

      _incidentsNotifier.updateIncidentFromWebSocket(event.incidentId, updates);
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling technician_on_way: $e',
      );
    }
  }

  /// Handle incident.technician_arrived event
  Future<void> _onTechnicianArrived(
    IncidentTechnicianArrivedEvent event,
  ) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] technician_arrived received: '
      'id=${event.incidentId}, technicianId=${event.technicianId}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Técnico Llegó #${event.incidentId}',
        body: 'El técnico ha llegado a la ubicación',
      );

      // ✅ Update incident with technician and status
      final updates = <String, dynamic>{'estado_actual': 'tecnico_llego'};

      updates['tecnico_id'] = event.technicianId;

      _incidentsNotifier.updateIncidentFromWebSocket(event.incidentId, updates);
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling technician_arrived: $e',
      );
    }
  }

  /// Handle incident.work_started event
  Future<void> _onWorkStarted(IncidentWorkStartedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] work_started received: '
      'id=${event.incidentId}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Trabajo Iniciado #${event.incidentId}',
        body: 'El técnico ha comenzado a trabajar en el incidente',
      );

      // Update incident status
      _incidentsNotifier.updateIncidentStatusFromWebSocket(
        event.incidentId,
        'in_progress',
      );
    } catch (e) {
      debugPrint('[IncidentRealtimeService] Error handling work_started: $e');
    }
  }

  /// Handle incident.work_completed event
  Future<void> _onWorkCompleted(IncidentWorkCompletedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] work_completed received: '
      'id=${event.incidentId}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Trabajo Completado #${event.incidentId}',
        body: 'El trabajo en el incidente ha sido completado',
      );

      // ✅ Update incident with completion timestamp
      _incidentsNotifier.updateIncidentFromWebSocket(event.incidentId, {
        'estado_actual': 'completado',
        'resolved_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[IncidentRealtimeService] Error handling work_completed: $e');
    }
  }

  /// Handle incident.photos_uploaded event (Task 1.2)
  Future<void> _onPhotosUploaded(IncidentPhotosUploadedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] photos_uploaded received: '
      'id=${event.incidentId}, count=${event.photoUrls.length}',
    );

    try {
      // Show notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Fotos Subidas #${event.incidentId}',
        body: '${event.photoUrls.length} foto(s) subida(s) al incidente',
      );

      // Note: Photo URLs would need to be stored in incident model
      // For now, just log the event
      debugPrint(
        '[IncidentRealtimeService] Photos uploaded: ${event.photoUrls}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling photos_uploaded: $e',
      );
    }
  }

  /// Handle incident.analysis_started event (Task 1.3)
  Future<void> _onAnalysisStarted(IncidentAnalysisStartedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] analysis_started received: '
      'id=${event.incidentId}, analysisId=${event.analysisId}',
    );

    try {
      // Show notification with "Analyzing..." indicator
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Analizando Incidente #${event.incidentId}',
        body: 'El análisis de IA está en progreso...',
      );

      // Update incident with analyzing flag
      // Note: This would require extending the incident model to include
      // an 'analyzing' flag. For now, we just log it.
      debugPrint(
        '[IncidentRealtimeService] Incident ${event.incidentId} is being analyzed',
      );
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling analysis_started: $e',
      );
    }
  }

  /// Handle incident.analysis_completed event (Task 1.4)
  Future<void> _onAnalysisCompleted(
    IncidentAnalysisCompletedEvent event,
  ) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] analysis_completed received: '
      'id=${event.incidentId}, diagnosis=${event.diagnosis}',
    );

    try {
      // Show notification with analysis result
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Análisis Completado #${event.incidentId}',
        body: 'Diagnóstico: ${event.diagnosis}',
      );

      // Update incident with analysis results
      _incidentsNotifier.updateIncidentFromWebSocket(event.incidentId, {
        'categoria_ia': event.diagnosis,
        'prioridad_ia': event.severity,
        'resumen_ia': event.recommendations != null
            ? (event.recommendations as List<String>).join('\n')
            : null,
      });
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling analysis_completed: $e',
      );
    }
  }

  /// Handle incident.analysis_failed event (Task 1.5)
  Future<void> _onAnalysisFailed(IncidentAnalysisFailedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[IncidentRealtimeService] analysis_failed received: '
      'id=${event.incidentId}, error=${event.error}',
    );

    try {
      // Show notification with error
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Error en Análisis #${event.incidentId}',
        body: 'No se pudo completar el análisis: ${event.error}',
      );

      // Log the error
      debugPrint(
        '[IncidentRealtimeService] Analysis failed for incident ${event.incidentId}: ${event.error}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentRealtimeService] Error handling analysis_failed: $e',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    debugPrint('[IncidentRealtimeService] Disposed');
  }
}
