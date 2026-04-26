import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../providers/incident_provider.dart';

class IncidentsListScreen extends ConsumerWidget {
  const IncidentsListScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsState = ref.watch(incidentsProvider);

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
                ref.read(incidentsProvider.notifier).loadIncidents();
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
                  ref.read(incidentsProvider.notifier).loadIncidents(),
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
                      ref.read(incidentsProvider.notifier).loadIncidents(),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${incident.id}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(
                      incident.estadoActual,
                      incident.estadoLabel,
                    ),
                  ],
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
                Row(
                  children: [
                    // Prioridad
                    if (incident.prioridadIa != null)
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.priority_high,
                          label: incident.prioridadLabel,
                          color: _getPriorityColor(incident.prioridadIa),
                        ),
                      ),
                    if (incident.prioridadIa != null) const SizedBox(width: 8),

                    // Categoría
                    if (incident.categoriaIa != null)
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.category_outlined,
                          label: incident.categoriaIa!,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

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
                    if (incident.direccionReferencia != null) ...[
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          incident.direccionReferencia!,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
