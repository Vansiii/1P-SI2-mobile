/// Adapter utilities for converting legacy WebSocket event formats to the
/// current envelope format used by [WebSocketService].
///
/// ## Format comparison
///
/// ### Old chat message format (pre-WebSocket-system)
/// ```json
/// {"message": "Hello!", "sender_id": 1}
/// ```
///
/// ### New format
/// ```json
/// {
///   "type": "message_received",
///   "data": {"message": "Hello!", "sender_id": 1},
///   "timestamp": "2024-01-01T12:00:00.000Z"
/// }
/// ```
///
/// ### Old location update format
/// ```json
/// {"lat": 4.6097, "lng": -74.0817}
/// ```
///
/// ### New format
/// ```json
/// {
///   "type": "location_update",
///   "data": {"latitude": 4.6097, "longitude": -74.0817},
///   "timestamp": "2024-01-01T12:00:00.000Z"
/// }
/// ```
class EventAdapter {
  EventAdapter._();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns `true` if [rawData] uses the legacy format (i.e. it does NOT
  /// contain all three required new-format fields: `type`, `data`,
  /// `timestamp`).
  static bool isLegacyFormat(Map<String, dynamic> rawData) {
    return !(rawData.containsKey('type') &&
        rawData.containsKey('data') &&
        rawData.containsKey('timestamp'));
  }

  /// Converts [rawData] to the new event envelope format if it is in a
  /// legacy format.  Returns [rawData] unchanged if it is already in the
  /// new format.
  ///
  /// Supported legacy formats:
  /// - **Old chat message**: `{"message": "...", "sender_id": 1}` →
  ///   `{"type": "message_received", "data": {...}, "timestamp": "..."}`
  /// - **Old location update**: `{"lat": 1.0, "lng": 2.0}` →
  ///   `{"type": "location_update", "data": {"latitude": ..., "longitude": ...}, "timestamp": "..."}`
  static Map<String, dynamic> adaptLegacyEvent(Map<String, dynamic> rawData) {
    if (!isLegacyFormat(rawData)) {
      // Already in new format — return as-is
      return rawData;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    // ── Old chat message ──────────────────────────────────────────────────
    // Detected by the presence of a top-level `message` string field.
    if (rawData.containsKey('message') && rawData['message'] is String) {
      return {
        'type': 'message_received',
        'data': Map<String, dynamic>.from(rawData),
        'timestamp': now,
      };
    }

    // ── Old location update ───────────────────────────────────────────────
    // Detected by the presence of `lat` and `lng` numeric fields.
    if (rawData.containsKey('lat') && rawData.containsKey('lng')) {
      final lat = rawData['lat'];
      final lng = rawData['lng'];

      // Build a new-format data map, renaming lat/lng to latitude/longitude
      final data = <String, dynamic>{
        'latitude': lat,
        'longitude': lng,
        // Preserve any extra fields (e.g. accuracy, technician_id)
        ...Map<String, dynamic>.from(rawData)
          ..remove('lat')
          ..remove('lng'),
      };

      return {'type': 'location_update', 'data': data, 'timestamp': now};
    }

    // ── Unknown legacy format ─────────────────────────────────────────────
    // Wrap the raw data in a generic envelope so it can still be processed.
    return {
      'type': 'unknown',
      'data': Map<String, dynamic>.from(rawData),
      'timestamp': now,
    };
  }
}
