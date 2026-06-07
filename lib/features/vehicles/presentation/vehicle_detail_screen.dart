import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/data_cache.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../../shared/widgets/offline_aware_image.dart';
import '../providers/vehicle_provider.dart';
import '../data/models/vehicle_model.dart';

class VehicleDetailScreen extends ConsumerWidget {
  final int vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesState = ref.watch(vehiclesProvider);

    return vehiclesState.when(
      data: (vehicles) {
        VehicleModel? vehicle;
        try {
          vehicle = vehicles.firstWhere((v) => v.id == vehicleId);
        } catch (_) {
          final cached = DataCache.get(
            DataCache.currentUserId != null
                ? DataCache.scopedKey('vehicle_$vehicleId', DataCache.currentUserId!)
                : 'vehicle_$vehicleId',
          );
          if (cached is Map) {
            vehicle = VehicleModel.fromJson(Map<String, dynamic>.from(cached));
          }
        }
        if (vehicle == null) {
          return Scaffold(
            backgroundColor: AppColors.baseBg,
            appBar: AppBar(
              title: const Text('Vehículo no encontrado'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: Text('No se pudo cargar el vehículo')),
          );
        }

        return _buildDetailScreen(context, ref, vehicle);
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.baseBg,
        appBar: AppBar(
          title: const Text('Detalle del Vehículo'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppColors.baseBg,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Error al cargar el vehículo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailScreen(
    BuildContext context,
    WidgetRef ref,
    VehicleModel vehicle,
  ) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: CustomScrollView(
        slivers: [
          // AppBar con imagen
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: vehicle.imagen != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        OfflineAwareImage(
                          imageUrl: vehicle.imagen!,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.directions_car,
                              size: 100,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        // Gradiente para mejor legibilidad
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.directions_car,
                        size: 100,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  context.push('/vehicles/${vehicle.id}/edit');
                },
                tooltip: 'Editar',
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'history') {
                    context.push('/vehicles/${vehicle.id}/history');
                  } else if (value == 'delete') {
                    _showDeleteDialog(context, ref, vehicle);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        Icon(Icons.history, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Ver Historial'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Eliminar'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    vehicle.displayName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Información del vehículo
                  _buildInfoCard(context, 'Información General', [
                    _buildInfoRow(
                      context,
                      Icons.pin,
                      'Placa / Matrícula',
                      vehicle.matricula,
                    ),
                    if (vehicle.marca != null)
                      _buildInfoRow(
                        context,
                        Icons.branding_watermark,
                        'Marca',
                        vehicle.marca!,
                      ),
                    _buildInfoRow(
                      context,
                      Icons.directions_car,
                      'Modelo',
                      vehicle.modelo,
                    ),
                    _buildInfoRow(
                      context,
                      Icons.calendar_today,
                      'Año',
                      vehicle.anio.toString(),
                    ),
                    if (vehicle.color != null)
                      _buildInfoRow(
                        context,
                        Icons.palette,
                        'Color',
                        vehicle.color!,
                      ),
                  ]),

                  const SizedBox(height: 16),

                  // Información de registro
                  _buildInfoCard(context, 'Información de Registro', [
                    _buildInfoRow(
                      context,
                      Icons.access_time,
                      'Registrado',
                      _formatDate(vehicle.createdAt),
                    ),
                    if (vehicle.updatedAt != vehicle.createdAt)
                      _buildInfoRow(
                        context,
                        Icons.update,
                        'Última actualización',
                        _formatDate(vehicle.updatedAt),
                      ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    VehicleModel vehicle,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Vehículo'),
        content: Text(
          '¿Estás seguro de que deseas eliminar ${vehicle.displayName}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(vehiclesProvider.notifier)
                    .deleteVehicle(vehicle.id);
                if (context.mounted) {
                  SnackBarUtils.showSuccess(
                    context,
                    'Vehículo eliminado exitosamente',
                  );
                  context.go('/vehicles');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackBarUtils.showError(context, e.toString());
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
