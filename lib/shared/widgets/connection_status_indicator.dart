import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:merchanic_repair/core/websocket/connection_status.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConnectionStatusIndicator
// ─────────────────────────────────────────────────────────────────────────────

/// A small colored-dot widget that reflects the current WebSocket connection
/// state in real time.
///
/// - 🟢 Green dot  → [ConnectionStatus.connected]
/// - 🟡 Pulsing dot → [ConnectionStatus.connecting] / [ConnectionStatus.reconnecting]
/// - 🔴 Red dot + "Sin conexión" label → [ConnectionStatus.disconnected]
///
/// Tapping the widget opens a dialog with connection details and a
/// "Reintentar" button.
class ConnectionStatusIndicator extends ConsumerStatefulWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  ConsumerState<ConnectionStatusIndicator> createState() =>
      _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState
    extends ConsumerState<ConnectionStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  DateTime? _lastConnectedAt;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _colorFor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
        return Colors.red;
    }
  }

  String _labelFor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Conectado';
      case ConnectionStatus.connecting:
        return 'Conectando…';
      case ConnectionStatus.reconnecting:
        return 'Reconectando…';
      case ConnectionStatus.disconnected:
        return 'Sin conexión';
    }
  }

  void _showDetailsDialog(BuildContext context, WebSocketService wsService) {
    final lastConnected = _lastConnectedAt;
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estado de conexión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _colorFor(_status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_labelFor(_status)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              lastConnected != null
                  ? 'Última conexión: ${formatter.format(lastConnected.toLocal())}'
                  : 'Sin conexión previa registrada',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              wsService.retryConnection();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wsService = ref.watch(webSocketServiceProvider);

    return StreamBuilder<ConnectionStatus>(
      stream: wsService.connectionStatus,
      initialData: ConnectionStatus.disconnected,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectionStatus.disconnected;

        // Track last successful connection time
        if (status == ConnectionStatus.connected &&
            _status != ConnectionStatus.connected) {
          _lastConnectedAt = DateTime.now();
        }
        _status = status;

        final isPulsing =
            status == ConnectionStatus.connecting ||
            status == ConnectionStatus.reconnecting;

        final dot = AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, __) => Opacity(
            opacity: isPulsing ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _colorFor(status),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

        return GestureDetector(
          onTap: () => _showDetailsDialog(context, wsService),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot,
              if (status == ConnectionStatus.disconnected) ...[
                const SizedBox(width: 4),
                Text(
                  'Sin conexión',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ConnectionStatusBanner
// ─────────────────────────────────────────────────────────────────────────────

/// A red banner shown at the top of a screen when the WebSocket is disconnected.
///
/// Returns [SizedBox.shrink] when connected so it takes no space.
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsService = ref.watch(webSocketServiceProvider);

    return StreamBuilder<ConnectionStatus>(
      stream: wsService.connectionStatus,
      initialData: ConnectionStatus.disconnected,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectionStatus.disconnected;

        if (status == ConnectionStatus.connected) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: Colors.red.shade700,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: const Text(
            'Sin conexión en tiempo real',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WebSocketSnackbarListener
// ─────────────────────────────────────────────────────────────────────────────

/// A widget that listens to WebSocket connection status changes and shows
/// SnackBars when the connection is lost or restored.
///
/// Wrap this around (or inside) your scaffold body. It renders its [child]
/// unchanged and only produces side-effects (SnackBars).
class WebSocketSnackbarListener extends ConsumerStatefulWidget {
  const WebSocketSnackbarListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WebSocketSnackbarListener> createState() =>
      _WebSocketSnackbarListenerState();
}

class _WebSocketSnackbarListenerState
    extends ConsumerState<WebSocketSnackbarListener> {
  StreamSubscription<ConnectionStatus>? _subscription;
  ConnectionStatus? _previousStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    final wsService = ref.read(webSocketServiceProvider);

    _subscription = wsService.connectionStatus.listen((status) {
      if (!mounted) return;

      final previous = _previousStatus;
      _previousStatus = status;

      // Connection lost
      if (status == ConnectionStatus.disconnected &&
          previous == ConnectionStatus.connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conexión perdida'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Connection restored
      if (status == ConnectionStatus.connected &&
          previous != null &&
          previous != ConnectionStatus.connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conexión restaurada'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
