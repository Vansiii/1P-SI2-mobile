import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/widgets/map/cached_osm_tile_layer.dart';
import 'package:merchanic_repair/shared/utils/snackbar_utils.dart';
import 'package:merchanic_repair/features/cotizaciones/providers/cotizacion_provider.dart';
import '../providers/workshop_selection_provider.dart';
import '../data/models/workshop_selection_model.dart';

class WorkshopDetailScreen extends ConsumerStatefulWidget {
  final int incidentId;
  final int workshopId;
  final String origin;

  const WorkshopDetailScreen({
    super.key,
    required this.incidentId,
    required this.workshopId,
    this.origin = 'report',
  });

  @override
  ConsumerState<WorkshopDetailScreen> createState() =>
      _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends ConsumerState<WorkshopDetailScreen> {
  final ScrollController _historyScrollController = ScrollController();

  @override
  void dispose() {
    _historyScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WorkshopDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidentId != widget.incidentId ||
        oldWidget.workshopId != widget.workshopId) {
      ref.invalidate(
        assignmentHistoryProvider(
          (incidentId: oldWidget.incidentId, workshopId: oldWidget.workshopId),
        ),
      );
      ref.invalidate(
        assignmentHistoryProvider(
          (incidentId: widget.incidentId, workshopId: widget.workshopId),
        ),
      );
    }
  }

  Future<void> _openCotizacion() async {
    try {
      final repo = ref.read(cotizacionRepositoryProvider);
      final cotizaciones = await repo.getCotizaciones();
      final existente = cotizaciones.where(
        (c) => c.incidenteId == widget.incidentId 
            && c.workshopId == widget.workshopId
            && c.estado != 'cancelado'
            && c.estado != 'rechazado',
      );
      if (existente.isNotEmpty) {
        if (mounted) context.push('/cotizaciones/${existente.first.id}');
        return;
      }
    } catch (_) {}
    if (mounted) {
      context.push('/cotizaciones/preview/${widget.incidentId}/${widget.workshopId}');
    }
  }

  Future<void> _selectWorkshop(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar solicitud'),
        content: Text('¿Enviar solicitud de servicio a "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ref
          .read(workshopSelectionProvider.notifier)
          .selectWorkshop(widget.incidentId, widget.workshopId);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, result.message);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        context.pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
          context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workshopSelectionProvider);
    final profileAsync = ref.watch(
        workshopPublicProfileProvider(widget.workshopId));

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Detalle del Taller'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'cotizar') {
                _openCotizacion();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'cotizar',
                child: ListTile(
                  leading: Icon(Icons.request_quote, color: AppColors.primary),
                  title: Text('Cotizacion'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _buildError(e),
        data: (workshops) {
          final w = workshops.firstWhere(
            (w) => w.workshopId == widget.workshopId,
            orElse: () => workshops.first,
          );

          final profile = profileAsync.whenOrNull(
            data: (d) => d,
          );

          final historyAsync = ref.watch(
              assignmentHistoryProvider(
                  (incidentId: widget.incidentId, workshopId: widget.workshopId)));
          final history = (historyAsync.whenOrNull(data: (d) => d) ?? [])
              .where((item) =>
                  item.incidentId == widget.incidentId &&
                  item.workshopId == widget.workshopId)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(w),
                const SizedBox(height: 16),
                _buildQuickInfo(w),
                const SizedBox(height: 16),
                _buildEstimateCard(w),
                const SizedBox(height: 16),
                _buildDescription(w),
                const SizedBox(height: 16),
                _buildLocationCard(w),
                const SizedBox(height: 16),
                _buildMapSection(w),
                if (w.matchingServices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildMatchingServices(w),
                ],
                if (profile != null) ...[
                  const SizedBox(height: 16),
                  _buildProfileServices(profile, w),
                  const SizedBox(height: 16),
                  _buildSchedules(profile),
                ],
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildHistory(history),
                ],
                const SizedBox(height: 24),
                _buildSendButton(w),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(e.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildMapSection(CompatibleWorkshop w) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(w.latitude, w.longitude),
          initialZoom: 14.5,
        ),
        children: [
          const CachedOsmTileLayer(),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(w.latitude, w.longitude),
                width: 60,
                height: 60,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on,
                    color: AppColors.primary, size: 42),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHero(CompatibleWorkshop w) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.build, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            w.workshopName,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      w.isOpenNow ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: w.isOpenNow ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      w.isOpenNow ? 'Abierto ahora' : 'Cerrado ahora',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: w.isOpenNow
                            ? const Color(0xFF166534)
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (!w.isAvailable) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'No disponible ahora',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo(CompatibleWorkshop w) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickStat(Icons.straighten, w.formatDistance(), 'Distancia'),
          _quickStat(Icons.timer, w.formatTime(), 'Tiempo est. IA'),
          if (w.rating != null)
            _quickStat(Icons.star,
                '${w.rating!.toStringAsFixed(1)} (${w.ratingCount})', 'Rating'),
          _quickStat(
              Icons.people, '${w.availableTechnicians} téc.', 'Técnicos'),
        ],
      ),
    );
  }

  Widget _quickStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain),
              textAlign: TextAlign.center),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(CompatibleWorkshop w) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.primarySubtle
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 24, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tiempo estimado de reparación',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain),
                ),
                const SizedBox(height: 4),
                Text(
                  w.estimatedTimeMinutes != null
                      ? '~${w.formatTime()}'
                      : 'A confirmar',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: w.estimatedTimeMinutes != null
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  w.estimatedTimeMinutes != null
                      ? 'Calculado según la categoría del incidente y los servicios del taller'
                      : 'El taller confirmará el tiempo al aceptar la solicitud',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(CompatibleWorkshop w) {
    if (w.description == null || w.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description, size: 16, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Descripción',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain)),
            ],
          ),
          const SizedBox(height: 8),
          Text(w.description!,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildMatchingServices(CompatibleWorkshop w) {
    if (w.matchingServices.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'Servicios compatibles (${w.matchingServices.length})',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain),
              ),
              const Spacer(),
              Text('IA',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary.withOpacity(0.6),
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ...w.matchingServices.map((MatchingService s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.baseBg,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle,
                          size: 16, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nombre,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMain)),
                          const SizedBox(height: 2),
                          Text(
                            '${s.categoria} · ${s.modalidadLabel}${s.tiempoEstimadoMin != null ? " · ~${s.tiempoEstimadoMin} min" : ""}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (s.precio != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '\$${s.precio!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildProfileServices(Map<String, dynamic> profile, CompatibleWorkshop w) {
    final services = profile['active_services'] as List<dynamic>? ?? [];
    if (services.isEmpty) return const SizedBox.shrink();

    final matchingNames = w.matchingServices.map((s) => s.nombre).toSet();

    return _ServiceSearchableList(
      title: 'Todos los servicios (${services.length})',
      subtitle: 'Catálogo completo del taller',
      icon: Icons.build_circle,
      iconColor: AppColors.primary,
      services: services,
      highlight: matchingNames,
    );
  }

  String _modalidadLabel(String modalidad) {
    switch (modalidad) {
      case 'ambas':
        return 'Taller + Dom.';
      case 'domicilio':
        return 'A Domicilio';
      default:
        return 'En Taller';
    }
  }

  Widget _buildSchedules(Map<String, dynamic> profile) {
    final schedules = profile['schedules'] as List<dynamic>? ?? [];
    if (schedules.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time, size: 16, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Horarios',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain)),
            ],
          ),
          const SizedBox(height: 10),
          ...schedules.map((s) {
            final map = s as Map<String, dynamic>;
            final day = map['day'] as String? ?? '';
            final open = map['open_time'] as String?;
            final close = map['close_time'] as String?;
            final isOpen = map['is_open'] as bool? ?? true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(day,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMain)),
                  ),
                  Expanded(
                    child: Text(
                      isOpen
                          ? '${_formatTime(open)} - ${_formatTime(close)}'
                          : 'Cerrado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOpen ? AppColors.textMuted : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null) return '--:--';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    return '${h > 12 ? h - 12 : (h == 0 ? 12 : h)}:$m ${h >= 12 ? 'PM' : 'AM'}';
  }

  Widget _buildLocationCard(CompatibleWorkshop w) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Ubicación',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain)),
            ],
          ),
          const SizedBox(height: 10),
          if (w.address != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.place, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(w.address!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMain)),
                  ),
                ],
              ),
            ),
          _locationRow(
              'Coordenadas',
              '${w.latitude.toStringAsFixed(6)}, ${w.longitude.toStringAsFixed(6)}'),
          _locationRow('Distancia', w.formatDistance()),
          if (w.coverageRadiusKm != null)
            _locationRow('Radio de cobertura',
                '${w.coverageRadiusKm!.toStringAsFixed(1)} km'),
          _locationRow('Score IA',
              '${(w.score * 10).round()}/10 (${(w.score * 100).round()}%)'),
        ],
      ),
    );
  }

  Widget _locationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(List<AssignmentHistoryItem> history) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, size: 16, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Historial de solicitudes',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain)),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Scrollbar(
              controller: _historyScrollController,
              thumbVisibility: history.length > 3,
              child: ListView.separated(
                controller: _historyScrollController,
                primary: false,
                padding: EdgeInsets.zero,
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) => _historyItem(history[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyItem(AssignmentHistoryItem h) {
    final icon = h.isTimeout
        ? Icons.timer_off
        : h.isRejected
            ? Icons.cancel
            : h.isCancelled
                ? Icons.remove_circle
                : h.isAccepted
                    ? Icons.check_circle
                    : Icons.schedule;

    final color = h.isTimeout
        ? Colors.orange
        : h.isRejected
            ? AppColors.error
            : h.isCancelled
                ? AppColors.textMuted
                : h.isAccepted
                    ? AppColors.success
                    : AppColors.info;

    final isActive = h.isPending;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.baseBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? AppColors.info.withOpacity(0.3) : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(h.statusLabel,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color)),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.info),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    h.elapsedLabel,
                    if (h.assignmentStrategy == 'client_selection')
                      'Selección manual'
                    else
                      'Asignación automática',
                    if (h.respondedAt != null)
                      'Respondió ${_formatDate(h.respondedAt!)}',
                    if (h.timeoutAt != null)
                      'Timeout: ${_formatDate(h.timeoutAt!)}',
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                if (h.responseMessage != null &&
                    h.responseMessage!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(h.responseMessage!,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF92400E),
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _buildSendButton(CompatibleWorkshop w) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _selectWorkshop(w.workshopName),
        icon: const Icon(Icons.send, size: 20),
        label: Text(
          'Enviar solicitud a ${w.workshopName}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _ServiceSearchableList extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<dynamic> services;
  final Set<String>? highlight;

  const _ServiceSearchableList({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.services,
    this.highlight,
  });

  @override
  State<_ServiceSearchableList> createState() => _ServiceSearchableListState();
}

class _ServiceSearchableListState extends State<_ServiceSearchableList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered() {
    final all = widget.services.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((s) {
      final nombre = (s['nombre'] as String? ?? '').toLowerCase();
      final categoria = (s['categoria'] as String? ?? '').toLowerCase();
      return nombre.contains(q) || categoria.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 16, color: widget.iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(widget.subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar servicio...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        child: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('No se encontraron servicios',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _serviceTile(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _serviceTile(Map<String, dynamic> s) {
    final nombre = s['nombre'] as String? ?? '';
    final categoria = s['categoria'] as String? ?? '';
    final modalidad = s['modalidad'] as String? ?? 'taller';
    final tiempo = s['tiempo_estimado_min'] as int?;
    final precio = s['precio'];
    final priceStr = precio != null
        ? '\$${(precio is double ? precio : (precio as num).toDouble()).toStringAsFixed(0)}'
        : null;
    final isHighlighted = widget.highlight != null && widget.highlight!.contains(nombre);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.success.withOpacity(0.05) : AppColors.baseBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? AppColors.success.withOpacity(0.3) : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          if (isHighlighted) ...[
            const Icon(Icons.check_circle, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textMain)),
                const SizedBox(height: 2),
                Text(
                  [categoria, _modalidadLabelStatic(modalidad),
                   if (tiempo != null) '~$tiempo min',
                   if (priceStr != null) priceStr,
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _modalidadLabelStatic(String modalidad) {
    switch (modalidad) {
      case 'ambas':
        return 'Taller + Dom.';
      case 'domicilio':
        return 'A Domicilio';
      default:
        return 'En Taller';
    }
  }
}
