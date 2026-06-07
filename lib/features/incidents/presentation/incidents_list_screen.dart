import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../providers/incident_provider.dart';
import '../providers/incidents_websocket_provider.dart';
import '../data/models/incident_model.dart';
import '../services/incident_analysis_realtime_service.dart';

class IncidentsListScreen extends ConsumerStatefulWidget {
  const IncidentsListScreen({super.key});

  @override
  ConsumerState<IncidentsListScreen> createState() =>
      _IncidentsListScreenState();
}

class _IncidentsListScreenState extends ConsumerState<IncidentsListScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    // Asegura estado fresco al volver desde chat/tracking.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(incidentsProvider.notifier).loadIncidents();
    });

    // Actualizar la UI cada minuto para refrescar los tiempos relativos
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return AppColors.warning;
      case 'asignado':
        return AppColors.info;
      case 'en_proceso':
        return AppColors.primary;
      case 'resuelto':
        return AppColors.success;
      case 'cancelado':
        return AppColors.textMuted;
      case 'sin_taller_disponible':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  Color _getPriorityColor(String? prioridad) {
    switch (prioridad) {
      case 'alta':
        return AppColors.error;
      case 'media':
        return AppColors.warning;
      case 'baja':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }

  Widget _buildAssignmentBadge(String mode) {
    final isAuto = mode == 'auto';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAuto
            ? AppColors.info.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isAuto ? 'AUTO' : 'MANUAL',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isAuto ? AppColors.info : AppColors.warning,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidentsState = ref.watch(incidentsProvider);
    // ✅ Activar el provider WebSocket para que los eventos actualicen la UI
    ref.watch(incidentsWebSocketProvider);
    // ✅ Activar el provider de análisis IA en tiempo real
    ref.watch(incidentAnalysisRealtimeProvider);

    // Sincronizar snapshot base HTTP -> estado realtime para que los eventos
    // apliquen también sobre incidentes existentes (no solo los creados en vivo).
    ref.listen<AsyncValue<List<IncidentModel>>>(incidentsProvider, (
      _,
      next,
    ) {
      next.whenData((incidents) {
        ref
            .read(incidentsWebSocketProvider.notifier)
            .syncFromBaseIncidents(incidents);
      });
    });

    // Sincronizar cambios del WebSocket: recargar del HTTP cuando cambia cualquier dato
ref.listen<List<IncidentModel>>(incidentsWebSocketProvider, (
      previous,
      next,
    ) {
      if (previous == null) return;

      if (next.length > previous.length) {
        final previousIds = previous.map((incident) => incident.id).toSet();
        for (final incident in next.where(
          (item) => !previousIds.contains(item.id),
        )) {
          ref.read(incidentsProvider.notifier).addIncidentFromWebSocket(
            incident,
          );
        }
      } else if (next.length < previous.length) {
        final nextIds = next.map((incident) => incident.id).toSet();
        for (final incident in previous.where(
          (item) => !nextIds.contains(item.id),
        )) {
          ref
              .read(incidentsProvider.notifier)
              .removeIncidentFromWebSocket(incident.id);
        }
      }

      for (final nextIncident in next) {
        final prevIncident = previous
            .where((i) => i.id == nextIncident.id)
            .firstOrNull;
        if (prevIncident == null) {
          continue;
        }

        if (prevIncident.prioridadIa != nextIncident.prioridadIa ||
            prevIncident.categoriaIa != nextIncident.categoriaIa ||
            prevIncident.resumenIa != nextIncident.resumenIa ||
            prevIncident.estadoActual != nextIncident.estadoActual ||
            prevIncident.tallerId != nextIncident.tallerId ||
            prevIncident.tecnicoId != nextIncident.tecnicoId ||
            prevIncident.direccionReferencia != nextIncident.direccionReferencia ||
            prevIncident.latitude != nextIncident.latitude ||
            prevIncident.longitude != nextIncident.longitude) {
          ref
              .read(incidentsProvider.notifier)
              .updateIncidentFromWebSocket(nextIncident.id, {
                if (prevIncident.prioridadIa != nextIncident.prioridadIa)
                  'prioridad_ia': nextIncident.prioridadIa,
                if (prevIncident.categoriaIa != nextIncident.categoriaIa)
                  'categoria_ia': nextIncident.categoriaIa,
                if (prevIncident.resumenIa != nextIncident.resumenIa)
                  'resumen_ia': nextIncident.resumenIa,
                if (prevIncident.estadoActual != nextIncident.estadoActual)
                  'estado_actual': nextIncident.estadoActual,
                if (prevIncident.tallerId != nextIncident.tallerId)
                  'taller_id': nextIncident.tallerId,
                if (prevIncident.tecnicoId != nextIncident.tecnicoId)
                  'tecnico_id': nextIncident.tecnicoId,
                if (prevIncident.direccionReferencia != nextIncident.direccionReferencia)
                  'direccion_referencia': nextIncident.direccionReferencia,
                if (prevIncident.latitude != nextIncident.latitude)
                  'latitude': nextIncident.latitude,
                if (prevIncident.longitude != nextIncident.longitude)
                  'longitude': nextIncident.longitude,
              });
        }
      }
    });

    // ✅ Escuchar eventos de análisis IA completado
    ref.listen<
      Map<int, IncidentAnalysisState>
    >(incidentAnalysisRealtimeProvider, (previous, next) {
      if (previous == null) return;

      // Detectar incidentes cuyo análisis acaba de completarse
      for (final entry in next.entries) {
        final incidentId = entry.key;
        final analysisState = entry.value;
        final prevState = previous[incidentId];

        // Si el análisis cambió a completado, recargar ese incidente
        if (prevState?.status != AnalysisStatus.completed &&
            analysisState.status == AnalysisStatus.completed) {
          debugPrint(
            '[IncidentsListScreen] AI analysis completed for incident $incidentId, reloading...',
          );

          // Recargar el incidente específico para obtener los datos actualizados
          ref.read(incidentsProvider.notifier).getIncidentDetail(incidentId);
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Navegar al home
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.baseBg,
        appBar: AppBar(
          title: const Text(
            'Mis Emergencias',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textMain),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textMain),
              onPressed: () {
                ref.read(incidentsProvider.notifier).refreshIncidents();
              },
              tooltip: 'Recargar emergencias',
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: incidentsState.when(
          data: (incidents) {
            if (incidents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 80,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes emergencias reportadas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reporta una emergencia cuando la necesites',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(incidentsProvider.notifier).refreshIncidents(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: incidents.length,
                itemBuilder: (context, index) {
                  final incident = incidents[index];
                  return _buildIncidentCard(context, incident);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar emergencias',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(incidentsProvider.notifier).refreshIncidents(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            context.push('/incidents/report');
          },
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.warning),
          label: const Text('Reportar Emergencia'),
        ),
      ),
    );
  }

  Widget _buildIncidentCard(BuildContext context, incident) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(incident.estadoActual).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(
              incident.estadoActual,
            ).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/incidents/${incident.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con ID y badges
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textMuted.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  incident.id == 0 ? 'Local' : '#${incident.id}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildAssignmentBadge(incident.assignmentMode),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topRight,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (incident.id == 0) ...[
                                      _buildPendingSyncBadge(),
                                      const SizedBox(width: 8),
                                    ],
                                    _buildStatusBadge(
                                      incident.estadoActual,
                                      incident.estadoLabel,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Descripción
                Text(
                  incident.descripcion,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMain,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Información adicional en grid
                if (incident.prioridadIa != null || incident.categoriaIa != null) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final hasPriority = incident.prioridadIa != null;
                      final hasCategory = incident.categoriaIa != null;
                      final badgeCount =
                          (hasPriority ? 1 : 0) + (hasCategory ? 1 : 0);
                      final spacing = badgeCount > 1 ? 8.0 : 0.0;
                      final availableWidth = constraints.maxWidth;
                      final badgeWidth = badgeCount <= 1
                          ? availableWidth
                          : ((availableWidth - spacing) / badgeCount)
                              .clamp(140.0, availableWidth);

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (hasPriority)
                              SizedBox(
                                width: badgeWidth,
                                child: _buildInfoChip(
                                  icon: Icons.priority_high,
                                  label: incident.prioridadLabel,
                                  color: _getPriorityColor(incident.prioridadIa),
                                ),
                              ),
                            if (hasPriority && hasCategory)
                              const SizedBox(width: 8),
                            if (hasCategory)
                              SizedBox(
                                width: badgeWidth,
                                child: _buildInfoChip(
                                  icon: Icons.category_outlined,
                                  label: incident.categoriaIa!,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Footer con fecha y ubicación
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(incident.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (_getLocationLabel(incident) != null) ...[
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _getLocationLabel(incident)!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String estado, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(estado).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(estado).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(estado),
            size: 14,
            color: _getStatusColor(estado),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: _getStatusColor(estado),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSyncBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 12,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            'Pendiente de sync',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getLocationLabel(dynamic incident) {
    final address = (incident.direccionReferencia as String?)?.trim();
    if (address != null &&
        address.isNotEmpty &&
        !_isCoordinateLike(address)) {
      return address;
    }

    final hasCoordinates = incident.latitude != 0 || incident.longitude != 0;
    if (hasCoordinates) {
      return 'Ubicación pendiente';
    }

    return null;
  }

  bool _isCoordinateLike(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('coordenadas:') ||
        normalized.startsWith('ubicación:') ||
        normalized.startsWith('ubicacion:')) {
      return true;
    }

    return RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(normalized);
  }

  IconData _getStatusIcon(String estado) {
    switch (estado) {
      case 'pendiente':
        return Icons.pending_outlined;
      case 'asignado':
        return Icons.assignment_turned_in_outlined;
      case 'en_proceso':
        return Icons.build_outlined;
      case 'resuelto':
        return Icons.check_circle_outline;
      case 'cancelado':
        return Icons.cancel_outlined;
      case 'sin_taller_disponible':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Hace un momento';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
