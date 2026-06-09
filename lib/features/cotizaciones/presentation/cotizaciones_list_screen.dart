import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/shared/widgets/primary_button.dart';
import 'package:merchanic_repair/features/cotizaciones/providers/cotizacion_provider.dart';
import 'package:merchanic_repair/features/cotizaciones/data/models/cotizacion_model.dart';

class CotizacionesListScreen extends ConsumerWidget {
  const CotizacionesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cotizacionesProvider);

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Mis Cotizaciones'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            tooltip: 'Nueva cotizacion',
            onPressed: () => context.push('/cotizaciones/solicitar'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 60, color: AppColors.error),
                const SizedBox(height: 16),
                const Text('Error al cargar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                const SizedBox(height: 8),
                Text(e.toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: () => ref.read(cotizacionesProvider.notifier).loadCotizaciones(),
                  text: 'Reintentar',
                ),
              ],
            ),
          ),
        ),
        data: (cotizaciones) {
          if (cotizaciones.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.request_quote_outlined, size: 72, color: AppColors.textMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    const Text('No tienes cotizaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                    const SizedBox(height: 8),
                    const Text('Solicita una cotizacion para que los talleres\nte envien sus mejores precios', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      onPressed: () => context.push('/cotizaciones/solicitar'),
                      text: 'Solicitar Cotizacion',
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(cotizacionesProvider.notifier).loadCotizaciones(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: cotizaciones.length,
              itemBuilder: (context, index) => _CotizacionCard(
                item: cotizaciones[index],
                onTap: () => context.push('/cotizaciones/${cotizaciones[index].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CotizacionCard extends StatelessWidget {
  final CotizacionListItemModel item;
  final VoidCallback onTap;

  const _CotizacionCard({required this.item, required this.onTap});

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'pendiente_cotizacion': return AppColors.textMuted;
      case 'cotizando': return AppColors.info;
      case 'cotizado': return AppColors.info;
      case 'taller_seleccionado': return AppColors.warning;
      case 'pago_pendiente': return Colors.orange;
      case 'pagado': case 'completado': return AppColors.success;
      case 'cancelado': case 'rechazado': return AppColors.error;
      case 'negociando': return Colors.purple;
      case 'aceptado': return Colors.teal;
      case 'en_proceso': return AppColors.info;
      default: return AppColors.textMuted;
    }
  }

  IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'pendiente_cotizacion': return Icons.hourglass_empty_outlined;
      case 'cotizando': return Icons.search_outlined;
      case 'cotizado': return Icons.price_check_outlined;
      case 'taller_seleccionado': return Icons.handshake_outlined;
      case 'pago_pendiente': return Icons.payment_outlined;
      case 'pagado': case 'completado': return Icons.check_circle_outline;
      case 'cancelado': return Icons.cancel_outlined;
      case 'rechazado': return Icons.block_outlined;
      case 'negociando': return Icons.chat_outlined;
      case 'aceptado': return Icons.thumb_up_outlined;
      case 'en_proceso': return Icons.build_circle_outlined;
      default: return Icons.hourglass_empty_outlined;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} dias';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _estadoColor(item.estado);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: color.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.vehiculoMarca} ${item.vehiculoModelo}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textMain),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_estadoIcon(item.estado), size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(item.estadoLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.vehiculoMatricula, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  Text(
                    item.descripcionDano.length > 120 ? '${item.descripcionDano.substring(0, 120)}...' : item.descripcionDano,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (item.categoriaIa != null) ...[
                        Icon(Icons.auto_awesome, size: 14, color: AppColors.info.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(item.categoriaIa!, style: TextStyle(fontSize: 11, color: AppColors.info.withValues(alpha: 0.7))),
                        const SizedBox(width: 16),
                      ],
                      Icon(Icons.reply_outlined, size: 14, color: AppColors.textMuted.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text('${item.respuestasCount} respuestas', style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.6))),
                      const Spacer(),
                      if (item.createdAt != null)
                        Text(_formatDate(item.createdAt!), style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.5))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
