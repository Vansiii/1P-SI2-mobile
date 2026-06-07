import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/widgets/map/cached_osm_tile_layer.dart';
import '../providers/workshop_selection_provider.dart';
import '../data/models/workshop_selection_model.dart';

class WorkshopMapScreen extends ConsumerStatefulWidget {
  final int incidentId;
  final String origin;

  const WorkshopMapScreen({
    super.key,
    required this.incidentId,
    this.origin = 'report',
  });

  @override
  ConsumerState<WorkshopMapScreen> createState() => _WorkshopMapScreenState();
}

class _WorkshopMapScreenState extends ConsumerState<WorkshopMapScreen> {
  CompatibleWorkshop? _selectedWorkshop;
  double _incidentLat = 0;
  double _incidentLng = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workshopSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Talleres'),
      ),
      body: state.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(e.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
        data: (workshops) {
          if (workshops.isEmpty) {
            return const Center(
              child: Text('No hay talleres para mostrar',
                  style: TextStyle(color: AppColors.textMuted)),
            );
          }

          if (workshops.isNotEmpty) {
            _incidentLat = workshops.first.latitude;
            _incidentLng = workshops.first.longitude;
          }

          final center = LatLng(
            workshops.map((w) => w.latitude).reduce((a, b) => a + b) /
                workshops.length,
            workshops.map((w) => w.longitude).reduce((a, b) => a + b) /
                workshops.length,
          );

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12.5,
                ),
                children: [
                  const CachedOsmTileLayer(),
                  MarkerLayer(
                    markers: _buildMarkers(workshops),
                  ),
                ],
              ),
              if (_selectedWorkshop != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildWorkshopPreview(_selectedWorkshop!),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Marker> _buildMarkers(List<CompatibleWorkshop> workshops) {
    return [
      _incidentPin(LatLng(_incidentLat, _incidentLng)),
      ...workshops.map((w) => _workshopPin(w)),
    ];
  }

  Marker _incidentPin(LatLng point) {
    return Marker(
      point: point,
      width: 80,
      height: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: AppColors.error, size: 42),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(230),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Incidente',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Marker _workshopPin(CompatibleWorkshop w) {
    final color = w.isAvailable ? AppColors.primary : AppColors.gray400;
    return Marker(
      point: LatLng(w.latitude, w.longitude),
      width: 90,
      height: 80,
      child: GestureDetector(
        onTap: () => setState(() => _selectedWorkshop = w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: color, size: 36),
            const SizedBox(height: 2),
            Text(
              w.workshopName,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopPreview(CompatibleWorkshop w) {
    final incidentId = widget.incidentId;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(w.workshopName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      setState(() => _selectedWorkshop = null),
                ),
              ],
            ),
            if (w.address != null)
              Text(w.address!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _mapBadge(w.formatDistance()),
              _mapBadge(w.formatTime()),
              if (w.rating != null)
                _mapBadge('★ ${w.rating!.toStringAsFixed(1)}'),
              _mapBadge('${w.matchingServices.length} servicios'),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await context.push<bool>(
                        '/incidents/$incidentId/workshop-detail/${w.workshopId}'
                        '?origin=${widget.origin}',
                      );
                      if (selected != true || !mounted) return;
                      context.pop(true);
                    },
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Ver detalles',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.list, size: 16),
                    label: const Text('Ver lista',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
    );
  }
}
