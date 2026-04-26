// Connection status indicator widget.
//
// Shows a small colored dot (or banner) reflecting the current WebSocket
// connection state.  Can be embedded in AppBars, navigation bars, or any
// widget tree.
//
// Requirements: 2.6, 2.15

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/websocket/connection_status.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Exposes the [ConnectionStatus] stream as a Riverpod [StreamProvider].
///
/// Widgets that watch this provider rebuild automatically whenever the
/// connection state changes (Requirement 2.6).
final connectionStatusStreamProvider = StreamProvider<ConnectionStatus>((ref) {
  return WebSocketService(StorageService()).connectionStatus;
});

// ── ConnectionStatusIndicator ─────────────────────────────────────────────────

/// A small colored dot that reflects the current WebSocket connection status.
///
/// Color mapping:
/// - 🟢 Green  → [ConnectionStatus.connected]
/// - 🟡 Yellow → [ConnectionStatus.reconnecting] / [ConnectionStatus.connecting]
/// - 🔴 Red    → [ConnectionStatus.disconnected]
///
/// Usage in an AppBar:
/// ```dart
/// AppBar(
///   title: const Text('Incidents'),
///   actions: const [
///     Padding(
///       padding: EdgeInsets.only(right: 12),
///       child: ConnectionStatusIndicator(),
///     ),
///   ],
/// )
/// ```
class ConnectionStatusIndicator extends ConsumerWidget {
  const ConnectionStatusIndicator({
    super.key,
    this.size = 10.0,
    this.showLabel = false,
  });

  /// Diameter of the status dot in logical pixels.
  final double size;

  /// When `true`, a short text label is shown next to the dot.
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectionStatusStreamProvider);

    final status = statusAsync.when(
      data: (s) => s,
      loading: () => ConnectionStatus.connecting,
      error: (_, __) => ConnectionStatus.disconnected,
    );

    final color = _colorFor(status);
    final label = _labelFor(status);

    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );

    if (!showLabel) return dot;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static Color _colorFor(ConnectionStatus status) => switch (status) {
    ConnectionStatus.connected => const Color(0xFF4CAF50),
    ConnectionStatus.connecting ||
    ConnectionStatus.reconnecting => const Color(0xFFFFC107),
    ConnectionStatus.disconnected => const Color(0xFFF44336),
  };

  static String _labelFor(ConnectionStatus status) => switch (status) {
    ConnectionStatus.connected => 'Conectado',
    ConnectionStatus.connecting => 'Conectando…',
    ConnectionStatus.reconnecting => 'Reconectando…',
    ConnectionStatus.disconnected => 'Desconectado',
  };
}

// ── ConnectionStatusBanner ────────────────────────────────────────────────────

/// A slim banner shown at the top of a screen when the WebSocket is not
/// connected.  Disappears automatically once the connection is restored.
///
/// Usage:
/// ```dart
/// Column(
///   children: [
///     const ConnectionStatusBanner(),
///     Expanded(child: myContent),
///   ],
/// )
/// ```
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectionStatusStreamProvider);

    final status = statusAsync.when(
      data: (s) => s,
      loading: () => ConnectionStatus.connecting,
      error: (_, __) => ConnectionStatus.disconnected,
    );

    if (status == ConnectionStatus.connected) return const SizedBox.shrink();

    final color = _bannerColorFor(status);
    final message = _messageFor(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: color,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Color _bannerColorFor(ConnectionStatus status) => switch (status) {
    ConnectionStatus.connecting ||
    ConnectionStatus.reconnecting => const Color(0xFFFFA000),
    ConnectionStatus.disconnected => const Color(0xFFD32F2F),
    ConnectionStatus.connected => Colors.transparent,
  };

  static String _messageFor(ConnectionStatus status) => switch (status) {
    ConnectionStatus.connecting => 'Estableciendo conexión en tiempo real…',
    ConnectionStatus.reconnecting => 'Reconectando…',
    ConnectionStatus.disconnected => 'Sin conexión en tiempo real',
    ConnectionStatus.connected => '',
  };
}
