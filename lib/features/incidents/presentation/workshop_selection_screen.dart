import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/shared/utils/snackbar_utils.dart';
import '../providers/workshop_selection_provider.dart';
import '../data/models/workshop_selection_model.dart';

class WorkshopSelectionScreen extends ConsumerStatefulWidget {
  final int incidentId;

  const WorkshopSelectionScreen({super.key, required this.incidentId});

  @override
  ConsumerState<WorkshopSelectionScreen> createState() =>
      _WorkshopSelectionScreenState();
}

class _WorkshopSelectionScreenState
    extends ConsumerState<WorkshopSelectionScreen> {
  double _radiusKm = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkshops();
    });
  }

  void _loadWorkshops() {
    ref
        .read(workshopSelectionProvider.notifier)
        .loadWorkshops(widget.incidentId, radiusKm: _radiusKm);
  }

  Future<void> _selectWorkshop(int workshopId, String name) async {
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
          .selectWorkshop(widget.incidentId, workshopId);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, result.message);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) context.go('/incidents/${widget.incidentId}');
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workshopSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Taller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Ver en mapa',
            onPressed: () {
              state.whenOrNull(data: (workshops) {
                context.push('/incidents/${widget.incidentId}/workshop-map');
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildRadiusBar(),
          Expanded(child: state.when(
            loading: () => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Buscando talleres cercanos...',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            error: (e, _) => _buildError(e.toString()),
            data: (workshops) =>
                workshops.isEmpty ? _buildEmpty() : _buildList(workshops),
          )),
        ],
      ),
    );
  }

  Widget _buildRadiusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.tune, size: 16, color: AppColors.textMuted),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: AppColors.borderLight,
                trackHeight: 3,
              ),
              child: Slider(
                min: 5, max: 200, divisions: 39,
                value: _radiusKm,
                label: '${_radiusKm.round()} km',
                onChanged: (v) => setState(() => _radiusKm = v),
                onChangeEnd: (_) => _loadWorkshops(),
              ),
            ),
          ),
          Text('${_radiusKm.round()} km',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () {
              setState(() => _radiusKm = (_radiusKm + 25).clamp(5, 200));
              _loadWorkshops();
            },
            child: const Text('Ampliar', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(msg.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWorkshops,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined, size: 64,
                color: AppColors.textMuted.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text('No hay talleres disponibles',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textMain)),
            const SizedBox(height: 6),
            const Text('Amplía el radio de búsqueda o intenta más tarde.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _radiusKm = (_radiusKm + 25).clamp(5, 200));
                _loadWorkshops();
              },
              icon: const Icon(Icons.expand_circle_down, size: 18),
              label: const Text('Ampliar búsqueda'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<CompatibleWorkshop> workshops) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: workshops.length,
      itemBuilder: (_, i) => _buildCard(workshops[i]),
    );
  }

  Widget _buildCard(CompatibleWorkshop w) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/incidents/${widget.incidentId}/workshop-detail/${w.workshopId}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(w.workshopName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                        ),
                        _badge(w.isOpenNow ? 'Abierto' : 'Cerrado',
                            w.isOpenNow ? Colors.green.shade50 : Colors.red.shade50,
                            w.isOpenNow ? const Color(0xFF166534) : AppColors.error),
                      ],
                    ),
                    if (w.address != null) ...[
                      const SizedBox(height: 2),
                      Text(w.address!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _badge(w.formatDistance(), AppColors.primarySubtle, AppColors.primary),
                      _badge(w.formatTime(), Colors.green.shade50, const Color(0xFF166534)),
                      if (w.rating != null)
                        _badge('★ ${w.rating!.toStringAsFixed(1)}', Colors.amber.shade50, const Color(0xFF92400E)),
                      _badge('${w.availableTechnicians} téc.', AppColors.borderLight, AppColors.textMuted),
                    ]),
                    if (w.matchingServices.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('${w.matchingServices.length} servicios compatibles',
                          style: const TextStyle(fontSize: 11, color: AppColors.info)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text((w.score * 10).round().toString(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const Text('score', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(CompatibleWorkshop w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(w.workshopName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textMain)),
              if (w.address != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(w.address!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                ]),
              ],
              const SizedBox(height: 14),
              Row(children: [
                _detailBadge(Icons.straighten, w.formatDistance()),
                const SizedBox(width: 10),
                _detailBadge(Icons.timer, w.formatTime()),
                const SizedBox(width: 10),
                if (w.rating != null) ...[
                  _detailBadge(Icons.star, '${w.rating!.toStringAsFixed(1)} (${w.ratingCount})'),
                  const SizedBox(width: 10),
                ],
                _detailBadge(Icons.people, '${w.availableTechnicians} disponibles'),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.circle, size: 8, color: w.isOpenNow ? Colors.green : Colors.red),
                const SizedBox(width: 4),
                Text(w.isOpenNow ? 'Abierto ahora' : 'Cerrado ahora',
                    style: TextStyle(fontSize: 12, color: w.isOpenNow ? Colors.green : Colors.red)),
              ]),
              if (w.description != null && w.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(w.description!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
              const SizedBox(height: 16),
              if (w.matchingServices.isNotEmpty) ...[
                const Text('Servicios compatibles',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                const SizedBox(height: 8),
                ...w.matchingServices.map((s) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.baseBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMain)),
                              Text('${s.categoria} · ${s.modalidadLabel}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          )),
                          if (s.precio != null)
                            Text('\$${s.precio!.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _selectWorkshop(w.workshopId, w.workshopName);
                  },
                  icon: const Icon(Icons.send, size: 20),
                  label: const Text('Enviar solicitud a este taller',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _detailBadge(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.textMuted),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ]);
  }
}
