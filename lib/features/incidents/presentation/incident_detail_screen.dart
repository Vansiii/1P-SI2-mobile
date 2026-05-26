import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_colors.dart';
import '../../payments/presentation/payment_screen.dart';
import '../../payments/providers/payment_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/incident_realtime_provider.dart';
import '../providers/incidents_websocket_provider.dart';
import '../data/models/incident_ai_analysis_model.dart';
import '../data/models/incident_model.dart';
import '../services/incident_analysis_realtime_service.dart';
import 'incident_tracking_map_screen.dart';

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
  bool _isLoading = true;
  bool _isLoadingAiAnalysis = false;
  String? _error;
  
  // Payment status
  bool _isPaid = false;
  int? _transactionId;
  bool _isCheckingPayment = false;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAudioIndex;
  bool _isPlaying = false;

  // Cancel incident
  bool _isCancelling = false;
  bool _isCompleting = false;

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
        
        if (incident.estadoActual == 'resuelto') {
          await _checkPaymentStatus();
        }
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

  Future<void> _checkPaymentStatus() async {
    if (!mounted) return;
    
    setState(() {
      _isCheckingPayment = true;
    });
    
    try {
      final status = await ref.read(paymentProvider.notifier).checkPaymentStatus(widget.incidentId);
      if (status != null && status['is_paid'] == true && mounted) {
        setState(() {
          _isPaid = true;
          _transactionId = status['transaction_id'] as int?;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
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

    try {
      latestAnalysis = await incidentsNotifier.getLatestIncidentAiAnalysis(
        widget.incidentId,
      );
    } catch (_) {
      latestAnalysis = null;
    }

    if (!mounted) return;

    setState(() {
      _latestAiAnalysis = latestAnalysis;
      _isLoadingAiAnalysis = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Real-time: watch incident realtime state to keep provider alive
    ref.watch(incidentRealtimeStateProvider(widget.incidentId));

    // Real-time: react to status changes from WebSocket
    ref.listen<IncidentRealtimeState?>(
      incidentRealtimeStateProvider(widget.incidentId),
      (previous, next) {
        if (previous == null || next == null) return;
        if (previous.status != next.status && _incident != null) {
          setState(() {
            _incident = _incident!.copyWith(estadoActual: next.status);
          });
        }
      },
    );

    // Real-time: react to AI analysis completion
    ref.listen<Map<int, IncidentAnalysisState>>(
      incidentAnalysisRealtimeProvider,
      (previous, next) {
        if (previous == null) return;
        final prevState = previous[widget.incidentId];
        final nextState = next[widget.incidentId];
        if (prevState?.status != AnalysisStatus.completed &&
            nextState?.status == AnalysisStatus.completed) {
          _loadAiAnalysisData();
          _loadIncidentDetail();
        }
      },
    );

    // Real-time: auto-reload detail when WebSocket provider updates this incident
    ref.listen<List<IncidentModel>>(incidentsWebSocketProvider, (previous, next) {
      if (previous == null || _incident == null) return;
      final prevIncident = previous.where((i) => i.id == widget.incidentId).firstOrNull;
      final nextIncident = next.where((i) => i.id == widget.incidentId).firstOrNull;
      if (prevIncident == null && nextIncident != null) {
        _loadIncidentDetail();
      }
      if (prevIncident != null && nextIncident != null) {
        final needsRefresh = prevIncident.estadoActual != nextIncident.estadoActual ||
            prevIncident.tallerId != nextIncident.tallerId ||
            prevIncident.tecnicoId != nextIncident.tecnicoId ||
            prevIncident.prioridadIa != nextIncident.prioridadIa ||
            prevIncident.categoriaIa != nextIncident.categoriaIa;
        if (needsRefresh) {
          _loadIncidentDetail();
        }
      }
    });

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
    // Verificar si el incidente está asignado y puede ser seguido en tiempo real
    final canTrack =
        incident.estadoActual == 'asignado' ||
        incident.estadoActual == 'en_proceso' ||
        incident.estadoActual == 'en_camino' ||
        incident.estadoActual == 'en_sitio';

    // Verificar si el incidente puede ser cancelado
    final canCancel =
        incident.estadoActual == 'pendiente' ||
        incident.estadoActual == 'asignado' ||
        incident.estadoActual == 'en_proceso';

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
            actions: [
              // Menú de acciones
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                enabled:
                    !_isCancelling &&
                    !_isCompleting, // Deshabilitar si hay operaciones en curso
                onSelected: (value) {
                  switch (value) {
                    case 'cancel':
                      _showCancelDialog(context, incident.id);
                      break;
                    case 'complete':
                      _showCompleteDialog(context, incident.id);
                      break;
                  }
                },
                itemBuilder: (context) {
                  final List<PopupMenuEntry<String>> items = [];

                  // Opción de cancelar (solo si puede ser cancelado)
                  if (canCancel) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'cancel',
                        enabled: !_isCancelling && !_isCompleting,
                        child: Row(
                          children: [
                            _isCancelling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.cancel_outlined,
                                    color: AppColors.error,
                                  ),
                            const SizedBox(width: 12),
                            Text(
                              _isCancelling
                                  ? 'Cancelando...'
                                  : 'Cancelar Incidente',
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Opción de completar (solo si está en proceso o en sitio)
                  if (incident.estadoActual == 'en_proceso' ||
                      incident.estadoActual == 'en_sitio') {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'complete',
                        enabled: !_isCancelling && !_isCompleting,
                        child: Row(
                          children: [
                            _isCompleting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.success,
                                  ),
                            const SizedBox(width: 12),
                            Text(
                              _isCompleting
                                  ? 'Completando...'
                                  : 'Marcar como Completado',
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return items;
                },
              ),
            ],
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

                  if (_isLoadingAiAnalysis || _latestAiAnalysis != null) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      icon: Icons.psychology_alt_outlined,
                      title: 'Detalle IA',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoadingAiAnalysis)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            ),
                          if (_latestAiAnalysis != null)
                            _buildAiInsightsCard(context, _latestAiAnalysis!),
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
                  
                  if (incident.estadoActual == 'resuelto') ...[
                    const SizedBox(height: 32),
                    if (_isCheckingPayment)
                      const Center(child: CircularProgressIndicator())
                    else if (_isPaid)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _transactionId == null ? null : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentReceiptScreen(
                                  transactionId: _transactionId!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Ver Comprobante de Pago', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentScreen(
                                  incidentId: incident.id,
                                  incidentDescription: incident.descripcion,
                                ),
                              ),
                            ).then((_) {
                              // Reload incident detail after returning from payment screen
                              _loadIncidentDetail();
                            });
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('Proceder al Pago', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      // Botón flotante para seguimiento en tiempo real
      floatingActionButton: canTrack
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IncidentTrackingMapScreen(
                      incidentId: incident.id,
                      userRole: 'client',
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.map),
              label: const Text('Ver Seguimiento'),
            )
          : null,
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

  Widget _buildAiInsightsCard(
    BuildContext context,
    IncidentAiAnalysisModel analysis,
  ) {
    final hasSummary =
        analysis.summary != null && analysis.summary!.trim().isNotEmpty;

    return Container(
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (analysis.confidence != null)
                _buildSmallTag(
                  context,
                  'Confianza: ${(analysis.confidence! * 100).toStringAsFixed(0)}%',
                  AppColors.info,
                ),
              if (analysis.category != null &&
                  analysis.category!.trim().isNotEmpty)
                _buildSmallTag(
                  context,
                  'Categoría: ${analysis.category}',
                  AppColors.primary,
                ),
              _buildSmallTag(
                context,
                analysis.isAmbiguous ? 'Caso ambiguo' : 'Caso claro',
                analysis.isAmbiguous ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          if (hasSummary) ...[
            const SizedBox(height: 12),
            Text(
              analysis.summary!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMain,
                height: 1.5,
              ),
            ),
          ],
          if (analysis.findings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Hallazgos relevantes',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            _buildBulletList(context, analysis.findings.take(4).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallTag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBulletList(BuildContext context, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMain,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
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

  void _showCompleteDialog(BuildContext context, int incidentId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Completar Incidente'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Confirmas que el problema ha sido resuelto satisfactoriamente?',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Esta acción marcará el incidente como completado.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _completeIncident(incidentId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, completar'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, int incidentId) {
    final TextEditingController motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar Incidente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de que deseas cancelar este incidente?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ej: Lo solucioné yo mismo',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('No, volver'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _cancelIncident(incidentId, motivoController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelIncident(int incidentId, String motivo) async {
    setState(() => _isCancelling = true);

    try {
      await ref
          .read(incidentsProvider.notifier)
          .cancelIncident(
            incidentId: incidentId,
            motivo: motivo.isEmpty ? null : motivo,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incidente cancelado exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );

        // Volver a la lista de incidentes
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cancelar incidente: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _completeIncident(int incidentId) async {
    setState(() => _isCompleting = true);

    try {
      await ref
          .read(incidentsProvider.notifier)
          .completeIncident(incidentId: incidentId);

      if (mounted) {
        setState(() => _isCompleting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incidente marcado como completado'),
            backgroundColor: AppColors.success,
          ),
        );

        // Recargar los detalles del incidente para mostrar el nuevo estado
        await _loadIncidentDetail();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al completar incidente: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
