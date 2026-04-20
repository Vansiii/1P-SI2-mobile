import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:merchanic_repair/data/models/cancellation_request.dart';
import 'package:merchanic_repair/core/config/app_config.dart';

/// Servicio para gestión de cancelaciones mutuas de incidentes
class CancellationService {
  final http.Client _client;
  final String _baseUrl;

  CancellationService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiUrl;

  /// Solicitar cancelación mutua de un incidente
  ///
  /// [incidentId] ID del incidente
  /// [reason] Motivo de la cancelación (mínimo 10 caracteres)
  /// [token] Token de autenticación JWT
  ///
  /// Returns: CancellationRequest creado
  ///
  /// Throws:
  /// - [Exception] si la solicitud falla
  /// - [FormatException] si la respuesta no es válida
  Future<CancellationRequest> requestCancellation({
    required int incidentId,
    required String reason,
    required String token,
  }) async {
    if (reason.trim().length < 10) {
      throw ArgumentError('El motivo debe tener al menos 10 caracteres');
    }

    final url = Uri.parse(
      '$_baseUrl/cancellation/incidents/$incidentId/request',
    );

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason.trim()}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CancellationRequest.fromJson(data);
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Error de validación');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permiso para solicitar cancelación');
      } else if (response.statusCode == 404) {
        throw Exception('Incidente no encontrado');
      } else {
        throw Exception(
          'Error al solicitar cancelación: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error de conexión: $e');
    }
  }

  /// Responder a una solicitud de cancelación
  ///
  /// [requestId] ID de la solicitud de cancelación
  /// [accept] true para aceptar, false para rechazar
  /// [responseMessage] Mensaje opcional de respuesta
  /// [token] Token de autenticación JWT
  ///
  /// Returns: CancellationRequest actualizado
  ///
  /// Throws:
  /// - [Exception] si la respuesta falla
  Future<CancellationRequest> respondToCancellation({
    required int requestId,
    required bool accept,
    String? responseMessage,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/cancellation/requests/$requestId/respond');

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'accept': accept,
          'response_message': responseMessage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CancellationRequest.fromJson(data);
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Error de validación');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permiso para responder a esta solicitud');
      } else if (response.statusCode == 404) {
        throw Exception('Solicitud de cancelación no encontrada');
      } else {
        throw Exception(
          'Error al responder cancelación: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener solicitud de cancelación pendiente para un incidente
  ///
  /// [incidentId] ID del incidente
  /// [token] Token de autenticación JWT
  ///
  /// Returns: CancellationRequest pendiente o null si no existe
  ///
  /// Throws:
  /// - [Exception] si la solicitud falla
  Future<CancellationRequest?> getPendingCancellation({
    required int incidentId,
    required String token,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/cancellation/incidents/$incidentId/pending',
    );

    try {
      final response = await _client.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) return null;
        return CancellationRequest.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permiso para ver esta solicitud');
      } else {
        throw Exception(
          'Error al obtener solicitud pendiente: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error de conexión: $e');
    }
  }

  /// Cerrar el cliente HTTP
  void dispose() {
    _client.close();
  }
}
