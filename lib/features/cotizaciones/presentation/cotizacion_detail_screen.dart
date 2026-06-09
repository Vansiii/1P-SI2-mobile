import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/shared/widgets/primary_button.dart';
import 'package:merchanic_repair/shared/utils/snackbar_utils.dart';
import 'package:merchanic_repair/features/cotizaciones/providers/cotizacion_provider.dart';
import 'package:merchanic_repair/features/cotizaciones/data/models/cotizacion_model.dart';
import 'cotizacion_mapa_screen.dart';

class CotizacionDetailScreen extends ConsumerStatefulWidget {
  final int cotizacionId;
  const CotizacionDetailScreen({super.key, required this.cotizacionId});

  @override
  ConsumerState<CotizacionDetailScreen> createState() => _CotizacionDetailScreenState();
}

class _CotizacionDetailScreenState extends ConsumerState<CotizacionDetailScreen> {
  CotizacionModel? _cotizacion;
  bool _loading = true;
  String? _error;
  bool _seleccionando = false;
  int? _incidenteId;
  int? _respuestaSeleccionadaId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(cotizacionRepositoryProvider);
      final c = await repo.getCotizacion(widget.cotizacionId);
      if (!mounted) return;
      setState(() { _cotizacion = c; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _seleccionarTaller(int respuestaId) async {
    setState(() => _seleccionando = true);
    try {
      final notifier = ref.read(cotizacionesProvider.notifier);
      final result = await notifier.seleccionarTaller(widget.cotizacionId, respuestaId);
      if (!mounted) return;
      final iid = result['incidente_id'] as int?;
      if (iid != null) {
        _incidenteId = iid;
        SnackBarUtils.showSuccess(context, 'Taller seleccionado. Incidente #$iid creado.');
      } else {
        SnackBarUtils.showSuccess(context, 'Taller seleccionado');
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _seleccionando = false);
    }
  }

  Future<void> _cancelar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cotizacion'),
        content: const Text('Estas seguro de cancelar esta cotizacion?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Si, cancelar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final notifier = ref.read(cotizacionesProvider.notifier);
      await notifier.cancelarCotizacion(widget.cotizacionId);
      if (!mounted) return;
      SnackBarUtils.showInfo(context, 'Cotizacion cancelada');
      _load();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Error: $e');
    }
  }

  Future<void> _aceptar() async {
    final selId = _respuestaSeleccionadaId;
    if (selId == null) {
      SnackBarUtils.showInfo(context, 'Selecciona una oferta antes de aceptar');
      return;
    }
    try {
      final repo = ref.read(cotizacionRepositoryProvider);
      await repo.aceptarCotizacion(widget.cotizacionId, respuestaId: selId);
      if (!mounted) return;
      _respuestaSeleccionadaId = null;
      SnackBarUtils.showSuccess(context, 'Cotizacion aceptada');
      _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      SnackBarUtils.showError(context, msg);
    }
  }

  Future<void> _iniciarNegociacion() async {
    try {
      final repo = ref.read(cotizacionRepositoryProvider);
      await repo.iniciarNegociacion(widget.cotizacionId);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Solicitud enviada. El taller podra enviar una contraoferta.');
      _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      SnackBarUtils.showError(context, msg);
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'cotizado': return AppColors.info;
      case 'taller_seleccionado': return AppColors.warning;
      case 'pagado': case 'completado': return AppColors.success;
      case 'cancelado': case 'rechazado': return AppColors.error;
      case 'negociando': return Colors.purple;
      case 'aceptado': return Colors.teal;
      default: return AppColors.textMuted;
    }
  }

  IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'cotizado': return Icons.price_check_outlined;
      case 'taller_seleccionado': return Icons.handshake_outlined;
      case 'pagado': case 'completado': return Icons.check_circle_outline;
      case 'cancelado': return Icons.cancel_outlined;
      case 'rechazado': return Icons.block_outlined;
      case 'negociando': return Icons.chat_outlined;
      case 'aceptado': return Icons.thumb_up_outlined;
      default: return Icons.hourglass_empty_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Error al cargar cotizacion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.textMuted, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            PrimaryButton(onPressed: _load, text: 'Reintentar'),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final c = _cotizacion!;
    final color = _estadoColor(c.estado);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          backgroundColor: color,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.map, color: Colors.white),
              tooltip: 'Ver ruta en mapa',
              onPressed: () {
                final c = _cotizacion;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CotizacionMapaScreen(
                      cotizacionId: widget.cotizacionId,
                      origenLat: c?.latitud,
                      origenLng: c?.longitud,
                      origenNombre: c != null ? '${c.vehiculoMarca} ${c.vehiculoModelo}' : null,
                    ),
                  ),
                );
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.75)],
                ),
              ),
            ),
            titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
            title: Row(
              children: [
                Icon(_estadoIcon(c.estado), color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Flexible(child: Text(c.estadoLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildIncidenteBanner(),
              if (_incidenteId != null) const SizedBox(height: 16),
              _buildSection(
                icon: Icons.directions_car_outlined,
                title: '${c.vehiculoMarca} ${c.vehiculoModelo}',
                subtitle: c.vehiculoMatricula,
              ),
              const SizedBox(height: 12),
              _buildSection(
                icon: Icons.description_outlined,
                title: 'Descripcion del dano',
                child: Text(c.descripcionDano, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
              ),
              if (c.categoriaIa != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppColors.info.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(c.categoriaIa!, style: TextStyle(fontSize: 13, color: AppColors.info.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
                    if (c.prioridadIa != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.prioridadIa == 'alta' ? AppColors.error.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(c.prioridadIa!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.prioridadIa == 'alta' ? AppColors.error : AppColors.warning)),
                      ),
                    ],
                  ],
                ),
              ],
              if (c.resumenIa != null) ...[
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.psychology_outlined,
                  title: 'Analisis IA',
                  child: Text(c.resumenIa!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
                ),
              ],
              if (c.respuestas.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.reply_outlined, size: 20, color: AppColors.textMain.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Text('Cotizaciones recibidas (${c.respuestas.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textMain)),
                  ],
                ),
                const SizedBox(height: 12),
                ...c.respuestas.map((r) => _buildRespuestaCard(c, r)),
                if (_respuestaSeleccionadaId != null && c.version != 'v2') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      onPressed: _seleccionando ? null : () => _seleccionarTaller(_respuestaSeleccionadaId!),
                      text: _seleccionando ? 'Seleccionando...' : 'Seleccionar taller',
                    ),
                  ),
                ],
              ],
              if (c.version == 'v2') ...[
                const SizedBox(height: 20),
                _buildV2Buttons(c),
              ],
              if (c.estado != 'cancelado' && c.estado != 'pagado' && c.estado != 'completado') ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _cancelar,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancelar cotizacion'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildIncidenteBanner() {
    final c = _cotizacion;
    final incidenteId = _incidenteId ?? c?.incidenteId;
    if (incidenteId == null) return const SizedBox.shrink();
    final esV2 = c?.version == 'v2';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(esV2 ? Icons.link : Icons.check_circle, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Text(esV2 ? 'Incidente vinculado' : 'Incidente creado', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.info, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text(esV2 ? 'Cotizacion directa asociada al incidente #$incidenteId' : 'Se ha creado el incidente #$incidenteId para seguimiento del servicio.', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/incidents/$incidenteId'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('Ver incidente #$incidenteId'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.info,
                side: const BorderSide(color: AppColors.info),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, String? subtitle, Widget? child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMain.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textMain)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
          if (child != null) ...[
            const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildRespuestaCard(CotizacionModel c, CotizacionRespuestaModel r) {
    final puedeSeleccionar = c.estado == 'cotizado' && r.estado == 'pendiente';
    final estaSeleccionada = _respuestaSeleccionadaId == r.id;
    final color = estaSeleccionada ? AppColors.primary : (puedeSeleccionar ? AppColors.primary.withValues(alpha: 0.5) : AppColors.borderLight);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        elevation: estaSeleccionada ? 3 : (puedeSeleccionar ? 1 : 0),
        shadowColor: AppColors.primary.withValues(alpha: 0.15),
        child: InkWell(
          onTap: puedeSeleccionar ? () => setState(() => _respuestaSeleccionadaId = estaSeleccionada ? null : r.id) : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: estaSeleccionada ? 2.5 : (puedeSeleccionar ? 1.5 : 1)),
              boxShadow: estaSeleccionada ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))] : null,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (estaSeleccionada) ...[
                      const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                    ] else if (puedeSeleccionar) ...[
                      Icon(Icons.radio_button_unchecked, size: 20, color: AppColors.textMuted.withValues(alpha: 0.4)),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.store_outlined, size: 18, color: color.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.workshopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textMain))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${r.costoTotal.toStringAsFixed(2)} BOB', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: AppColors.textMuted.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(r.tiempoEstimadoTexto, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
                if (r.notas != null && r.notas!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                    child: Text(r.notas!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                ],
                if (r.validaHasta != null) ...[
                  const SizedBox(height: 4),
                  Text('Valido hasta ${r.validaHasta!.day}/${r.validaHasta!.month} ${r.validaHasta!.hour}:${r.validaHasta!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.5))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildV2Buttons(CotizacionModel c) {
    final bool puedeAceptar = c.estado == 'cotizado' || c.estado == 'negociando';
    final bool puedeNegociar = c.estado == 'cotizado' && c.chatSalaId == null;
    final bool enNegociacion = c.estado == 'negociando';

    if (!puedeAceptar && !puedeNegociar && !enNegociacion) return const SizedBox.shrink();

    final sel = _respuestaSeleccionadaId != null
        ? c.respuestas.where((r) => r.id == _respuestaSeleccionadaId).firstOrNull
        : null;
    final selPrecio = sel?.costoTotal ?? c.costoTotalEstimado;
    final aceptarLabel = selPrecio != null
        ? 'Aceptar (${selPrecio.toStringAsFixed(2)} BOB)'
        : 'Aceptar cotizacion';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.preview_outlined, size: 20, color: AppColors.textMain.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            const Text('Acciones', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textMain)),
          ],
        ),
        const SizedBox(height: 12),
        if (puedeAceptar && !enNegociacion) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _aceptar,
              icon: const Icon(Icons.thumb_up_outlined),
              label: Text(aceptarLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (puedeNegociar && !enNegociacion) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _iniciarNegociacion,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Solicitar contraoferta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        if (enNegociacion) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.purple, size: 20),
                    SizedBox(width: 8),
                    Text('En negociacion', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.purple, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Esperando contraoferta del taller.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _aceptar,
                    icon: const Icon(Icons.thumb_up_outlined),
                    label: Text(aceptarLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
