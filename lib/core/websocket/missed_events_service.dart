import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

/// Service responsible for fetching and replaying events that were missed
/// while the WebSocket was disconnected.
///
/// Usage:
/// ```dart
/// final service = MissedEventsService();
/// await service.replayMissedEvents(wsService, token, since);
/// ```
class MissedEventsService {
  bool _isReplayingMissedEvents = false;

  /// Whether a missed-events replay is currently in progress.
  bool get isReplayingMissedEvents => _isReplayingMissedEvents;

  /// Fetches missed events from the backend.
  ///
  /// Calls `GET /api/v1/ws/missed-events?since=<ISO8601>&limit=100`.
  ///
  /// Returns a list of raw event maps sorted by the server in chronological
  /// order.  Returns an empty list on any error.
  Future<List<Map<String, dynamic>>> fetchMissedEvents(
    String token,
    DateTime since,
  ) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final uri = Uri.parse('$baseUrl${ApiConfig.apiVersion}/ws/missed-events')
          .replace(
            queryParameters: {
              'since': since.toUtc().toIso8601String(),
              'limit': '100',
            },
          );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> events;

        if (body is List) {
          events = body;
        } else if (body is Map<String, dynamic> && body['data'] is List) {
          events = body['data'] as List<dynamic>;
        } else {
          debugPrint('[MissedEventsService] Unexpected response format: $body');
          return [];
        }

        return events.cast<Map<String, dynamic>>();
      } else {
        debugPrint(
          '[MissedEventsService] fetchMissedEvents failed: '
          'status=${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('[MissedEventsService] fetchMissedEvents error: $e');
      return [];
    }
  }

  /// Fetches missed events and replays them through [wsService] in
  /// chronological order.
  ///
  /// Sets [isReplayingMissedEvents] to `true` for the duration of the replay
  /// so callers can show a loading indicator.
  Future<void> replayMissedEvents(
    WebSocketService wsService,
    String token,
    DateTime since,
  ) async {
    _isReplayingMissedEvents = true;
    debugPrint(
      '[MissedEventsService] Starting replay of missed events since $since',
    );

    try {
      final events = await fetchMissedEvents(token, since);

      if (events.isEmpty) {
        debugPrint('[MissedEventsService] No missed events to replay.');
        return;
      }

      // Sort chronologically by timestamp field (ascending)
      events.sort((a, b) {
        final tsA = _parseTimestamp(a['timestamp']);
        final tsB = _parseTimestamp(b['timestamp']);
        return tsA.compareTo(tsB);
      });

      debugPrint(
        '[MissedEventsService] Replaying ${events.length} missed events.',
      );

      for (final event in events) {
        wsService.processRawEvent(event);
      }
    } catch (e) {
      debugPrint('[MissedEventsService] replayMissedEvents error: $e');
    } finally {
      _isReplayingMissedEvents = false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime _parseTimestamp(dynamic raw) {
    if (raw is String) {
      try {
        return DateTime.parse(raw).toUtc();
      } catch (_) {
        // fall through
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
