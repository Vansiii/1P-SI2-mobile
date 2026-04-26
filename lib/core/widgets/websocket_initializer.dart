// WebSocket initializer widget.
//
// Wraps the app (or a subtree) and:
//   1. Initializes [EventDispatcherService] on first build.
//   2. Attaches [WebSocketLifecycleManager] to observe app lifecycle and
//      network changes.
//   3. Disposes both services when the widget is removed from the tree.
//
// Requirements: 2.6, 2.15
//
// Note: The project contains two WebSocket service implementations:
//   - `services/websocket_service.dart`  — the original service used by
//     [WebSocketLifecycleManager] and most existing features.
//   - `core/services/websocket_service.dart` — the newer singleton used by
//     [EventDispatcherService] and [incident_realtime_provider].
//
// Each provider below wires to the correct implementation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/core/services/websocket_auth_service.dart';
import 'package:merchanic_repair/core/services/websocket_lifecycle_manager.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';

// Alias imports to disambiguate the two WebSocketService classes.
import 'package:merchanic_repair/services/websocket_service.dart' as legacy_ws;
import 'package:merchanic_repair/core/services/websocket_service.dart'
    as core_ws;

// ── Providers ─────────────────────────────────────────────────────────────────

/// Provides the [StorageService] singleton.
final _storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Provides the [WebSocketAuthService] singleton.
final webSocketAuthServiceProvider = Provider<WebSocketAuthService>((ref) {
  final storage = ref.watch(_storageServiceProvider);
  return WebSocketAuthService(storage);
});

/// Provides the legacy [WebSocketService] singleton (services/).
///
/// Used by [WebSocketLifecycleManager] and existing feature services.
final legacyWebSocketServiceProvider = Provider<legacy_ws.WebSocketService>((
  ref,
) {
  final storage = ref.watch(_storageServiceProvider);
  final service = legacy_ws.WebSocketService(storage);
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the core [WebSocketService] singleton (core/services/).
///
/// Used by [EventDispatcherService] and the incident real-time provider.
final coreWebSocketServiceProvider = Provider<core_ws.WebSocketService>((ref) {
  final service = core_ws.WebSocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the [EventDispatcherService] singleton, already initialized.
///
/// IMPORTANT: Uses legacyWebSocketService because that's the one that actually
/// connects to WebSocket endpoints. The coreWebSocketService is not connected.
final eventDispatcherProvider = Provider<EventDispatcherService>((ref) {
  final wsService = ref.watch(legacyWebSocketServiceProvider);
  final dispatcher = EventDispatcherService(webSocketService: wsService);
  dispatcher.initialize();
  ref.onDispose(dispatcher.dispose);
  return dispatcher;
});

/// Provides the [WebSocketLifecycleManager], already attached.
///
/// Detaches automatically when the provider is disposed.
final webSocketLifecycleManagerProvider = Provider<WebSocketLifecycleManager>((
  ref,
) {
  final wsService = ref.watch(legacyWebSocketServiceProvider);
  final authService = ref.watch(webSocketAuthServiceProvider);

  final manager = WebSocketLifecycleManager(
    webSocketService: wsService,
    authService: authService,
  );
  manager.attach();
  ref.onDispose(manager.detach);
  return manager;
});

// ── WebSocketInitializer ──────────────────────────────────────────────────────

/// Widget that bootstraps all WebSocket-related services for the app.
///
/// Place this widget high in the widget tree (e.g. wrapping [MaterialApp] or
/// the root [Scaffold]) so that services are initialized before any child
/// widget tries to use them.
///
/// Example — wrapping the router output:
/// ```dart
/// // In your root ConsumerStatefulWidget's build method:
/// return WebSocketInitializer(
///   child: MaterialApp.router(routerConfig: router),
/// );
/// ```
///
/// The widget:
/// - Reads [webSocketLifecycleManagerProvider] to trigger attach on first
///   build (Riverpod lazily initializes providers on first read).
/// - Reads [eventDispatcherProvider] to ensure the dispatcher is initialized.
/// - Does NOT modify [main.dart] — it is purely opt-in.
class WebSocketInitializer extends ConsumerWidget {
  const WebSocketInitializer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reading these providers triggers their initialization (lazy by default).
    // The providers self-dispose via ref.onDispose when the ProviderScope
    // is removed, satisfying Requirement 2.15.
    ref.watch(webSocketLifecycleManagerProvider);
    ref.watch(eventDispatcherProvider);

    return child;
  }
}
