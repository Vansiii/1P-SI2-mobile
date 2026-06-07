import 'package:flutter/foundation.dart';
import '../app_database.dart';

class ConflictResolution {
  final String action;
  final String label;
  final String? description;

  const ConflictResolution({
    required this.action,
    required this.label,
    this.description,
  });
}

class ConflictResolverService {
  final AppDatabase _db;

  ConflictResolverService({AppDatabase? db}) : _db = db ?? AppDatabase();

  OfflineQueueDao get dao => _db.offlineQueueDao;

  Future<List<OfflineOperation>> getUnresolvedConflicts({int? userId}) {
    return dao.getConflicts(userId: userId);
  }

  Future<List<ConflictResolution>> getResolutionsFor(String conflictCode) async {
    switch (conflictCode) {
      case 'WORKSHOP_NOT_AVAILABLE':
        return const [
          ConflictResolution(
            action: 'retry_new_data',
            label: 'Seleccionar otro taller',
            description:
                'El taller que elegiste ya no está disponible. Puedes elegir otro.',
          ),
          ConflictResolution(
            action: 'auto_assign',
            label: 'Asignación automática',
            description: 'Deja que el sistema asigne el mejor taller disponible.',
          ),
          ConflictResolution(
            action: 'cancel',
            label: 'Cancelar operación',
          ),
        ];
      case 'INCIDENT_ALREADY_RESOLVED':
      case 'INCIDENT_CANCELLED':
        return const [
          ConflictResolution(
            action: 'acknowledge',
            label: 'Aceptar estado del servidor',
            description: 'El incidente ya fue atendido o cancelado.',
          ),
        ];
      case 'TECHNICIAN_NOT_AVAILABLE':
        return const [
          ConflictResolution(
            action: 'retry',
            label: 'Reintentar más tarde',
            description: 'El técnico está ocupado. Intenta de nuevo.',
          ),
          ConflictResolution(
            action: 'cancel',
            label: 'Cancelar operación',
          ),
        ];
      case 'INVALID_STATE_TRANSITION':
        return const [
          ConflictResolution(
            action: 'acknowledge',
            label: 'Aceptar estado actual',
          ),
        ];
      case 'RESOURCE_VERSION_CHANGED':
        return const [
          ConflictResolution(
            action: 'refresh_and_retry',
            label: 'Actualizar y reintentar',
          ),
          ConflictResolution(action: 'cancel', label: 'Cancelar'),
        ];
      case 'TENANT_SUSPENDED':
      case 'SUBSCRIPTION_INACTIVE':
        return const [
          ConflictResolution(action: 'acknowledge', label: 'Entendido'),
        ];
      case 'UNAUTHORIZED':
        return const [
          ConflictResolution(
            action: 'reauthenticate',
            label: 'Iniciar sesión',
          ),
        ];
      case 'TOKEN_EXPIRED':
        return const [
          ConflictResolution(action: 'retry', label: 'Reintentar'),
        ];
      default:
        return const [
          ConflictResolution(action: 'retry', label: 'Reintentar'),
          ConflictResolution(action: 'cancel', label: 'Cancelar'),
        ];
    }
  }

  Future<void> resolveConflict(int operationId, String action) async {
    final op = await dao.getById(operationId);
    if (op == null) return;

    switch (action) {
      case 'retry':
      case 'retry_new_data':
      case 'auto_assign':
      case 'refresh_and_retry':
        await dao.updateSyncStatus(operationId, 'retry_pending');
        break;
      case 'cancel':
        await dao.cancelOperation(operationId);
        break;
      case 'acknowledge':
        await dao.updateSyncStatus(operationId, 'synced');
        break;
      case 'reauthenticate':
        await dao.cancelOperation(operationId);
        break;
      default:
        await dao.updateSyncStatus(operationId, 'retry_pending');
        break;
    }
    debugPrint('[ConflictResolver] Resolved op $operationId → $action');
  }

  String humanReadableCode(String code) {
    switch (code) {
      case 'WORKSHOP_NOT_AVAILABLE':
        return 'Taller no disponible';
      case 'INCIDENT_ALREADY_RESOLVED':
        return 'Incidente ya resuelto';
      case 'INCIDENT_CANCELLED':
        return 'Incidente cancelado';
      case 'TECHNICIAN_NOT_AVAILABLE':
        return 'Técnico no disponible';
      case 'INVALID_STATE_TRANSITION':
        return 'Transición de estado inválida';
      case 'RESOURCE_VERSION_CHANGED':
        return 'Datos modificados';
      case 'TENANT_SUSPENDED':
        return 'Cuenta suspendida';
      case 'SUBSCRIPTION_INACTIVE':
        return 'Suscripción inactiva';
      case 'UNAUTHORIZED':
        return 'No autorizado';
      case 'TOKEN_EXPIRED':
        return 'Sesión expirada';
      default:
        return code;
    }
  }
}
