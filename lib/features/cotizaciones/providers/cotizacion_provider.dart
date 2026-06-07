import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/features/auth/providers/auth_provider.dart';
import 'package:merchanic_repair/features/cotizaciones/data/models/cotizacion_model.dart';
import 'package:merchanic_repair/features/cotizaciones/data/repositories/cotizacion_repository.dart';

final cotizacionRepositoryProvider = Provider<CotizacionRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return CotizacionRepository(apiService);
});

final cotizacionesProvider = StateNotifierProvider<CotizacionesNotifier, AsyncValue<List<CotizacionListItemModel>>>((ref) {
  return CotizacionesNotifier(ref.read(cotizacionRepositoryProvider));
});

class CotizacionesNotifier extends StateNotifier<AsyncValue<List<CotizacionListItemModel>>> {
  final CotizacionRepository _repository;

  CotizacionesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCotizaciones();
  }

  Future<void> loadCotizaciones({String? estado}) async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getCotizaciones(estado: estado);
      state = AsyncValue.data(items);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<CotizacionModel> solicitarCotizacion({
    required int vehiculoId,
    required double latitud,
    required double longitud,
    String? direccionReferencia,
    required String descripcionDano,
    List<String> imagenesDano = const [],
    String? audioDiagnostico,
    double radioBusquedaKm = 15.0,
  }) async {
    return _repository.solicitarCotizacion(
      vehiculoId: vehiculoId,
      latitud: latitud,
      longitud: longitud,
      direccionReferencia: direccionReferencia,
      descripcionDano: descripcionDano,
      imagenesDano: imagenesDano,
      audioDiagnostico: audioDiagnostico,
      radioBusquedaKm: radioBusquedaKm,
    );
  }

  Future<Map<String, dynamic>> seleccionarTaller(int cotizacionId, int respuestaId) async {
    return _repository.seleccionarTaller(cotizacionId, respuestaId);
  }

  Future<Map<String, dynamic>> cancelarCotizacion(int cotizacionId) async {
    return _repository.cancelarCotizacion(cotizacionId);
  }
}
