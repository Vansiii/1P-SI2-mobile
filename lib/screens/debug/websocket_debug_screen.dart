import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/connection_status.dart';
import 'package:merchanic_repair/core/websocket/websocket_logger.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

/// Debug screen for WebSocket diagnostics.
///
/// Only accessible in debug mode ([kDebugMode]).  Shows connection status,
/// event counts, average processing latencies, and recent errors.
///
/// Usage:
/// ```dart
/// if (kDebugMode) {
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => const WebSocketDebugScreen(),
///   ));
/// }
/// ```
class WebSocketDebugScreen extends ConsumerStatefulWidget {
  const WebSocketDebugScreen({super.key});

  @override
  ConsumerState<WebSocketDebugScreen> createState() =>
      _WebSocketDebugScreenState();
}

class _WebSocketDebugScreenState extends ConsumerState<WebSocketDebugScreen> {
  @override
  Widget build(BuildContext context) {
    // Guard: only render in debug mode
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Debug screen not available in release mode')),
      );
    }

    final wsService = ref.watch(webSocketServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<ConnectionStatus>(
        stream: wsService.connectionStatus,
        initialData: ConnectionStatus.disconnected,
        builder: (context, snapshot) {
          final status = snapshot.data ?? ConnectionStatus.disconnected;
          return _buildBody(context, wsService, status);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WebSocketService wsService,
    ConnectionStatus status,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Connection'),
        _ConnectionStatusCard(status: status, wsService: wsService),
        const SizedBox(height: 16),

        _SectionHeader(title: 'Event Counts'),
        _EventCountsCard(),
        const SizedBox(height: 16),

        _SectionHeader(title: 'Average Processing Latency'),
        _LatencyCard(),
        const SizedBox(height: 16),

        _SectionHeader(title: 'Recent Errors'),
        _RecentErrorsCard(
          onClear: () => setState(() => WebSocketLogger.recentErrors.clear()),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                onPressed: () => wsService.retryConnection(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear Errors'),
                onPressed: () =>
                    setState(() => WebSocketLogger.recentErrors.clear()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({required this.status, required this.wsService});

  final ConnectionStatus status;
  final WebSocketService wsService;

  Color _colorFor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
        return Colors.red;
    }
  }

  String _labelFor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting…';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting…';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _colorFor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _labelFor(status),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Polling mode',
              value: wsService.isPollingMode ? 'Yes' : 'No',
            ),
            _InfoRow(
              label: 'Auth failures',
              value: wsService.authFailureCount.toString(),
            ),
            if (wsService.lastError != null)
              _InfoRow(
                label: 'Last error',
                value: wsService.lastError!,
                valueColor: Colors.red,
              ),
          ],
        ),
      ),
    );
  }
}

class _EventCountsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final counts = WebSocketLogger.eventCounts;
    if (counts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No events recorded yet.'),
        ),
      );
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: sorted
              .map((e) => _InfoRow(label: e.key, value: e.value.toString()))
              .toList(),
        ),
      ),
    );
  }
}

class _LatencyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final latencies = WebSocketLogger.averageLatencies;
    if (latencies.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No latency data yet.'),
        ),
      );
    }

    final sorted = latencies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: sorted
              .map(
                (e) => _InfoRow(
                  label: e.key,
                  value: '${e.value.toStringAsFixed(2)} ms',
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _RecentErrorsCard extends StatelessWidget {
  const _RecentErrorsCard({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final errors = WebSocketLogger.recentErrors;
    if (errors.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No recent errors.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors.reversed
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    e,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
