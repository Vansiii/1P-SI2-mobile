import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:merchanic_repair/core/config/api_config.dart';

/// Service for managing service ratings
class RatingService {
  /// Create a rating for an incident
  Future<Map<String, dynamic>> createRating({
    required int incidentId,
    required String token,
    required int rating,
    String? comment,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/ratings/incidents/$incidentId',
    );

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'rating': rating, 'comment': comment}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create rating');
    }
  }

  /// Get rating for an incident
  Future<Map<String, dynamic>?> getIncidentRating({
    required int incidentId,
    required String token,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/ratings/incidents/$incidentId',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to get rating');
    }
  }

  /// Check if incident can be rated
  bool canRateIncident(String incidentStatus) {
    return incidentStatus == 'resuelto';
  }
}
