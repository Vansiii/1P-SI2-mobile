import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/map/cached_osm_tile_layer.dart';
import '../../../widgets/map/smart_map_marker.dart';
import '../data/repositories/cotizacion_repository.dart';
import '../providers/cotizacion_provider.dart';

class CotizacionMapaScreen extends ConsumerStatefulWidget {
  final int cotizacionId;
  final double? origenLat;
  final double? origenLng;
  final double? destinoLat;
  final double? destinoLng;
  final String? origenNombre;
  final String? destinoNombre;
  final double? distancia;
  final double? duracion;

  const CotizacionMapaScreen({
    super.key,
    required this.cotizacionId,
    this.origenLat,
    this.origenLng,
    this.destinoLat,
    this.destinoLng,
    this.origenNombre,
    this.destinoNombre,
    this.distancia,
    this.duracion,
  });

  @override
  ConsumerState<CotizacionMapaScreen> createState() => _CotizacionMapaScreenState();
}

class _CotizacionMapaScreenState extends ConsumerState<CotizacionMapaScreen> {
  List<LatLng> _polylinePoints = [];
  LatLng? _origen;
  LatLng? _destino;
  double _distancia = 0;
  double _duracion = 0;
  String _origenNombre = '';
  String _destinoNombre = '';
  bool _loading = true;
  String? _error;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initFromParams();
    _loadRuta();
  }

  void _initFromParams() {
    if (widget.origenLat != null && widget.origenLng != null) {
      _origen = LatLng(widget.origenLat!, widget.origenLng!);
      _origenNombre = widget.origenNombre ?? 'Incidente';
    }
    if (widget.destinoLat != null && widget.destinoLng != null) {
      _destino = LatLng(widget.destinoLat!, widget.destinoLng!);
      _destinoNombre = widget.destinoNombre ?? 'Taller';
    }
    _distancia = widget.distancia ?? 0;
    _duracion = widget.duracion ?? 0;
    if (_origen != null && _destino != null) {
      _loading = false;
      _fitMap();
    }
  }

  Future<void> _loadRuta() async {
    try {
      final repo = ref.read(cotizacionRepositoryProvider);
      final data = await repo.getRuta(widget.cotizacionId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        final origen = data['origen'] as Map<String, dynamic>;
        final destino = data['destino'] as Map<String, dynamic>;
        final ruta = data['ruta'] as Map<String, dynamic>;

        _origen = LatLng(origen['lat'] as double, origen['lng'] as double);
        _destino = LatLng(destino['lat'] as double, destino['lng'] as double);
        _origenNombre = origen['nombre'] as String? ?? _origenNombre;
        _destinoNombre = destino['nombre'] as String? ?? _destinoNombre;
        _distancia = (ruta['distancia_km'] as num?)?.toDouble() ?? _distancia;
        _duracion = (ruta['duracion_minutos'] as num?)?.toDouble() ?? _duracion;

        final polyline = ruta['polyline'];
        if (polyline is List && polyline.isNotEmpty) {
          _polylinePoints = polyline
              .map((p) => LatLng(
                    (p as Map<String, dynamic>)['lat'] as double,
                    p['lng'] as double,
                  ))
              .toList();
        }
      });
      _fitMap();
    } catch (e) {
      if (!mounted) return;
      if (_origen != null) {
        // Origin from params, show map even if route API fails
        setState(() { _loading = false; });
        _fitMap();
      } else {
        setState(() { _loading = false; _error = 'Error al cargar ruta: $e'; });
      }
    }
  }

  void _fitMap() {
    if (!mounted) return;
    try {
      if (_polylinePoints.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(_polylinePoints);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
      } else if (_origen != null && _destino != null) {
        final bounds = LatLngBounds.fromPoints([_origen!, _destino!]);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
      } else if (_origen != null) {
        _mapController.move(_origen!, 14);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(title: const Text('Ruta de Cotizacion')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final origen = _origen ?? const LatLng(-17.3935, -66.1570);

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: origen, initialZoom: 14),
            children: [
              const CachedOsmTileLayer(),
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _polylinePoints, color: const Color(0xFF4285F4), strokeWidth: 4),
                  ],
                )
              else if (_origen != null && _destino != null)
                PolylineLayer(
                  polylines: [
                    Polyline(points: [_origen!, _destino!], color: const Color(0xFFF59E0B), strokeWidth: 3),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_origen != null)
                    Marker(point: _origen!, width: 40, height: 52, alignment: Alignment.topCenter,
                      child: SmartMapMarker(role: MarkerRole.client, isSelected: false)),
                  if (_destino != null)
                    Marker(point: _destino!, width: 40, height: 52, alignment: Alignment.topCenter,
                      child: SmartMapMarker(role: MarkerRole.workshop, isSelected: false)),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Container(color: Colors.orange.shade50, padding: const EdgeInsets.all(8),
            child: Text('⚠️ $_error', style: const TextStyle(fontSize: 12, color: Colors.orange), textAlign: TextAlign.center)),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.straighten, size: 20), const SizedBox(width: 8),
                  Text('Distancia: ${_distancia.toStringAsFixed(1)} km', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 24),
                  const Icon(Icons.timer, size: 20), const SizedBox(width: 8),
                  Text('ETA: ${_duracion.toStringAsFixed(0)} min', style: Theme.of(context).textTheme.titleSmall),
                ]),
                const SizedBox(height: 8),
                Text('🏪 $_destinoNombre', style: Theme.of(context).textTheme.bodyMedium),
                if (_origenNombre.isNotEmpty) Text('📍 $_origenNombre', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
