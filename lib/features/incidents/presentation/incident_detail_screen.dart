import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/incident_provider.dart';
import '../data/models/incident_ai_analysis_model.dart';
import '../data/models/incident_model.dart';

class IncidentDetailScreen extends ConsumerStatefulWidget {
  final int incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  ConsumerState<IncidentDetailScreen> createState() =>
      _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen> {
  IncidentModel? _incident;
  IncidentAiAnalysisModel? _latestAiAnalysis;
  List<IncidentAiAnalysisModel> _aiAnalysisHistory = const [];
  bool _isLoading = true;
  bool _isLoadingAiAnalysis = false;
  String? _error;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAudioIndex;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadIncidentDetail();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadIncidentDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final incident = await ref
          .read(incidentsProvider.notifier)
          .getIncidentDetail(widget.incidentId);

      if (mounted) {
        setState(() {
          _incident = incident;
          _isLoading = false;
        });

        await _loadAiAnalysisData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAiAnalysisData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingAiAnalysis = true;
    });

    final incidentsNotifier = ref.read(incidentsProvider.notifier);
    IncidentAiAnalysisModel? latestAnalysis;
    List<IncidentAiAnalysisModel> analysisHistory = const [];

    try {
      latestAnalysis = await incidentsNotifier.getLatestIncidentAiAnalysis(
        widget.incidentId,
      );
    } catch (_) {
      latestAnalysis = null;
    }

    try {
      analysisHistory = await incidentsNotifier.getIncidentAiAnalysisHistory(
        widget.incidentId,
      );
    } catch (_) {
      analysisHistory = const [];
    }

    if (!mounted) return;

    setState(() {
      _latestAiAnalysis = latestAnalysis;
      _aiAnalysisHistory = analysisHistory;
      _isLoadingAiAnalysis = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.baseBg,
        appBar: AppBar(
          title: const Text(
            'Detalle de Emergencia',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textMain),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.baseBg,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.surface,
          iconTheme: const IconThemeData(color: AppColors.textMain),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Error al cargar el incidente',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadIncidentDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_incident == null) {
      return Scaffold(
        backgroundColor: AppColors.baseBg,
        appBar: AppBar(
          title: const Text('Incidente no encontrado'),
          backgroundColor: AppColors.surface,
          iconTheme: const IconThemeData(color: AppColors.textMain),
        ),
        body: const Center(child: Text('Incidente no encontrado')),
      );
    }

    return _buildDetailScreen(context, ref, _incident!);
  }

  Widget _buildDetailScreen(
    BuildContext context,
    WidgetRef ref,
    IncidentModel incident,
  ) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: CustomScrollView(
        slivers: [
          // AppBar con estado
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _getStatusColor(incident.estadoActual),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Emergencia #${incident.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getStatusColor(incident.estadoActual),
                      _getStatusColor(
                        incident.estadoActual,
                      ).withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado y prioridad
                  Row(
                    children: [
                      _buildStatusChip(incident),
                      if (incident.prioridadIa != null) ...[
                        const SizedBox(width: 12),
                        _buildPriorityChip(incident),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Descripción
                  _buildSection(
                    context,
                    icon: Icons.description_outlined,
                    title: 'Descripción',
                    child: Text(
                      incident.descripcion,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),

                  // Resumen IA
                  if (incident.resumenIa != null) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      icon: Icons.auto_awesome,
                      title: 'Análisis IA',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          incident.resumenIa!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                height: 1.5,
                                color: AppColors.textMain,
                              ),
                        ),
                      ),
                    ),
                  ],

                  if (_isLoadingAiAnalysis ||
                      _latestAiAnalysis != null ||
                      _aiAnalysisHistory.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      icon: Icons.manage_search_outlined,
                      title: 'Estado Procesamiento IA',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoadingAiAnalysis)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            ),
                          if (_latestAiAnalysis != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getAiStatusIcon(
                                          _latestAiAnalysis!.status,
                                        ),
                                        size: 20,
                                        color: _getAiStatusColor(
                                          _latestAiAnalysis!.status,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _latestAiAnalysis!.statusLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: _getAiStatusColor(
                                                _latestAiAnalysis!.status,
                                              ),
                                            ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Intento #${_latestAiAnalysis!.attemptNumber}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Actualizado: ${_formatDateTime(_latestAiAnalysis!.updatedAt)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textMuted),
                                  ),
                                  if (_latestAiAnalysis!.summary != null &&
                                      _latestAiAnalysis!.summary!
                                          .trim()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _latestAiAnalysis!.summary!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textMain,
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if (_aiAnalysisHistory.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Historial de análisis',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMain,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ..._aiAnalysisHistory
                                .take(5)
                                .map(
                                  (analysis) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getAiStatusIcon(analysis.status),
                                          size: 18,
                                          color: _getAiStatusColor(
                                            analysis.status,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Intento #${analysis.attemptNumber} - ${analysis.statusLabel}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: AppColors.textMain,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          _formatDateTime(analysis.createdAt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Categoría
                  if (incident.categoriaIa != null) ...[
                    const SizedBox(height: 20),
                    _buildInfoCard(
                      context,
                      icon: Icons.category_outlined,
                      label: 'Categoría',
                      value: incident.categoriaIa!,
                      color: AppColors.primary,
                    ),
                  ],

                  // Imágenes
                  if (incident.imagenes != null &&
                      incident.imagenes!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      icon: Icons.photo_library_outlined,
                      title: 'Imágenes (${incident.imagenes!.length})',
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: incident.imagenes!.length,
                        itemBuilder: (context, index) {
                          final imagen = incident.imagenes![index];
                          return GestureDetector(
                            onTap: () =>
                                _showImageDialog(context, imagen.fileUrl),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                imagen.fileUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: AppColors.textMuted,
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Audios
                  if (incident.audios != null &&
                      incident.audios!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      icon: Icons.audiotrack_outlined,
                      title: 'Audios (${incident.audios!.length})',
                      child: Column(
                        children: incident.audios!.asMap().entries.map((entry) {
                          final index = entry.key;
                          final audio = entry.value;
                          final isPlaying =
                              _playingAudioIndex == index && _isPlaying;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPlaying
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isPlaying ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Botón de reproducir/pausar
                                Material(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () => _toggleAudioPlayback(
                                      index,
                                      audio.fileUrl,
                                    ),
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: AppColors.primary,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Información del audio
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        audio.fileName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textMain,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.audiotrack,
                                            size: 14,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isPlaying
                                                ? 'Reproduciendo...'
                                                : 'Toca para reproducir',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Ubicación
                  _buildSection(
                    context,
                    icon: Icons.location_on_outlined,
                    title: 'Ubicación',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (incident.direccionReferencia != null) ...[
                          Text(
                            incident.direccionReferencia!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                incident.latitude,
                                incident.longitude,
                              ),
                              initialZoom: 15,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.mobile',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      incident.latitude,
                                      incident.longitude,
                                    ),
                                    width: 50,
                                    height: 50,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: AppColors.error,
                                      size: 50,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Lat: ${incident.latitude.toStringAsFixed(6)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Lng: ${incident.longitude.toStringAsFixed(6)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openInMaps(
                              incident.latitude,
                              incident.longitude,
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Abrir en Mapas'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Información temporal
                  _buildSection(
                    context,
                    icon: Icons.access_time_outlined,
                    title: 'Información Temporal',
                    child: Column(
                      children: [
                        _buildTimelineItem(
                          context,
                          'Reportado',
                          _formatDateTime(incident.createdAt),
                          Icons.report_problem_outlined,
                          AppColors.error,
                        ),
                        if (incident.assignedAt != null)
                          _buildTimelineItem(
                            context,
                            'Asignado',
                            _formatDateTime(incident.assignedAt!),
                            Icons.assignment_turned_in_outlined,
                            AppColors.info,
                          ),
                        if (incident.resolvedAt != null)
                          _buildTimelineItem(
                            context,
                            'Resuelto',
                            _formatDateTime(incident.resolvedAt!),
                            Icons.check_circle_outline,
                            AppColors.success,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildStatusChip(IncidentModel incident) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor(incident.estadoActual).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(incident.estadoActual),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(incident.estadoActual),
            size: 18,
            color: _getStatusColor(incident.estadoActual),
          ),
          const SizedBox(width: 6),
          Text(
            incident.estadoLabel,
            style: TextStyle(
              color: _getStatusColor(incident.estadoActual),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(IncidentModel incident) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getPriorityColor(incident.prioridadIa).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getPriorityColor(incident.prioridadIa),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.priority_high,
            size: 18,
            color: _getPriorityColor(incident.prioridadIa),
          ),
          const SizedBox(width: 6),
          Text(
            incident.prioridadLabel,
            style: TextStyle(
              color: _getPriorityColor(incident.prioridadIa),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
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

  Widget _buildTimelineItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
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
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      default:
        return AppColors.textMuted;
    }
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
      default:
        return Icons.help_outline;
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

  Color _getAiStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getAiStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_outlined;
      case 'processing':
        return Icons.autorenew_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime date) {
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

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.day} ${months[date.month - 1]} ${date.year} - $hour:$minute';
  }

  Future<void> _openInMaps(double latitude, double longitude) async {
    try {
      // Intentar abrir en Google Maps primero (funciona en Android e iOS)
      final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );

      // Intentar lanzar directamente
      final launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Si falla, intentar con el esquema geo: (Android)
        final geoUrl = Uri.parse(
          'geo:$latitude,$longitude?q=$latitude,$longitude',
        );
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Si todo falla, mostrar mensaje al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir la aplicación de mapas: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 60,
                        color: Colors.white,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAudioPlayback(int index, String audioUrl) async {
    try {
      if (_playingAudioIndex == index && _isPlaying) {
        // Pausar audio actual
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        // Reproducir nuevo audio
        if (_playingAudioIndex != index) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _playingAudioIndex = index;
          _isPlaying = true;
        });

        // Listener para cuando termine el audio
        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _playingAudioIndex = null;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }
}
