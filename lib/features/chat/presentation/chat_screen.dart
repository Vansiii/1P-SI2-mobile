import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/data/models/message.dart';
import 'package:merchanic_repair/data/models/message_status.dart';
import 'package:merchanic_repair/data/models/cancellation_request.dart';
import 'package:merchanic_repair/services/api_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/features/auth/providers/auth_provider.dart' show authProvider;
import 'package:merchanic_repair/features/chat/services/chat_realtime_service.dart';
import 'package:merchanic_repair/features/chat/services/chat_cache.dart';
import 'package:merchanic_repair/features/chat/providers/chat_realtime_provider.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_provider.dart';
import 'package:merchanic_repair/core/websocket/connection_status.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int incidentId;

  const ChatScreen({super.key, required this.incidentId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];

  bool _isLoading = true;
  StreamSubscription? _wsSubscription;
  int? _activeConversationId;

  // Usuario actual
  int? _currentUserId;
  String? _currentUserRole; // 'client', 'workshop', 'technician'

  // Datos del incidente (para saber si es ambiguo)
  bool _isAmbiguous = false;

  // Cancelación mutua
  CancellationRequest? _pendingCancellation;
  bool _isLoadingCancellation = false;
  bool _redirectingAfterCancellation = false;

  // Typing indicator timer (Task 2.1, 2.2)
  Timer? _typingTimer;
  bool _isTyping = false;

  // ── Scroll inteligente (Task 2.3) ──────────────────────────────────────
  bool _isUserAtBottom = true;
  int _unreadNewMessages = 0;

  // ── Resincronización (Task 2.5) ──────────────────────────────────────
  StreamSubscription? _connectionSubscription;
  bool _wasDisconnected = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  // ── Optimización markAsRead con debounce ──────────────────────────────────
  final Set<int> _pendingReadIds = {};
  final Set<int> _alreadyReadIds = {};
  Timer? _markAsReadTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWebSocket();
    _getCurrentUser();
    _loadIncidentInfo();
    _loadPendingCancellation();

    // Listener para detectar posición del scroll (Task 2.3)
    _scrollController.addListener(_onScroll);

    // Listener para detectar reconexión (Task 2.5)
    _listenToConnectionStatus();

    // Limpieza automática de cache antiguo (Task 4.5)
    _scheduleOldCacheCleanup();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _wsSubscription?.cancel();
    _connectionSubscription?.cancel();
    _typingTimer?.cancel();
    _markAsReadTimer?.cancel();
    super.dispose();
  }

  // ─── Scroll inteligente ───────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Con reverse: true, posición 0 es el final (mensajes más recientes)
    final isAtBottom = _scrollController.position.pixels <= 50;

    if (isAtBottom != _isUserAtBottom) {
      setState(() {
        _isUserAtBottom = isAtBottom;
        if (isAtBottom) {
          _unreadNewMessages = 0; // Resetear contador al llegar abajo
        }
      });
    }
  }

  // ─── Resincronización tras reconexión ─────────────────────────────────────

  void _listenToConnectionStatus() {
    final wsService = ref.read(webSocketServiceProvider);

    // Obtener estado inicial inmediatamente (Task 4.2 fix)
    if (mounted) {
      setState(() {
        _connectionStatus = wsService.isConnected
            ? ConnectionStatus.connected
            : ConnectionStatus.disconnected;
      });
    }

    // Escuchar cambios futuros
    _connectionSubscription = wsService.connectionState.listen((status) {
      if (!mounted) return;

      setState(() {
        _connectionStatus = status;
      });

      if (status == ConnectionStatus.disconnected) {
        _wasDisconnected = true;
        debugPrint('[ChatScreen] 🔴 WebSocket desconectado');
      } else if (status == ConnectionStatus.connected && _wasDisconnected) {
        _wasDisconnected = false;
        debugPrint('[ChatScreen] 🟢 WebSocket reconectado - sincronizando...');
        _syncAfterReconnection();
      }
    });
  }

  /// Programa limpieza automática de cache antiguo (Task 4.5)
  void _scheduleOldCacheCleanup() {
    // Ejecutar limpieza en segundo plano después de 5 segundos
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        await ChatCache.clearOldCache();
        debugPrint('[ChatScreen] ✅ Limpieza automática de cache completada');
      } catch (e) {
        debugPrint('[ChatScreen] ❌ Error en limpieza de cache: $e');
      }
    });
  }

  Future<void> _syncAfterReconnection() async {
    try {
      // Obtener el ID del último mensaje conocido
      await _refreshActiveConversation();
      if (_activeConversationId == null) {
        return;
      }

      final api = ref.read(apiServiceProvider);
      final response = await api.getRaw(
        '${ApiConfig.chat}/incidents/${widget.incidentId}/messages',
      );

      List<dynamic> data;
      if (response.data is List) {
        data = response.data as List<dynamic>;
      } else if (response.data is Map && response.data['data'] != null) {
        data = response.data['data'] as List<dynamic>;
      } else {
        data = [];
      }

      if (data.isEmpty) {
        if (mounted) {
          setState(() {
            _messages.clear();
          });
        } else {
          _messages.clear();
        }
        await ChatCache.saveMessages(widget.incidentId, <Message>[]);
        return;
      }

      if (data.isEmpty) {
        debugPrint('[ChatScreen] ✅ Sin mensajes nuevos tras reconexión');
        return;
      }

      final newMessages = data
          .map((j) => Message.fromJson(j))
          .where((message) => message.conversationId == _activeConversationId)
          .toList();

      if (mounted) {
        setState(() {
          // Agregar solo mensajes que no existen
          _messages
            ..clear()
            ..addAll(newMessages);

          // Reordenar
          _messages.sort(
            (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            ),
          );
        });

        // Scroll solo si usuario está abajo
        _scrollToBottom();

        // Actualizar cache
        await ChatCache.saveMessages(widget.incidentId, _messages);

        debugPrint(
          '[ChatScreen] ✅ Sincronizados ${newMessages.length} mensajes nuevos',
        );
      }
    } catch (e) {
      debugPrint('[ChatScreen] ❌ Error sincronizando tras reconexión: $e');
    }
  }

  /// Sincronizar con backend (usado por pull-to-refresh) (Task 4.3)
  Future<void> _syncWithBackend() async {
    try {
      await _refreshActiveConversation();
      if (_activeConversationId == null) {
        return;
      }

      final api = ref.read(apiServiceProvider);
      final response = await api.getRaw(
        '${ApiConfig.chat}/incidents/${widget.incidentId}/messages',
      );

      List<dynamic> data;
      if (response.data is List) {
        data = response.data as List<dynamic>;
      } else if (response.data is Map && response.data['data'] != null) {
        data = response.data['data'] as List<dynamic>;
      } else {
        data = [];
      }

      final serverMessages = data
          .map((j) => Message.fromJson(j))
          .where((message) => message.conversationId == _activeConversationId)
          .toList();

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(serverMessages);
          _messages.sort(
            (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            ),
          );
        });

        // Actualizar cache
        await ChatCache.saveMessages(widget.incidentId, serverMessages);

        debugPrint('[ChatScreen] ✅ Mensajes sincronizados con backend');
      }
    } catch (e) {
      debugPrint('[ChatScreen] ❌ Error sincronizando con backend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al sincronizar mensajes')),
        );
      }
    }
  }

  // ─── Carga de datos ───────────────────────────────────────────────────────

  Future<void> _getCurrentUser() async {
    final authState = ref.read(authProvider);
    if (authState.user != null) {
      _currentUserId = authState.user!.id;
      _currentUserRole = authState.user!.userType;
      return;
    }
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('${ApiConfig.auth}/me');
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          _currentUserId = (data['id'] as num?)?.toInt();
          _currentUserRole = data['user_type'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error getting current user: $e');
    }
  }

  Future<void> _loadIncidentInfo() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get(
        '${ApiConfig.incidentes}/${widget.incidentId}',
      );
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          _isAmbiguous = data['es_ambiguo'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading incident info: $e');
    }
  }

  Future<int?> _fetchActiveConversationId() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.getRaw(
        '${ApiConfig.chat}/incidents/${widget.incidentId}/conversation',
      );
      final body = response.data;
      final data =
          body is Map<String, dynamic> && body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : (body is Map<String, dynamic> ? body : <String, dynamic>{});
      return (data['id'] as num?)?.toInt();
    } catch (e) {
      final cachedConversationId = await ChatCache.getConversationId(
        widget.incidentId,
      );
      if (cachedConversationId != null && cachedConversationId > 0) {
        debugPrint(
          '[ChatScreen] Using cached conversation $cachedConversationId for incident ${widget.incidentId}',
        );
        return cachedConversationId;
      }
      if (_activeConversationId != null && _activeConversationId! > 0) {
        return _activeConversationId;
      }
      debugPrint(
        '[ChatScreen] No active conversation for incident ${widget.incidentId}: $e',
      );
      return null;
    }
  }

  Future<void> _clearCurrentConversation({
    bool keepConversationId = false,
    bool clearPersistentCache = true,
  }) async {
    if (!keepConversationId) {
      _activeConversationId = null;
    }
    if (mounted) {
      setState(() {
        _messages.clear();
      });
    } else {
      _messages.clear();
    }
    if (clearPersistentCache) {
      await ChatCache.clearIncident(widget.incidentId);
    }
  }

  Future<void> _applyConversationId(int conversationId) async {
    if (_activeConversationId == conversationId) return;
    _activeConversationId = conversationId;
    await _clearCurrentConversation(
      keepConversationId: true,
      clearPersistentCache: false,
    );
  }

  Future<void> _refreshActiveConversation() async {
    final conversationId = await _fetchActiveConversationId();
    if (conversationId == null) {
      await _clearCurrentConversation();
      return;
    }
    await _applyConversationId(conversationId);
  }

  Future<void> _loadMessages() async {
    final activeConversationId = await _fetchActiveConversationId();
    if (activeConversationId == null) {
      await _clearCurrentConversation();
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    await _applyConversationId(activeConversationId);

    // 1. Cargar desde cache INMEDIATAMENTE (sin loader)
    final cachedMessages = (await ChatCache.getMessages(widget.incidentId))
        .where((message) => message.conversationId == _activeConversationId)
        .toList();
    if (cachedMessages.isNotEmpty && mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(_dedupeMessages(cachedMessages));
      });
      _scrollToBottom();
    }

    // 2. Mostrar loader solo si no hay cache
    if (mounted && cachedMessages.isEmpty) {
      setState(() => _isLoading = true);
    }

    // 3. Sincronizar con backend en segundo plano
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.getRaw(
        '${ApiConfig.chat}/incidents/${widget.incidentId}/messages',
      );

      List<dynamic> data;
      if (response.data is List) {
        data = response.data as List<dynamic>;
      } else if (response.data is Map && response.data['data'] != null) {
        data = response.data['data'] as List<dynamic>;
      } else {
        data = [];
      }

      final serverMessages = _dedupeMessages(
        data
            .map((j) => Message.fromJson(j))
            .where((message) => message.conversationId == _activeConversationId)
            .toList(),
      );

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(serverMessages);
        });
        _scrollToBottom(force: true); // Forzar scroll al cargar inicial

        // 4. Guardar en cache
        await ChatCache.saveMessages(widget.incidentId, serverMessages);
      }
    } catch (e) {
      if (mounted) {
        // Si hay cache, no mostrar error (modo offline)
        if (cachedMessages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar mensajes: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingCancellation() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get(
        '${ApiConfig.cancellation}/incidents/${widget.incidentId}/pending',
      );
      // El endpoint devuelve null o el objeto directamente
      if (mounted) {
        setState(() {
          if (response.containsKey('id') && response['id'] != null) {
            _pendingCancellation = CancellationRequest.fromJson(response);
          } else {
            _pendingCancellation = null;
          }
        });
      }
    } catch (e) {
      // 404 = no hay solicitud pendiente, es normal
      if (mounted) {
        setState(() => _pendingCancellation = null);
      }
      debugPrint('No pending cancellation: $e');
    }
  }

  // ─── WebSocket ────────────────────────────────────────────────────────────

  void _connectWebSocket() async {
    final wsService = ref.read(webSocketServiceProvider);
    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getAccessToken();
    if (token == null || token.isEmpty) return;

    _wsSubscription = wsService.messages.listen((message) {
      if (!mounted) return;
      final type =
          message['type'] as String? ?? message['event_type'] as String?;
      final incidentId = _extractIncidentId(message);

      if (incidentId != null && incidentId != widget.incidentId) return;

      if (type == 'new_message' ||
          type == 'chat.message_sent' ||
          type == 'chat_message_sent') {
        final incoming = _parseIncomingChatMessage(message);
        if (incoming != null) {
          _upsertIncomingMessage(incoming);
        }
      } else if (type == 'incident.assignment_accepted' ||
          type == 'assignment_accepted') {
        final data = (message['data'] is Map<String, dynamic>)
            ? message['data'] as Map<String, dynamic>
            : ((message['payload'] is Map<String, dynamic>)
                ? message['payload'] as Map<String, dynamic>
                : message);
        final conversationId = (data['conversation_id'] as num?)?.toInt();
        if (conversationId != null) {
          unawaited(_applyConversationId(conversationId));
        }
      } else if (type == 'chat.message_read' || type == 'message_read') {
        _handleMessageStatusEvent(message, isRead: true);
      } else if (type == 'chat.message_delivered' ||
          type == 'message_delivered') {
        _handleMessageStatusEvent(message, isRead: false);
      } else if (type == 'incident_status_changed' ||
          type == 'incident.status_changed') {
        final data = (message['data'] is Map<String, dynamic>)
            ? message['data'] as Map<String, dynamic>
            : message;
        final reason = data['reason']?.toString();
        if (reason == 'mutual_cancellation') {
          unawaited(_handleCancellationApprovedAndRedirect());
        }
      } else if (type == 'cancellation.requested' ||
          type == 'cancellation.approved' ||
          type == 'cancellation.rejected' ||
          type == 'cancellation_request' ||
          type == 'cancellation_response') {
        // Recargar estado de cancelación cuando llega notificación WS
        _handleCancellationRealtimeEvent(type!);
      }
    });

    wsService.connect(
      '${ApiConfig.wsIncidents}/${widget.incidentId}',
      token: token,
    );
  }

  // ─── Envío de mensajes ────────────────────────────────────────────────────

  void _handleCancellationRealtimeEvent(String type) {
    if (type == 'cancellation.requested' || type == 'cancellation_request') {
      _loadPendingCancellation();
      return;
    }

    if (type == 'cancellation.rejected') {
      if (mounted) {
        setState(() => _pendingCancellation = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Cancelación rechazada. El servicio continúa.'),
          ),
        );
      }
      return;
    }

    if (type == 'cancellation.approved' || type == 'cancellation_response') {
      unawaited(_handleCancellationApprovedAndRedirect());
      return;
    }
  }

  Future<void> _handleCancellationApprovedAndRedirect() async {
    if (!mounted || _redirectingAfterCancellation) return;
    _redirectingAfterCancellation = true;

    await _clearCurrentConversation();
    setState(() => _pendingCancellation = null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Cancelación aprobada. Volviendo a solicitudes...'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Forzar refresh para evitar estado viejo al volver a la lista.
    unawaited(ref.read(incidentsProvider.notifier).loadIncidents());

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) context.go('/incidents');
    _redirectingAfterCancellation = false;
  }

  int? _extractIncidentId(Map<String, dynamic> message) {
    final topLevel = (message['incident_id'] as num?)?.toInt();
    if (topLevel != null) return topLevel;

    final payload = message['payload'];
    if (payload is Map<String, dynamic>) {
      final payloadIncidentId = (payload['incident_id'] as num?)?.toInt();
      if (payloadIncidentId != null) return payloadIncidentId;
    }

    final data = message['data'];
    if (data is Map<String, dynamic>) {
      return (data['incident_id'] as num?)?.toInt();
    }

    return null;
  }

  Message? _parseIncomingChatMessage(Map<String, dynamic> message) {
    try {
      final legacy = message['message'];
      if (legacy is Map<String, dynamic>) {
        return Message.fromJson(legacy);
      }

      final payload = message['payload'];
      final data = message['data'];
      final source = payload is Map<String, dynamic>
          ? payload
          : (data is Map<String, dynamic> ? data : null);
      if (source != null) {
        final messageId = (source['message_id'] as num?)?.toInt();
        final conversationId = (source['conversation_id'] as num?)?.toInt();
        final incidentId = (source['incident_id'] as num?)?.toInt();
        final senderId = (source['sender_id'] as num?)?.toInt();
        if (messageId == null || incidentId == null || senderId == null) {
          return null;
        }

        return Message.fromJson({
          'id': messageId,
          'conversation_id': conversationId ?? _activeConversationId ?? 0,
          'incident_id': incidentId,
          'sender_id': senderId,
          'sender_name': source['sender_name'],
          'sender_role': source['sender_role'],
          'message': source['content'] ?? source['message'] ?? '',
          'message_type': source['message_type'] ?? 'text',
          'created_at': _normalizeServerTimestamp(
            source['sent_at'] ?? message['timestamp'],
          ),
          'sent_at': _normalizeServerTimestamp(
            source['sent_at'] ?? message['timestamp'],
          ),
          'is_read': false,
        });
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error parsing incoming chat event: $e');
    }
    return null;
  }

  void _upsertIncomingMessage(Message newMessage) {
    if (newMessage.conversationId > 0 &&
        _activeConversationId != null &&
        newMessage.conversationId != _activeConversationId) {
      _activeConversationId = newMessage.conversationId;
      _messages.clear();
      unawaited(ChatCache.clearIncident(widget.incidentId));
    }
    if (newMessage.conversationId > 0 && _activeConversationId == null) {
      _activeConversationId = newMessage.conversationId;
    }

    setState(() {
      final messageId = newMessage.id;
      final existingIndex = messageId == null
          ? -1
          : _messages.indexWhere((m) => m.id == messageId);
      final optimisticIndex = existingIndex == -1
          ? _findMatchingOptimisticMessageIndex(newMessage)
          : -1;

      if (existingIndex != -1) {
        _messages[existingIndex] = _mergeMessageVersions(
          _messages[existingIndex],
          newMessage,
        );
      } else if (optimisticIndex != -1) {
        _messages[optimisticIndex] = _mergeMessageVersions(
          _messages[optimisticIndex],
          newMessage.copyWith(
            status: MessageStatus.sent,
            sentAt: newMessage.sentAt ?? newMessage.createdAt,
            isTemporary: false,
          ),
        );
      } else if (_hasDuplicateSystemMessage(newMessage)) {
        return;
      } else {
        _messages.add(newMessage);
      }

      final deduped = _dedupeMessages(_messages);
      _messages
        ..clear()
        ..addAll(deduped);
    });

    _scrollToBottom();
    ChatCache.addMessage(newMessage);
  }

  List<Message> _dedupeMessages(List<Message> source) {
    final sorted = [...source]..sort(
      (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
        b.createdAt ?? DateTime.now(),
      ),
    );

    final deduped = <Message>[];
    for (final message in sorted) {
      final existingIndex = message.id == null
          ? -1
          : deduped.indexWhere((entry) => entry.id == message.id);

      if (existingIndex != -1) {
        deduped[existingIndex] = _mergeMessageVersions(
          deduped[existingIndex],
          message,
        );
        continue;
      }

      final lastMessage = deduped.isEmpty ? null : deduped.last;
      if (lastMessage != null && _isDuplicateSystemMessage(lastMessage, message)) {
        deduped[deduped.length - 1] = message;
        continue;
      }

      deduped.add(message);
    }

    return deduped;
  }

  bool _hasDuplicateSystemMessage(Message incoming) {
    return _messages.any((existing) => _isDuplicateSystemMessage(existing, incoming));
  }

  bool _isDuplicateSystemMessage(Message previous, Message incoming) {
    if (previous.type != 'system' || incoming.type != 'system') {
      return false;
    }

    if (
        previous.conversationId != incoming.conversationId ||
        previous.incidentId != incoming.incidentId ||
        previous.senderId != incoming.senderId) {
      return false;
    }

    final previousText = previous.message.trim();
    final incomingText = incoming.message.trim();
    if (previousText.isEmpty || previousText != incomingText) {
      return false;
    }

    final previousTime = previous.createdAt ?? DateTime.now();
    final incomingTime = incoming.createdAt ?? DateTime.now();
    return incomingTime.difference(previousTime).inMinutes.abs() <= 2;
  }

  int _findMatchingOptimisticMessageIndex(Message serverMessage) {
    return _messages.indexWhere((entry) {
      if (!entry.isTemporary) return false;
      if (entry.conversationId != 0 &&
          serverMessage.conversationId != 0 &&
          entry.conversationId != serverMessage.conversationId) {
        return false;
      }
      if (entry.senderId != serverMessage.senderId) return false;
      if (entry.incidentId != serverMessage.incidentId) return false;
      if (entry.message.trim() != serverMessage.message.trim()) return false;

      final optimisticTime = entry.createdAt ?? DateTime.now();
      final serverTime =
          serverMessage.createdAt ?? serverMessage.sentAt ?? DateTime.now();
      return optimisticTime.difference(serverTime).inMinutes.abs() <= 2;
    });
  }

  Message _mergeMessageVersions(Message current, Message incoming) {
    final mergedStatus = _messageStatusRank(incoming.status) >=
            _messageStatusRank(current.status)
        ? incoming.status
        : current.status;

    return current.copyWith(
      id: incoming.id ?? current.id,
      localId: current.localId ?? incoming.localId,
      conversationId: incoming.conversationId != 0
          ? incoming.conversationId
          : current.conversationId,
      senderName: incoming.senderName ?? current.senderName,
      senderRole: incoming.senderRole ?? current.senderRole,
      message: incoming.message.isNotEmpty ? incoming.message : current.message,
      type: incoming.type.isNotEmpty ? incoming.type : current.type,
      createdAt: incoming.createdAt ?? current.createdAt,
      sentAt: incoming.sentAt ?? current.sentAt ?? incoming.createdAt,
      deliveredAt: incoming.deliveredAt ?? current.deliveredAt,
      readAt: incoming.readAt ?? current.readAt,
      status: mergedStatus,
      errorMessage: incoming.errorMessage ?? current.errorMessage,
      isRead: incoming.isRead ?? current.isRead,
      isTemporary: incoming.isTemporary && current.id == null,
    );
  }

  int _messageStatusRank(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return 0;
      case MessageStatus.sent:
        return 1;
      case MessageStatus.delivered:
        return 2;
      case MessageStatus.read:
        return 3;
      case MessageStatus.failed:
        return -1;
    }
  }

  void _handleMessageStatusEvent(
    Map<String, dynamic> message, {
    required bool isRead,
  }) {
    final payload = (message['payload'] is Map<String, dynamic>)
        ? message['payload'] as Map<String, dynamic>
        : <String, dynamic>{};
    final src = payload.isNotEmpty
        ? payload
        : ((message['data'] is Map<String, dynamic>)
              ? message['data'] as Map<String, dynamic>
              : message);

    final messageId = (src['message_id'] as num?)?.toInt();
    if (messageId == null) return;

    final timestampRaw = isRead ? src['read_at'] : src['delivered_at'];
    final eventDate = timestampRaw is String && timestampRaw.trim().isNotEmpty
        ? DateTime.parse(_normalizeServerTimestamp(timestampRaw)).toLocal()
        : DateTime.now();

    setState(() {
      final index = _messages.indexWhere((entry) => entry.id == messageId);
      if (index == -1) return;

      final current = _messages[index];
      final updated = current.copyWith(
        status: isRead ? MessageStatus.read : MessageStatus.delivered,
        readAt: isRead ? eventDate : current.readAt,
        deliveredAt: isRead ? current.deliveredAt : eventDate,
        isRead: isRead ? true : current.isRead,
      );
      _messages[index] = _mergeMessageVersions(current, updated);
    });

    unawaited(
      ChatCache.updateMessageStatus(widget.incidentId, messageId, {
        if (isRead) 'read_at': eventDate.toUtc().toIso8601String(),
        if (!isRead) 'delivered_at': eventDate.toUtc().toIso8601String(),
        if (isRead) 'is_read': true,
      }),
    );
  }

  /// Handle text input changes for typing indicator (Task 2.1, 2.2)
  void _onTextChanged(String text) {
    final chatRealtimeService = ref.read(chatRealtimeServiceProvider);

    if (text.trim().isNotEmpty && !_isTyping) {
      // User started typing
      _isTyping = true;
      chatRealtimeService.sendTypingIndicator(widget.incidentId);
    }

    // Reset the 3-second timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      // User stopped typing after 3 seconds
      if (_isTyping) {
        _isTyping = false;
        chatRealtimeService.sendTypingStopIndicator(widget.incidentId);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _refreshActiveConversation();
    if (_activeConversationId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AÃºn no hay una conversaciÃ³n activa para este taller'),
          ),
        );
      }
      return;
    }

    // Stop typing indicator when sending
    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      final chatRealtimeService = ref.read(chatRealtimeServiceProvider);
      chatRealtimeService.sendTypingStopIndicator(widget.incidentId);
    }

    // 1. Crear mensaje temporal para envío optimista
    final tempMessage = Message.temporary(
      incidentId: widget.incidentId,
      senderId: _currentUserId ?? 0,
      senderName: 'Tú',
      messageText: text,
    );
    final optimisticMessage = tempMessage.copyWith(
      conversationId: _activeConversationId,
    );

    // 2. Agregar mensaje temporal INMEDIATAMENTE
    setState(() {
      _messages.add(optimisticMessage);
    });
    await ChatCache.addMessage(optimisticMessage);

    // 3. Limpiar input y hacer scroll (forzado porque el usuario envió)
    _messageController.clear();
    _scrollToBottom(force: true);

    // 4. Enviar al backend en segundo plano
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '${ApiConfig.chat}/incidents/${widget.incidentId}/messages',
        data: {'message': text},
      );

      final payload = response['data'] ?? response;
      if (_isOfflineQueuedPayload(payload)) {
        await ChatCache.saveMessages(widget.incidentId, _messages);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Mensaje guardado localmente. Se enviará al reconectar.',
              ),
            ),
          );
        }
        return;
      }

      // 5. Reemplazar mensaje temporal con mensaje del servidor
      final sentMessage = Message.fromJson(payload);
      if (sentMessage.conversationId > 0 &&
          sentMessage.conversationId != _activeConversationId) {
        await _applyConversationId(sentMessage.conversationId);
      }
      setState(() {
        final index = _messages.indexWhere(
          (m) => m.localId == optimisticMessage.localId,
        );
        final existingServerIndex = _messages.indexWhere(
          (m) => m.id != null && m.id == sentMessage.id,
        );

        if (existingServerIndex != -1 && index != -1) {
          _messages[existingServerIndex] = _mergeMessageVersions(
            _messages[existingServerIndex],
            sentMessage.copyWith(
              status: MessageStatus.sent,
              sentAt: sentMessage.sentAt ?? sentMessage.createdAt,
              isTemporary: false,
            ),
          );
          _messages.removeAt(index);
        } else if (index != -1) {
          _messages[index] = _mergeMessageVersions(
            _messages[index],
            sentMessage.copyWith(
              status: MessageStatus.sent,
              sentAt: sentMessage.sentAt ?? sentMessage.createdAt,
              isTemporary: false,
            ),
          );
        } else {
          _messages.add(
            sentMessage.copyWith(
              status: MessageStatus.sent,
              sentAt: sentMessage.sentAt ?? sentMessage.createdAt,
              isTemporary: false,
            ),
          );
        }
      });

      // 6. Guardar en cache
      await ChatCache.addMessage(sentMessage);

      debugPrint('[ChatScreen] ✅ Mensaje enviado: ${sentMessage.id}');
    } catch (e) {
      // 7. Marcar mensaje como fallido
      setState(() {
        final index = _messages.indexWhere(
          (m) => m.localId == optimisticMessage.localId,
        );
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            status: MessageStatus.failed,
            errorMessage: e.toString(),
          );
        }
      });
      await ChatCache.saveMessages(widget.incidentId, _messages);

      debugPrint('[ChatScreen] ❌ Error al enviar mensaje: $e');

      // Mostrar snackbar con opción de reintentar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo enviar el mensaje'),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: () => _retryMessage(optimisticMessage.localId!),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Reintentar envío de mensaje fallido
  Future<void> _retryMessage(String localId) async {
    final messageIndex = _messages.indexWhere((m) => m.localId == localId);
    if (messageIndex == -1) return;

    final failedMessage = _messages[messageIndex];

    // Cambiar estado a "enviando"
    setState(() {
      _messages[messageIndex] = failedMessage.copyWith(
        status: MessageStatus.sending,
        errorMessage: null,
      );
    });

    // Reintentar envío
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '${ApiConfig.chat}/incidents/${widget.incidentId}/messages',
        data: {'message': failedMessage.message},
      );

      final payload = response['data'] ?? response;
      if (_isOfflineQueuedPayload(payload)) {
        await ChatCache.saveMessages(widget.incidentId, _messages);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mensaje reencolado. Se enviará al reconectar.'),
            ),
          );
        }
        return;
      }

      final sentMessage = Message.fromJson(payload);
      setState(() {
        final existingServerIndex = _messages.indexWhere(
          (m) => m.id != null && m.id == sentMessage.id,
        );
        if (existingServerIndex != -1 && existingServerIndex != messageIndex) {
          _messages[existingServerIndex] = _mergeMessageVersions(
            _messages[existingServerIndex],
            sentMessage.copyWith(
              status: MessageStatus.sent,
              sentAt: sentMessage.sentAt ?? sentMessage.createdAt,
              isTemporary: false,
            ),
          );
          _messages.removeAt(messageIndex);
        } else {
          _messages[messageIndex] = _mergeMessageVersions(
            _messages[messageIndex],
            sentMessage.copyWith(
              status: MessageStatus.sent,
              sentAt: sentMessage.sentAt ?? sentMessage.createdAt,
              isTemporary: false,
            ),
          );
        }
      });
      await ChatCache.addMessage(sentMessage);

      debugPrint('[ChatScreen] ✅ Mensaje reenviado: ${sentMessage.id}');
    } catch (e) {
      setState(() {
        _messages[messageIndex] = failedMessage.copyWith(
          status: MessageStatus.failed,
          errorMessage: e.toString(),
        );
      });
      await ChatCache.saveMessages(widget.incidentId, _messages);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al reenviar: $e')));
      }
    }
  }

  // ─── Cancelación mutua ────────────────────────────────────────────────────

  void _showCancellationDialog() {
    final receiverName = _currentUserRole == 'client'
        ? 'el taller'
        : 'el cliente';
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Solicitar Cancelación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta solicitud será enviada a $receiverName. Si ambas partes están de acuerdo, el incidente se cancelará y el sistema buscará un nuevo taller automáticamente.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Motivo de la cancelación:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText:
                        'Explica por qué solicitas cancelar el servicio...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (reasonController.text.trim().isNotEmpty &&
                    reasonController.text.trim().length < 10)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '⚠️ Mínimo 10 caracteres',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: reasonController.text.trim().length >= 10
                  ? () {
                      Navigator.of(ctx).pop();
                      _requestCancellation(reasonController.text.trim());
                    }
                  : null,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Enviar Solicitud'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestCancellation(String reason) async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '${ApiConfig.cancellation}/incidents/${widget.incidentId}/request',
        data: {'reason': reason},
      );
      if (mounted) {
        setState(() {
          _pendingCancellation = CancellationRequest.fromJson(response);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud de cancelación enviada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _respondToCancellation(bool accept) async {
    if (_pendingCancellation == null) return;
    setState(() => _isLoadingCancellation = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.post(
        '${ApiConfig.cancellation}/requests/${_pendingCancellation!.id}/respond',
        data: {
          'accept': accept,
          'response_message': accept
              ? 'Acepto cancelar el servicio'
              : 'No acepto cancelar el servicio',
        },
      );

      if (mounted) {
        if (accept) {
          unawaited(_handleCancellationApprovedAndRedirect());
          return;
        } else {
          setState(() => _pendingCancellation = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Cancelación rechazada. El servicio continúa.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCancellation = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Programa el marcado de un mensaje como leído con debounce de 1 segundo.
  /// Agrupa todos los IDs pendientes en una sola petición al backend.
  void _scheduleMarkAsRead(int messageId) {
    if (_alreadyReadIds.contains(messageId)) return;
    _pendingReadIds.add(messageId);

    _markAsReadTimer?.cancel();
    _markAsReadTimer = Timer(const Duration(seconds: 1), _flushMarkAsRead);
  }

  Future<void> _flushMarkAsRead() async {
    if (_pendingReadIds.isEmpty) return;

    final ids = Set<int>.from(_pendingReadIds);
    _pendingReadIds.clear();
    _alreadyReadIds.addAll(ids);

    try {
      final api = ref.read(apiServiceProvider);
      // Una sola petición para marcar todo el incidente como leído
      await api.post(
        '${ApiConfig.chat}/incidents/${widget.incidentId}/messages/mark-read',
      );
      debugPrint('[ChatScreen] Marked ${ids.length} messages as read (batch)');
    } catch (e) {
      // Si falla, volver a agregar para reintentar
      _pendingReadIds.addAll(ids);
      _alreadyReadIds.removeAll(ids);
      debugPrint('[ChatScreen] Error marking messages as read: $e');
    }
  }

  void _scrollToBottom({bool force = false}) {
    // Solo hacer scroll automático si el usuario está abajo o es forzado
    if (!force && !_isUserAtBottom) {
      // Usuario está leyendo mensajes antiguos, no interrumpir
      setState(() {
        _unreadNewMessages++;
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Con reverse: true, la posición 0 es el final (mensajes más recientes)
        // Animación más suave (Task 3.6)
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    if (now.difference(date).inDays > 0) {
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _normalizeServerTimestamp(dynamic rawValue) {
    final raw = rawValue == null ? '' : rawValue.toString().trim();
    if (raw.isEmpty) return DateTime.now().toUtc().toIso8601String();
    final hasTimezone = RegExp(r'([zZ]|[+\-]\d{2}:\d{2})$').hasMatch(raw);
    return hasTimezone ? raw : '${raw}Z';
  }

  // ─── Separadores de día (Task 3.4) ────────────────────────────────────────

  /// Versión para acceso con índice real (cronológico).
  /// reversedIndex = posición en _messages (0 = más antiguo).
  /// Muestra separador cuando el mensaje es el primero de un nuevo día.
  bool _shouldShowDaySeparatorReversed(int reversedIndex) {
    if (reversedIndex == 0)
      return true; // El más antiguo siempre tiene separador

    final currentMsg = _messages[reversedIndex];
    final prevMsg =
        _messages[reversedIndex - 1]; // Mensaje anterior en el tiempo

    if (currentMsg.createdAt == null || prevMsg.createdAt == null) return false;

    final currentDate = currentMsg.createdAt!;
    final prevDate = prevMsg.createdAt!;

    return currentDate.year != prevDate.year ||
        currentDate.month != prevDate.month ||
        currentDate.day != prevDate.day;
  }

  Widget _buildDaySeparator(DateTime? date) {
    if (date == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String label;
    if (messageDate == today) {
      label = 'Hoy';
    } else if (messageDate == yesterday) {
      label = 'Ayer';
    } else if (now.difference(messageDate).inDays < 7) {
      // Día de la semana
      const weekDays = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      label = weekDays[date.weekday - 1];
    } else {
      // Fecha completa
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Agrupar mensajes consecutivos (Task 3.3) ─────────────────────────────

  /// Versión para acceso con índice real (cronológico).
  /// Un mensaje está agrupado si el mensaje anterior (reversedIndex - 1)
  /// es del mismo usuario y tiene menos de 2 minutos de diferencia.
  bool _isMessageGroupedReversed(int reversedIndex) {
    if (reversedIndex == 0) return false; // El más antiguo no está agrupado

    final currentMsg = _messages[reversedIndex];
    final prevMsg =
        _messages[reversedIndex - 1]; // Mensaje anterior en el tiempo

    if (currentMsg.senderId != prevMsg.senderId) return false;

    if (currentMsg.createdAt != null && prevMsg.createdAt != null) {
      final diff = currentMsg.createdAt!.difference(prevMsg.createdAt!).abs();
      if (diff.inMinutes > 2) return false;
    }

    return true;
  }

  bool get _isOwnCancellationRequest =>
      _pendingCancellation?.requestedByUserId == _currentUserId;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            // Avatar circular (Task 3.1)
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Icon(
                _currentUserRole == 'client' ? Icons.build : Icons.person,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Badge "AMBIGUO" más pequeño (Task 3.1)
                      if (_isAmbiguous) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AMBIGUO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Indicador "en línea" (Task 3.1)
                  if (_connectionStatus == ConnectionStatus.connected)
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34C759),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'En línea',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Botón de cancelación mutua (iconos más pequeños - Task 3.1)
          if (_pendingCancellation == null)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 20),
              onPressed: _showCancellationDialog,
              tooltip: 'Solicitar cancelación',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadMessages,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Indicador de conexión (Task 4.2) ──
          if (_connectionStatus != ConnectionStatus.connected)
            _buildConnectionBanner(),

          // ── Aviso caso ambiguo (solo si no hay solicitud pendiente) ──
          if (_isAmbiguous && _pendingCancellation == null)
            _buildAmbiguousNotice(),

          // ── Tarjeta de solicitud de cancelación pendiente ──
          if (_pendingCancellation != null) _buildCancellationCard(),

          // ── Lista de mensajes ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _syncWithBackend,
                    child: Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          reverse:
                              true, // índice 0 = mensaje más reciente (abajo)
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            // Con reverse: true, índice 0 = más reciente (abajo)
                            // Invertimos el acceso: índice 0 → último mensaje de la lista
                            final reversedIndex = _messages.length - 1 - index;
                            final msg = _messages[reversedIndex];
                            final isMe = msg.senderId == _currentUserId;
                            final isSystem = msg.type == 'system';

                            // Separador de día: comparar con el mensaje anterior en el tiempo
                            // (reversedIndex - 1 es el mensaje anterior cronológicamente)
                            final showDaySeparator =
                                _shouldShowDaySeparatorReversed(reversedIndex);

                            // Agrupación: comparar con el mensaje anterior en el tiempo
                            final isGrouped = _isMessageGroupedReversed(
                              reversedIndex,
                            );
                            final isFirstInGroup = !isGrouped;

                            if (isSystem) return _buildSystemMessage(msg);

                            // Mark message as read when visible (debounced)
                            if (!isMe && msg.id != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scheduleMarkAsRead(msg.id!);
                              });
                            }

                            return Column(
                              children: [
                                _buildMessageBubble(
                                  msg,
                                  isMe,
                                  isFirstInGroup: isFirstInGroup,
                                ),
                                if (showDaySeparator)
                                  _buildDaySeparator(msg.createdAt),
                              ],
                            );
                          },
                        ),

                        // ── Botón flotante "bajar" (Task 2.4) ──
                        if (!_isUserAtBottom && _unreadNewMessages > 0)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: _buildScrollToBottomButton(),
                          ),
                      ],
                    ),
                  ),
          ),

          // ── Typing indicator (Task 2.1) ──
          _buildTypingIndicator(),

          // ── Input ──
          _buildInput(),
        ],
      ),
    );
  }

  // ─── Widgets de cancelación ───────────────────────────────────────────────

  Widget _buildConnectionBanner() {
    final isReconnecting = _connectionStatus == ConnectionStatus.reconnecting;
    final bgColor = isReconnecting ? Colors.orange[700] : Colors.red[700];
    final icon = isReconnecting ? Icons.sync : Icons.wifi_off;
    final text = isReconnecting ? 'Reconectando...' : 'Sin conexión';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbiguousNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Caso Ambiguo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Coordina detalles por chat o solicita cancelación.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _showCancellationDialog,
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationCard() {
    final isOwn = _isOwnCancellationRequest;
    final requesterLabel = _pendingCancellation!.requestedBy == 'client'
        ? 'El cliente'
        : 'El taller';
    final waitingLabel = _pendingCancellation!.requestedBy == 'client'
        ? 'el taller'
        : 'el cliente';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOwn
              ? [const Color(0xFFDBEAFE), const Color(0xFFBFDBFE)]
              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
        ),
        border: Border.all(
          color: isOwn ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOwn
                      ? 'Solicitud enviada — esperando a $waitingLabel'
                      : '$requesterLabel solicita cancelar el servicio',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOwn
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Motivo:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _pendingCancellation!.reason,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          // Botones solo para quien recibe la solicitud
          if (!isOwn) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingCancellation
                        ? null
                        : () => _respondToCancellation(true),
                    icon: _isLoadingCancellation
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 15),
                    label: const Text('Aceptar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingCancellation
                        ? null
                        : () => _respondToCancellation(false),
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text('Rechazar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Tiempo restante para quien envió
          if (isOwn) ...[
            const SizedBox(height: 6),
            Text(
              _formatExpiration(_pendingCancellation!.timeUntilExpiration),
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatExpiration(Duration d) {
    if (d <= Duration.zero) return 'Solicitud expirada';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? 'Expira en ${h}h ${m}m' : 'Expira en ${m}m';
  }

  // ─── Widgets de mensajes ──────────────────────────────────────────────────

  /// Build typing indicator widget (Task 2.1)
  Widget _buildTypingIndicator() {
    final typingUsers = ref.watch(chatTypingUsersProvider(widget.incidentId));
    final typingText = _buildTypingText(typingUsers);

    if (typingText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TypingDots(),
                const SizedBox(width: 8),
                Text(
                  typingText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildTypingText(List<String> typingUsers) {
    if (typingUsers.isEmpty) return '';
    return 'escribiendo';
  }

  Widget _buildSystemMessage(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.message,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Message message,
    bool isMe, {
    bool isFirstInGroup = true,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: isFirstInGroup ? 8 : 2,
        ), // Menos espacio si está agrupado
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.70, // 70% ancho máximo
        ),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF0084FF)
              : const Color(0xFFF0F0F0), // Colores mejorados
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Mostrar nombre y rol solo en primer mensaje del grupo
            if (!isMe && message.senderName != null && isFirstInGroup)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.senderName!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0084FF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleBadgeColor(message.senderRole),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getRoleBadgeText(message.senderRole),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _getRoleBadgeTextColor(message.senderRole),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.message,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF8E8E93),
                  ),
                ),
                // Mostrar estado para mensajes propios
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(message.status, isMe),
                ],
              ],
            ),
            // Botón de reintentar si falló
            if (isMe &&
                message.status == MessageStatus.failed &&
                message.localId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => _retryMessage(message.localId!),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reintentar'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Construye el ícono de estado del mensaje con animación (Task 3.6)
  Widget _buildStatusIcon(MessageStatus status, bool isMe) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: _buildStatusIconContent(status, isMe),
    );
  }

  Widget _buildStatusIconContent(MessageStatus status, bool isMe) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          key: ValueKey('sending'),
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white70),
          ),
        );
      case MessageStatus.sent:
        return const Icon(
          key: ValueKey('sent'),
          Icons.check,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.delivered:
        return const Icon(
          key: ValueKey('delivered'),
          Icons.done_all,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.read:
        return const Icon(
          key: ValueKey('read'),
          Icons.done_all,
          size: 14,
          color: Color(0xFF34C759),
        );
      case MessageStatus.failed:
        return Icon(
          key: const ValueKey('failed'),
          Icons.error_outline,
          size: 14,
          color: Colors.red[300],
        );
    }
  }

  // Widget builders for UI components
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay mensajes aún',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inicia la conversación',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    return FloatingActionButton.small(
      onPressed: () => _scrollToBottom(force: true),
      backgroundColor: AppColors.primary,
      child: Badge(
        label: Text('${_unreadNewMessages}'),
        isLabelVisible: _unreadNewMessages > 0,
        child: const Icon(Icons.arrow_downward, color: Colors.white),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onTextChanged,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  // Helper functions for role badges
  String _getRoleBadgeText(String? role) {
    switch (role) {
      case 'client':
        return 'CLIENTE';
      case 'technician':
        return 'TÉCNICO';
      case 'workshop':
        return 'TALLER';
      case 'administrator':
      case 'admin':
        return 'ADMIN';
      default:
        return '';
    }
  }

  Color _getRoleBadgeColor(String? role) {
    switch (role) {
      case 'client':
        return const Color(0xFF3B82F6).withValues(alpha: 0.15);
      case 'technician':
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case 'workshop':
        return const Color(0xFFF59E0B).withValues(alpha: 0.15);
      case 'administrator':
      case 'admin':
        return const Color(0xFF8B5CF6).withValues(alpha: 0.15);
      default:
        return Colors.grey.withValues(alpha: 0.15);
    }
  }

  Color _getRoleBadgeTextColor(String? role) {
    switch (role) {
      case 'client':
        return const Color(0xFF1E40AF);
      case 'technician':
        return const Color(0xFF065F46);
      case 'workshop':
        return const Color(0xFF92400E);
      case 'administrator':
      case 'admin':
        return const Color(0xFF5B21B6);
      default:
        return Colors.grey[700]!;
    }
  }

  bool _isOfflineQueuedPayload(dynamic payload) {
    if (payload is! Map) return false;
    return payload['_offline_queued'] == true;
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final t = _controller.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final opacity = ((t * 3 - index) % 1.0).clamp(0.25, 1.0);
              return Opacity(
                opacity: opacity,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
