import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/map/cached_osm_tile_layer.dart';
import '../../../widgets/map/smart_map_marker.dart';
import '../../../widgets/map/map_compass_button.dart';
import '../../../services/api_service.dart';

class CotizacionRutaScreen extends ConsumerStatefulWidget {
  final double origenLat;
  final double origenLng;
  final String origenNombre;
  final double destinoLat;
  final double destinoLng;
  final String destinoNombre;
  final double distanciaKm;
  final double duracionMin;

  const CotizacionRutaScreen({
    super.key,
    required this.origenLat,
    required this.origenLng,
    required this.origenNombre,
    required this.destinoLat,
    required this.destinoLng,
    required this.destinoNombre,
    required this.distanciaKm,
    required this.duracionMin,
  });

  @override
  ConsumerState<CotizacionRutaScreen> createState() => _CotizacionRutaScreenState();
}

class _CotizacionRutaScreenState extends ConsumerState<CotizacionRutaScreen> {
  List<LatLng> _routePoints = [];
  double _distanciaKm = 0;
  double _duracionMin = 0;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _distanciaKm = widget.distanciaKm;
    _duracionMin = widget.duracionMin;
    _loadOSRMRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitMap();
    });
  }

  Future<void> _loadOSRMRoute() async {
    try {
      final api = ref.read(apiServiceProvider);
      final route = await api.calculateRoute(
        originLat: widget.origenLat,
        originLng: widget.origenLng,
        destLat: widget.destinoLat,
        destLng: widget.destinoLng,
      );
      if (!mounted) return;

      final geometry = route['geometry'] as Map<String, dynamic>?;
      final distanceKm = (route['distance_km'] as num?)?.toDouble();
      final durationMin = (route['duration_minutes'] as num?)?.toDouble();

      setState(() {
        if (distanceKm != null) _distanciaKm = distanceKm;
        if (durationMin != null) _duracionMin = durationMin;
        if (geometry != null) {
          _routePoints = _parseOSRMGeometry(geometry);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routePoints = [];
      });
    }
  }

  List<LatLng> _parseOSRMGeometry(Map<String, dynamic> geometry) {
    final coords = geometry['coordinates'] as List<dynamic>?;
    if (coords == null) return <LatLng>[];
    return coords.map((c) {
      final l = c as List<dynamic>;
      return LatLng(
        (l[1] as num).toDouble(),
        (l[0] as num).toDouble(),
      );
    }).toList();
  }

  void _fitMap() {
    final center = LatLng(
      (widget.origenLat + widget.destinoLat) / 2,
      (widget.origenLng + widget.destinoLng) / 2,
    );
    double zoom = 14;
    if (_distanciaKm > 5) zoom = 12;
    if (_distanciaKm > 20) zoom = 10;
    _mapController.move(center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  (widget.origenLat + widget.destinoLat) / 2,
                  (widget.origenLng + widget.destinoLng) / 2,
                ),
                initialZoom: _distanciaKm > 20 ? 10 : (_distanciaKm > 5 ? 12 : 14),
              ),
              children: [
                const CachedOsmTileLayer(),
                PolylineLayer(
                  polylines: [
                    if (_routePoints.isNotEmpty)
                      Polyline(
                        points: _routePoints,
                        color: const Color(0xFF4285F4),
                        strokeWidth: 4,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                      )
                    else
                      Polyline(
                        points: [LatLng(widget.origenLat, widget.origenLng), LatLng(widget.destinoLat, widget.destinoLng)],
                        color: const Color(0xFFF59E0B),
                        strokeWidth: 3,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.origenLat, widget.origenLng),
                      width: SmartMapMarker.markerWidth,
                      height: SmartMapMarker.markerHeight,
                      alignment: Alignment.topCenter,
                      child: const SmartMapMarker(role: MarkerRole.client, isSelected: false),
                    ),
                    Marker(
                      point: LatLng(widget.destinoLat, widget.destinoLng),
                      width: SmartMapMarker.markerWidth,
                      height: SmartMapMarker.markerHeight,
                      alignment: Alignment.topCenter,
                      child: const SmartMapMarker(role: MarkerRole.workshop, isSelected: false),
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: MapCompassButton(mapController: _mapController, top: 0, right: 0),
                ),
                const RichAttributionWidget(attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ]),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoCard(Icons.straighten, 'Distancia', '${_distanciaKm.toStringAsFixed(1)} km'),
                      _infoCard(Icons.timer, 'Tiempo est.', '${_duracionMin.toStringAsFixed(0)} min'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFFEA4335)),
                      const SizedBox(width: 4),
                      Text(widget.origenNombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 16),
                      const Icon(Icons.store, size: 14, color: Color(0xFF9333EA)),
                      const SizedBox(width: 4),
                      Text(widget.destinoNombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain)),
        ],
      ),
    );
  }
}
