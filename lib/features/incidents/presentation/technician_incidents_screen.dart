import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/data/models/incident.dart';
import 'package:merchanic_repair/services/api_service.dart';
import 'package:merchanic_repair/features/incidents/presentation/incident_tracking_map_screen.dart';

class TechnicianIncidentsScreen extends ConsumerStatefulWidget {
  const TechnicianIncidentsScreen({super.key});

  @override
  ConsumerState<TechnicianIncidentsScreen> createState() =>
      _TechnicianIncidentsScreenState();
}

class _TechnicianIncidentsScreenState
    extends ConsumerState<TechnicianIncidentsScreen> {
  List<Incident> _incidents = [];
  Incident? _activeIncident;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(
        '${ApiConfig.incidentes}?tecnico_id=me',
      );

      if (!mounted) return;

      // Debug: ver la respuesta completa
      debugPrint('📊 Response: $response');

      // Verificar si la respuesta tiene datos (respuesta exitosa)
      // El backend puede devolver { data: [...], message: "...", timestamp: "..." }
      // O { success: true, data: [...], message: "..." }
      final bool isSuccess =
          response.containsKey('data') ||
          (response.containsKey('success') && response['success'] == true);

      if (isSuccess && response.containsKey('data')) {
        final List<dynamic> data = response['data'] ?? [];

        debugPrint('✅ Found ${data.length} incidents');

        if (data.isEmpty) {
          setState(() {
            _incidents = [];
            _activeIncident = null;
            _isLoading = false;
          });
          return;
        }

        _incidents = data.map((json) => Incident.fromJson(json)).toList();

        // Ordenar: activos primero, luego por fecha
        _incidents.sort((a, b) {
          final aActive = _isActiveStatus(a.estadoActual);
          final bActive = _isActiveStatus(b.estadoActual);
          if (aActive && !bActive) return -1;
          if (!aActive && bActive) return 1;
          return (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          );
        });

        // Buscar incidente activo
        _activeIncident = _findActiveIncident();

        debugPrint('🎯 Active incident: ${_activeIncident?.id}');

        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        final errorMsg = response['message'] ?? 'Error al cargar incidentes';
        debugPrint('❌ API Error: $errorMsg');
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      // Errores de Dio (red, timeout, etc.)
      debugPrint('❌ DioException: ${e.type} - ${e.message}');

      String errorMsg;
      if (e.response != null) {
        // El servidor respondió con un código de error
        final responseData = e.response?.data;
        if (responseData is Map && responseData.containsKey('message')) {
          errorMsg = responseData['message'];
        } else if (responseData is Map && responseData.containsKey('error')) {
          errorMsg = responseData['error'];
        } else {
          errorMsg = 'Error del servidor: ${e.response?.statusCode}';
        }
      } else {
        // Error de conexión
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMsg = 'Tiempo de espera agotado. Verifica tu conexión.';
            break;
          case DioExceptionType.connectionError:
            errorMsg = 'Error de conexión. Verifica tu internet.';
            break;
          default:
            errorMsg = 'Error de red: ${e.message}';
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error inesperado: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  bool _isActiveStatus(String status) {
    return status == 'asignado' ||
        status == 'en_camino' ||
        status == 'en_sitio' ||
        status == 'en_proceso';
  }

  Incident? _findActiveIncident() {
    try {
      return _incidents.firstWhere((inc) => _isActiveStatus(inc.estadoActual));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Mis Incidencias',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadIncidents,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadIncidents,
      color: AppColors.primary,
      child: Column(
        children: [
          // Banner de incidente activo
          if (_activeIncident != null) _buildActiveBanner(),

          // Estadísticas rápidas
          _buildStatsBar(),

          // Lista de incidentes
          Expanded(
            child: _incidents.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _incidents.length,
                    itemBuilder: (context, index) {
                      final incident = _incidents[index];
                      final isActive = incident.id == _activeIncident?.id;
                      return _buildIncidentCard(incident, isActive);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingButton() {
    if (_activeIncident == null) return null;

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IncidentTrackingMapScreen(
              incidentId: _activeIncident!.id,
              userRole: 'technician',
            ),
          ),
        );
      },
      backgroundColor: AppColors.primary,
      elevation: 4,
      icon: const Icon(Icons.map_rounded, size: 24),
      label: const Text(
        'Ver Mapa y Chat',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildActiveBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incidencia Activa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Incidente #${_activeIncident!.id}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusText(_activeIncident!.estadoActual),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final activeCount = _incidents
        .where((i) => _isActiveStatus(i.estadoActual))
        .length;
    final completedCount = _incidents
        .where((i) => i.estadoActual == 'resuelto')
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.assignment_rounded,
              label: 'Total',
              value: _incidents.length.toString(),
              color: AppColors.info,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.borderLight),
          Expanded(
            child: _buildStatItem(
              icon: Icons.pending_actions_rounded,
              label: 'Activas',
              value: activeCount.toString(),
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.borderLight),
          Expanded(
            child: _buildStatItem(
              icon: Icons.check_circle_rounded,
              label: 'Resueltas',
              value: completedCount.toString(),
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Error desconocido',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadIncidents,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 80,
                color: AppColors.gray400,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No tienes incidencias',
              style: TextStyle(
                fontSize: 22,
                color: AppColors.textMain,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Las incidencias aparecerán aquí cuando te sean asignadas por el taller',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.info,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Cómo funciona',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildEmptyInfoRow(
                    icon: Icons.notifications_active_rounded,
                    text: 'Recibirás notificaciones de nuevas asignaciones',
                  ),
                  const SizedBox(height: 12),
                  _buildEmptyInfoRow(
                    icon: Icons.map_rounded,
                    text: 'El botón de mapa se activará automáticamente',
                  ),
                  const SizedBox(height: 12),
                  _buildEmptyInfoRow(
                    icon: Icons.location_on_rounded,
                    text: 'Mantén tu ubicación activada',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.info),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMain,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentCard(Incident incident, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.borderLight,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IncidentTrackingMapScreen(
                  incidentId: incident.id,
                  userRole: 'technician',
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Estado + ID + Badge activo
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(incident.estadoActual),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(incident.estadoActual),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 6, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'ACTIVO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '#${incident.id}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Descripción
                Text(
                  incident.descripcion ?? 'Sin descripción',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Información detallada
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.location_on_rounded,
                        iconColor: AppColors.error,
                        text:
                            incident.direccionReferencia ??
                            'Ubicación no disponible',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        icon: Icons.access_time_rounded,
                        iconColor: AppColors.info,
                        text: _formatDate(incident.createdAt),
                      ),
                      if (incident.categoriaIa != null) ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          icon: Icons.category_rounded,
                          iconColor: AppColors.warning,
                          text: incident.categoriaIa!,
                        ),
                      ],
                    ],
                  ),
                ),

                // Indicador de acción para incidente activo
                if (isActive) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Toca para ver mapa y chat',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMain,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return AppColors.warning;
      case 'asignado':
        return AppColors.info;
      case 'en_camino':
        return const Color(0xFF9333EA); // Purple
      case 'en_sitio':
      case 'en_proceso':
        return AppColors.success;
      case 'resuelto':
        return const Color(0xFF14B8A6); // Teal
      case 'cancelado':
        return AppColors.error;
      default:
        return AppColors.gray500;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'asignado':
        return 'ASIGNADO';
      case 'en_camino':
        return 'EN CAMINO';
      case 'en_sitio':
        return 'EN SITIO';
      case 'en_proceso':
        return 'EN PROCESO';
      case 'resuelto':
        return 'RESUELTO';
      case 'cancelado':
        return 'CANCELADO';
      case 'sin_taller_disponible':
        return 'SIN TALLER';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha no disponible';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Hace un momento';
    }
  }
}
