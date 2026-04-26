// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result type
// ─────────────────────────────────────────────────────────────────────────────

/// Sealed result type returned by [EventParser.parse].
///
/// Use pattern matching to handle both variants:
/// ```dart
/// switch (result) {
///   case EventParseSuccess(:final event) => handleEvent(event),
///   case EventParseFailure(:final error) => debugPrint('Parse error: $error'),
/// }
/// ```
sealed class EventParseResult {
  const EventParseResult();
}

/// Successful parse result containing the decoded [WebSocketEvent].
final class EventParseSuccess extends EventParseResult {
  const EventParseSuccess(this.event);

  final WebSocketEvent event;
}

/// Failed parse result containing a human-readable [error] description.
final class EventParseFailure extends EventParseResult {
  const EventParseFailure(this.error);

  final String error;
}

// ─────────────────────────────────────────────────────────────────────────────
// Parser
// ─────────────────────────────────────────────────────────────────────────────

/// Stateless utility class for parsing and serialising [WebSocketEvent]s.
///
/// All methods are static so no instance is required.
///
/// ### Parsing pipeline
/// 1. Validate that [rawJson] is valid JSON ([FormatException] guard).
/// 2. Validate that the decoded value is a `Map<String, dynamic>`.
/// 3. Validate required fields: `type` (String), `data` (Map), `timestamp` (String).
/// 4. Validate that `timestamp` is a valid ISO-8601 string ([DateTime.parse] guard).
/// 5. Construct and return a [WebSocketEvent] wrapped in [EventParseSuccess].
///
/// Any validation failure returns an [EventParseFailure] with a descriptive
/// message and logs the error via [debugPrint].
class EventParser {
  // Private constructor – this class is not meant to be instantiated.
  const EventParser._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Parses [rawJson] into a [WebSocketEvent].
  ///
  /// Returns [EventParseSuccess] on success or [EventParseFailure] on any
  /// validation / parsing error.
  static EventParseResult parse(String rawJson) {
    // ── Step 1: JSON syntax validation ──────────────────────────────────────
    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (e) {
      final msg = 'EventParser: invalid JSON – ${e.message}';
      debugPrint(msg);
      return EventParseFailure(msg);
    } catch (e) {
      final msg = 'EventParser: unexpected error decoding JSON – $e';
      debugPrint(msg);
      return EventParseFailure(msg);
    }

    // ── Step 2: Root must be a JSON object ───────────────────────────────────
    if (decoded is! Map) {
      const msg = 'EventParser: root value is not a JSON object';
      debugPrint(msg);
      return const EventParseFailure(msg);
    }

    final Map<String, dynamic> json;
    try {
      json = Map<String, dynamic>.from(decoded);
    } catch (e) {
      final msg =
          'EventParser: could not cast root to Map<String, dynamic> – $e';
      debugPrint(msg);
      return EventParseFailure(msg);
    }

    // ── Step 3: Required field – `type` ──────────────────────────────────────
    final rawType = json['type'];
    if (rawType == null) {
      const msg = "EventParser: missing required field 'type'";
      debugPrint(msg);
      return const EventParseFailure(msg);
    }
    if (rawType is! String) {
      final msg =
          "EventParser: field 'type' must be a String, got ${rawType.runtimeType}";
      debugPrint(msg);
      return EventParseFailure(msg);
    }

    // ── Step 4: Required field – `data` ──────────────────────────────────────
    final rawData = json['data'];
    if (rawData == null) {
      const msg = "EventParser: missing required field 'data'";
      debugPrint(msg);
      return const EventParseFailure(msg);
    }
    if (rawData is! Map) {
      final msg =
          "EventParser: field 'data' must be a JSON object, got ${rawData.runtimeType}";
      debugPrint(msg);
      return EventParseFailure(msg);
    }

    // ── Step 5: Required field – `timestamp` ─────────────────────────────────
    final rawTimestamp = json['timestamp'];
    if (rawTimestamp == null) {
      const msg = "EventParser: missing required field 'timestamp'";
      debugPrint(msg);
      return const EventParseFailure(msg);
    }
    if (rawTimestamp is! String) {
      final msg =
          "EventParser: field 'timestamp' must be a String, got ${rawTimestamp.runtimeType}";
      debugPrint(msg);
      return EventParseFailure(msg);
    }

    // ── Step 6: ISO-8601 timestamp validation ────────────────────────────────
    try {
      DateTime.parse(rawTimestamp);
    } catch (_) {
      final msg =
          "EventParser: 'timestamp' is not a valid ISO-8601 string – '$rawTimestamp'";
      debugPrint(msg);
      return EventParseFailure(msg);
    }

    // ── Step 7: Construct the event ──────────────────────────────────────────
    try {
      final event = WebSocketEvent.fromJson(json);
      return EventParseSuccess(event);
    } catch (e) {
      final msg = 'EventParser: failed to construct WebSocketEvent – $e';
      debugPrint(msg);
      return EventParseFailure(msg);
    }
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  /// Converts [event] back to a JSON string using [WebSocketEvent.toJson].
  ///
  /// Throws only if [jsonEncode] itself throws (e.g. non-serialisable values
  /// inside [event.data]), which should not happen for well-formed events.
  static String serialize(WebSocketEvent event) {
    return jsonEncode(event.toJson());
  }

  // ── Round-trip validation ──────────────────────────────────────────────────

  /// Returns `true` when [event] survives a full serialize → parse round-trip
  /// with the same [WebSocketEvent.type] and [WebSocketEvent.timestamp].
  ///
  /// This is a lightweight sanity check; it does **not** deep-compare [event.data].
  static bool validateRoundTrip(WebSocketEvent event) {
    try {
      final json = serialize(event);
      final result = parse(json);
      if (result is! EventParseSuccess) return false;
      final reparsed = result.event;
      return reparsed.type == event.type &&
          reparsed.timestamp.isAtSameMomentAs(event.timestamp);
    } catch (_) {
      return false;
    }
  }
}
