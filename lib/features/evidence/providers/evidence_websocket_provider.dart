import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single piece of evidence attached to an incident.
///
/// [type] is one of: `'image'`, `'audio'`, `'file'`.
class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.incidentId,
    required this.type,
    required this.fileUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    required this.uploadedBy,
    this.uploadedAt,
  });

  final int id;
  final int incidentId;
  final String type; // 'image', 'audio', 'file'
  final String fileUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final int uploadedBy;
  final DateTime? uploadedAt;

  EvidenceItem copyWith({
    int? id,
    int? incidentId,
    String? type,
    String? fileUrl,
    Object? thumbnailUrl = _sentinel,
    Object? durationSeconds = _sentinel,
    int? uploadedBy,
    Object? uploadedAt = _sentinel,
  }) {
    return EvidenceItem(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl == _sentinel
          ? this.thumbnailUrl
          : thumbnailUrl as String?,
      durationSeconds: durationSeconds == _sentinel
          ? this.durationSeconds
          : durationSeconds as int?,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt == _sentinel
          ? this.uploadedAt
          : uploadedAt as DateTime?,
    );
  }
}

const Object _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive map of evidence lists keyed by incident ID, kept
/// up-to-date by incoming WebSocket events.
///
/// Requirements: 7.1–7.8
final evidenceWebSocketProvider =
    StateNotifierProvider<
      EvidenceWebSocketNotifier,
      Map<int, List<EvidenceItem>>
    >((ref) {
      final wsService = ref.read(webSocketServiceProvider);
      return EvidenceWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a map of `incidentId → List<EvidenceItem>` and updates it in
/// response to evidence-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class EvidenceWebSocketNotifier
    extends StateNotifier<Map<int, List<EvidenceItem>>> {
  EvidenceWebSocketNotifier(this._wsService) : super({}) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Seeds evidence for a specific incident loaded via HTTP.
  void seedEvidence(int incidentId, List<EvidenceItem> items) {
    state = {...state, incidentId: List.unmodifiable(items)};
  }

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.evidenceUploaded)
          .listen(_onEvidenceUploaded),
      _wsService
          .getEventStream(EventType.evidenceImageUploaded)
          .listen(_onEvidenceImageUploaded),
      _wsService
          .getEventStream(EventType.evidenceAudioUploaded)
          .listen(_onEvidenceAudioUploaded),
      _wsService
          .getEventStream(EventType.evidenceDeleted)
          .listen(_onEvidenceDeleted),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `evidence_uploaded` → append a generic file evidence item.
  ///
  /// Requirement 7.1
  void _onEvidenceUploaded(WebSocketEvent event) {
    try {
      final payload = EvidenceUploadedPayload.fromJson(event.data);
      final item = EvidenceItem(
        id: payload.evidenceId,
        incidentId: payload.incidentId,
        type: 'file',
        fileUrl: payload.fileUrl ?? '',
        uploadedBy: payload.uploadedBy,
        uploadedAt: payload.uploadedAt,
      );
      _appendItem(payload.incidentId, item);
      debugPrint(
        '[EvidenceWebSocketNotifier] evidence_uploaded: '
        'id=${payload.evidenceId} incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[EvidenceWebSocketNotifier] Error handling evidence_uploaded: $e',
      );
    }
  }

  /// `evidence_image_uploaded` → append an image evidence item.
  ///
  /// Requirement 7.2
  void _onEvidenceImageUploaded(WebSocketEvent event) {
    try {
      final payload = EvidenceImageUploadedPayload.fromJson(event.data);
      final uploadedBy = event.data['uploaded_by'] as int? ?? 0;
      final item = EvidenceItem(
        id: payload.evidenceId,
        incidentId: payload.incidentId,
        type: 'image',
        fileUrl: payload.imageUrl,
        thumbnailUrl: payload.thumbnailUrl,
        uploadedBy: uploadedBy,
        uploadedAt: payload.uploadedAt,
      );
      _appendItem(payload.incidentId, item);
      debugPrint(
        '[EvidenceWebSocketNotifier] evidence_image_uploaded: '
        'id=${payload.evidenceId} incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[EvidenceWebSocketNotifier] Error handling evidence_image_uploaded: $e',
      );
    }
  }

  /// `evidence_audio_uploaded` → append an audio evidence item.
  ///
  /// Requirement 7.3
  void _onEvidenceAudioUploaded(WebSocketEvent event) {
    try {
      final payload = EvidenceAudioUploadedPayload.fromJson(event.data);
      final uploadedBy = event.data['uploaded_by'] as int? ?? 0;
      final item = EvidenceItem(
        id: payload.evidenceId,
        incidentId: payload.incidentId,
        type: 'audio',
        fileUrl: payload.audioUrl,
        durationSeconds: payload.durationSeconds,
        uploadedBy: uploadedBy,
        uploadedAt: payload.uploadedAt,
      );
      _appendItem(payload.incidentId, item);
      debugPrint(
        '[EvidenceWebSocketNotifier] evidence_audio_uploaded: '
        'id=${payload.evidenceId} incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[EvidenceWebSocketNotifier] Error handling evidence_audio_uploaded: $e',
      );
    }
  }

  /// `evidence_deleted` → remove the evidence item from the incident's list.
  ///
  /// Requirement 7.4
  void _onEvidenceDeleted(WebSocketEvent event) {
    try {
      final payload = EvidenceDeletedPayload.fromJson(event.data);
      final current = state[payload.incidentId] ?? [];
      final updated = current
          .where((item) => item.id != payload.evidenceId)
          .toList();
      state = {...state, payload.incidentId: updated};
      debugPrint(
        '[EvidenceWebSocketNotifier] evidence_deleted: '
        'id=${payload.evidenceId} incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[EvidenceWebSocketNotifier] Error handling evidence_deleted: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _appendItem(int incidentId, EvidenceItem item) {
    final current = state[incidentId] ?? [];
    state = {
      ...state,
      incidentId: [...current, item],
    };
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
