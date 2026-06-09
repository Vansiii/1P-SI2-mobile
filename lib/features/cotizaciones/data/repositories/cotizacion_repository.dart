import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/data/services/api_service.dart';
import 'package:merchanic_repair/features/cotizaciones/data/models/cotizacion_model.dart';

class CotizacionRepository {
  final ApiService _apiService;

  CotizacionRepository(this._apiService);

  static const _base = '${ApiConfig.apiVersion}/cotizaciones';

  Future<List<CotizacionListItemModel>> getCotizaciones({String? estado}) async {
    String path = _base;
    if (estado != null) path += '?estado=$estado';
    final response = await _apiService.getRaw(path);
    final jsonData = response.data as Map<String, dynamic>;
    final data = jsonData['data'] as List<dynamic>;
    return data.map((e) => CotizacionListItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CotizacionModel> getCotizacion(int id) async {
    final response = await _apiService.getRaw('$_base/$id');
    final jsonData = response.data as Map<String, dynamic>;
    return CotizacionModel.fromJson(jsonData['data'] as Map<String, dynamic>);
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
    final body = <String, dynamic>{
      'vehiculo_id': vehiculoId,
      'latitud': latitud,
      'longitud': longitud,
      if (direccionReferencia != null) 'direccion_referencia': direccionReferencia,
      'descripcion_dano': descripcionDano,
      'imagenes_dano': imagenesDano,
      if (audioDiagnostico != null) 'audio_diagnostico': audioDiagnostico,
      'radio_busqueda_km': radioBusquedaKm,
    };
    final response = await _apiService.dio.post('$_base/solicitar', data: body);
    final jsonData = response.data as Map<String, dynamic>;
    return CotizacionModel.fromJson(jsonData['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> seleccionarTaller(int cotizacionId, int respuestaId) async {
    final body = {'cotizacion_respuesta_id': respuestaId};
    final response = await _apiService.dio.post('$_base/$cotizacionId/seleccionar-taller', data: body);
    final jsonData = response.data as Map<String, dynamic>;
    return jsonData['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelarCotizacion(int cotizacionId) async {
    final response = await _apiService.dio.patch('$_base/$cotizacionId/cancelar');
    final jsonData = response.data as Map<String, dynamic>;
    return jsonData['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPreview(int incidenteId, int workshopId) async {
    final response = await _apiService.getRaw(
      '$_base/preview?incidente_id=$incidenteId&workshop_id=$workshopId',
    );
    final jsonData = response.data as Map<String, dynamic>;
    return jsonData['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> solicitarDesdeIncidente({
    required int incidenteId,
    required int workshopId,
    List<int> serviciosSeleccionados = const [],
    String? descripcionAdicional,
  }) async {
    final body = <String, dynamic>{
      'servicios_seleccionados': serviciosSeleccionados,
      if (descripcionAdicional != null) 'descripcion_adicional': descripcionAdicional,
    };
    final response = await _apiService.dio.post(
      '$_base/solicitar-desde-incidente?incidente_id=$incidenteId&workshop_id=$workshopId',
      data: body,
    );
    final jsonData = response.data as Map<String, dynamic>;
    return jsonData['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aceptarCotizacion(int cotizacionId, {int? respuestaId}) async {
    String path = '$_base/$cotizacionId/aceptar';
    if (respuestaId != null) path += '?respuesta_id=$respuestaId';
    final response = await _apiService.dio.post(path);
    final jsonData = response.data as Map<String, dynamic>;
    return jsonData['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> iniciarNegociacion(int cotizacionId) async {
    final response = await _apiService.dio.post('$_base/$cotizacionId/iniciar-negociacion');
    final jsonData = response.data as Map<String, dynamic>;
    return jsonData['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRuta(int cotizacionId) async {
    final response = await _apiService.getRaw('$_base/$cotizacionId/ruta');
    final jsonData = response.data as Map<String, dynamic>;
    return jsonData['data'] as Map<String, dynamic>;
  }
}
