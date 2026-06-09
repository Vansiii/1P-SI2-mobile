import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/repositories/cotizacion_repository.dart';
import '../providers/cotizacion_provider.dart';
import 'cotizacion_ruta_screen.dart';

class CotizacionPreviewScreen extends ConsumerStatefulWidget {
  final int incidenteId;
  final int workshopId;

  const CotizacionPreviewScreen({
    super.key,
    required this.incidenteId,
    required this.workshopId,
  });

  @override
  ConsumerState<CotizacionPreviewScreen> createState() => _CotizacionPreviewScreenState();
}

class _CotizacionPreviewScreenState extends ConsumerState<CotizacionPreviewScreen> {
  Map<String, dynamic>? _preview;
  bool _loading = true;
  String? _error;
  final Set<int> _selectedServices = {};

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final repo = ref.read(cotizacionRepositoryProvider);
      final data = await repo.getPreview(widget.incidenteId, widget.workshopId);
      if (mounted) {
        setState(() {
          _preview = data;
          _loading = false;
          final servicios = (data['servicios_sugeridos'] as List<dynamic>?) ?? [];
          for (final sv in servicios) {
            _selectedServices.add((sv as Map<String, dynamic>)['servicio_id'] as int);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _toggleService(int servicioId) {
    setState(() {
      if (_selectedServices.contains(servicioId)) {
        _selectedServices.remove(servicioId);
      } else {
        _selectedServices.add(servicioId);
      }
    });
  }

  Future<void> _enviarSolicitud() async {
    try {
      setState(() => _loading = true);
      final repo = ref.read(cotizacionRepositoryProvider);
      final result = await repo.solicitarDesdeIncidente(
        incidenteId: widget.incidenteId,
        workshopId: widget.workshopId,
        serviciosSeleccionados: _selectedServices.toList(),
      );
      if (mounted) {
        final cotizacionId = result['id'] as int;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de cotizacion enviada')),
        );
        context.replace('/cotizaciones/$cotizacionId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _mostrarMapa() {
    final p = _preview;
    if (p == null) return;
    final ubicacion = p['incidente_ubicacion'] as Map<String, dynamic>?;
    final tallerUbicacion = p['taller_ubicacion'] as Map<String, dynamic>?;
    if (ubicacion == null) return;

    final tallerLat = tallerUbicacion?['lat'] as double? ?? ubicacion['lat'];
    final tallerLng = tallerUbicacion?['lng'] as double? ?? ubicacion['lng'];
    final tallerNombre = p['taller_nombre'] as String? ?? 'Taller';
    final distancia = p['distancia_km'] as double? ?? 0;
    final duracion = p['duracion_minutos'] as double? ?? 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CotizacionRutaScreen(
          origenLat: ubicacion['lat'] as double,
          origenLng: ubicacion['lng'] as double,
          origenNombre: 'Incidente #${widget.incidenteId}',
          destinoLat: tallerLat,
          destinoLng: tallerLng,
          destinoNombre: tallerNombre,
          distanciaKm: distancia,
          duracionMin: duracion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Cotizacion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Ver ubicacion en mapa',
            onPressed: _mostrarMapa,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildBody() {
    if (_loading && _preview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPreview, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_preview == null) return const SizedBox.shrink();

    final tallerNombre = _preview!['taller_nombre'] as String? ?? 'Taller';
    final vehiculo = '${_preview!['vehiculo_marca']} ${_preview!['vehiculo_modelo']}';
    final matricula = _preview!['vehiculo_matricula'] as String? ?? '';
    final servicios = (_preview!['servicios_sugeridos'] as List<dynamic>?) ?? [];
    final distancia = _preview!['distancia_km'] as double? ?? 0;
    final duracion = _preview!['duracion_minutos'] as double? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.store, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tallerNombre, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Cotizacion directa', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(child: Text(vehiculo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                        ],
                      ),
                      if (matricula.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Matricula: $matricula', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      ],
                      const Divider(height: 24),
                      Row(
                        children: [
                          _infoChip(Icons.straighten, '${distancia.toStringAsFixed(1)} km'),
                          const SizedBox(width: 16),
                          _infoChip(Icons.timer, '${duracion.toStringAsFixed(0)} min'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Servicios sugeridos por IA', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (servicios.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text('No se encontraron servicios coincidentes', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                ...servicios.map((sv) {
                  final s = sv as Map<String, dynamic>;
                  final id = s['servicio_id'] as int;
                  final nombre = s['nombre'] as String? ?? '';
                  final precio = s['precio'] as double? ?? 0;
                  final tiempo = s['tiempo_minutos'] as int? ?? 0;
                  final selected = _selectedServices.contains(id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected ? AppColors.primary.withOpacity(0.04) : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _toggleService(id),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.borderLight,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (_) => _toggleService(id),
                                activeColor: AppColors.primary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text('${precio.toStringAsFixed(2)} BOB', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                                        if (tiempo > 0) ...[
                                          const SizedBox(width: 12),
                                          Icon(Icons.schedule, size: 13, color: AppColors.textMuted.withOpacity(0.6)),
                                          const SizedBox(width: 3),
                                          Text('${tiempo}min', style: TextStyle(fontSize: 12, color: AppColors.textMuted.withOpacity(0.7))),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('IA', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
      ],
    );
  }

  Widget _buildBottomButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _enviarSolicitud,
            icon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: const Text('Enviar solicitud', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
