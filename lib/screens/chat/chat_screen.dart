import 'package:flutter/material.dart';
import 'dart:async';
import 'package:merchanic_repair/data/models/message.dart';
import 'package:merchanic_repair/data/models/message_status.dart';
import 'package:merchanic_repair/data/models/incident.dart';
import 'package:merchanic_repair/data/models/cancellation_request.dart';
import 'package:merchanic_repair/data/cache/chat_cache.dart';
import 'package:merchanic_repair/services/chat_service.dart';
import 'package:merchanic_repair/services/cancellation_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';
import 'package:merchanic_repair/shared/widgets/chat_input.dart';
import 'package:merchanic_repair/shared/widgets/ambiguous_case_notice.dart';
import 'package:merchanic_repair/shared/widgets/cancellation_request_card.dart';
import 'package:merchanic_repair/shared/widgets/cancellation_dialog.dart';
import 'package:merchanic_repair/shared/widgets/scroll_to_bottom_button.dart';
import 'package:merchanic_repair/screens/chat/chat_screen_helpers.dart';
import 'package:merchanic_repair/core/config/api_config.dart';

class ChatScreen extends StatefulWidget {
  final int incidentId;
  final String token;
  final int currentUserId;
  final String currentUserRole; // 'client' or 'workshop'
  final String otherPartyName;
  final Incident incident;

  const ChatScreen({
    Key? key,
    required this.incidentId,
    required this.token,
    required this.currentUserId,
    required this.currentUserRole,
    required this.otherPartyName,
    required this.incident,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with ChatScreenHelpers, SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final CancellationService _cancellationService = CancellationService();
  final ChatCache _cache = ChatCache();
  late final WebSocketService _wsService = WebSocketService(StorageService());
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  bool _isLoading = true;
  bool _isTyping = false;
  bool _isUserAtBottom = true;
  int _unreadNewMessages = 0;
  CancellationRequest? _pendingCancellation;
  bool _isLoadingCancellation = false;

  // Optimización de markAsRead
  final Set<int> _pendingReadMessages = {};
  final Set<int> _alreadyReadMessages = {};
  Timer? _markAsReadTimer;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _connectionSubscription;

  // Implementación de getters requeridos por ChatScreenHelpers
  @override
  List<Message> get messages => _messages;

  @override
  int get currentUserId => widget.currentUserId;

  @override
  Function(String) get onRetryMessage => _retryMessage;

  @override
  void initState() {
    super.initState();
    _initializeCache();
    _loadMessagesWithCache();
    _loadPendingCancellation();
    _connectWebSocket();
    _scrollController.addListener(_onScroll);
  }

  /// Listener del scroll para detectar posición del usuario
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final isAtBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;

    if (isAtBottom != _isUserAtBottom) {
      setState(() {
        _isUserAtBottom = isAtBottom;
        if (isAtBottom) {
          _unreadNewMessages = 0;
        }
      });
    }
  }

  /// Inicializar cache
  Future<void> _initializeCache() async {
    try {
      await _cache.init();
    } catch (e) {
      debugPrint('❌ Error initializing cache: $e');
      // Continuar sin cache
    }
  }

  /// Cargar mensajes con estrategia cache-first
  Future<void> _loadMessagesWithCache() async {
    try {
      // 1. Cargar desde cache primero (rápido)
      if (_cache.isInitialized) {
        final cachedMessages = await _cache.getMessages(widget.incidentId);
        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          cachedMessages.sort(
            (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            ),
          );
          setState(() {
            _messages.clear();
            _messages.addAll(cachedMessages);
            _isLoading = false;
          });
          _scrollToBottom(animated: false);
          debugPrint('✅ Loaded ${cachedMessages.length} messages from cache');
        }
      }

      // 2. Sincronizar con el servidor
      // Si hay mensajes en cache, hacer sync incremental; si no, cargar todo
      final lastMessageId = _messages.isNotEmpty ? _messages.last.id : null;

      List<Message> serverMessages;
      if (lastMessageId != null) {
        serverMessages = await _chatService.getMessagesSince(
          widget.token,
          widget.incidentId,
          sinceMessageId: lastMessageId,
        );
      } else {
        serverMessages = await _chatService.getMessages(
          widget.token,
          widget.incidentId,
        );
      }

      if (serverMessages.isNotEmpty) {
        setState(() {
          for (final message in serverMessages) {
            if (!_messages.any((m) => m.id == message.id)) {
              _messages.add(message);
            }
          }
          _messages.sort(
            (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            ),
          );
          _isLoading = false;
        });

        // Guardar en cache
        if (_cache.isInitialized) {
          for (final message in serverMessages) {
            await _cache.addMessage(widget.incidentId, message);
          }
        }

        _scrollToBottom(animated: false);
        debugPrint('✅ Synced ${serverMessages.length} messages from server');
      } else {
        setState(() => _isLoading = false);
      }

      // Marcar mensajes como leídos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markVisibleMessagesAsRead();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌ Error loading messages: $e');
      if (_messages.isEmpty) {
        _showError('Error al cargar mensajes: $e');
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _wsSubscription?.cancel();
    _connectionSubscription?.cancel();
    _markAsReadTimer?.cancel();
    _wsService.disconnect();
    _scrollController.dispose();
    _cancellationService.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _isLoading = true);

      final messages = await _chatService.getMessages(
        widget.token,
        widget.incidentId,
      );

      setState(() {
        _messages.clear();
        // Ordenar mensajes por fecha (más antiguos primero, como WhatsApp)
        messages.sort(
          (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
            b.createdAt ?? DateTime.now(),
          ),
        );
        _messages.addAll(messages);
        _isLoading = false;
      });

      _scrollToBottom();

      // Marcar mensajes como leídos después de cargar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markVisibleMessagesAsRead();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar mensajes: $e');
    }
  }

  void _connectWebSocket() {
    // ✅ Conectar al WebSocket del incidente
    _wsService.connect(
      '${ApiConfig.wsIncidents}/${widget.incidentId}',
      token: widget.token,
    );

    // ✅ Escuchar estado de conexión para resincronizar tras reconexión
    _connectionSubscription = _wsService.connectionStatus.listen((status) {
      debugPrint('🔌 WebSocket status changed: $status');

      if (status.toString().contains('connected') &&
          !status.toString().contains('disconnected')) {
        // Reconectado — sincronizar mensajes perdidos
        debugPrint('✅ WebSocket reconnected — syncing messages');
        _syncAfterReconnection();
      }
    });

    // ✅ Escuchar mensajes del WebSocket
    _wsSubscription = _wsService.messages.listen((message) {
      if (message['type'] == 'new_message' &&
          message['data'] != null &&
          message['data']['incident_id'] == widget.incidentId) {
        _handleIncomingMessage(message['data']);
      } else if (message['type'] == 'typing' &&
          message['incident_id'] == widget.incidentId &&
          message['user_id'] != widget.currentUserId) {
        setState(() {
          _isTyping = message['is_typing'] ?? false;
        });
      }
    });

    // Listen to chat service stream
    _messageSubscription = _chatService.messagesStream.listen((message) {
      if (message.incidentId == widget.incidentId) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();

        // Mark as read if not from current user
        if (message.senderId != widget.currentUserId && message.id != null) {
          _scheduleMarkAsRead(message.id!);
        }
      }
    });
  }

  /// Sincronizar mensajes después de reconexión WebSocket
  Future<void> _syncAfterReconnection() async {
    try {
      final lastMessageId = _messages.isNotEmpty ? _messages.last.id : null;

      if (lastMessageId == null) {
        // No hay mensajes locales, cargar todos
        debugPrint('📥 No local messages, loading all');
        await _loadMessagesWithCache();
        return;
      }

      // Pedir solo mensajes nuevos desde el último conocido
      debugPrint('📥 Syncing messages since ID: $lastMessageId');
      final newMessages = await _chatService.getMessagesSince(
        widget.token,
        widget.incidentId,
        sinceMessageId: lastMessageId,
      );

      if (newMessages.isNotEmpty) {
        setState(() {
          for (final message in newMessages) {
            if (!_messages.any((m) => m.id == message.id)) {
              _messages.add(message);
            }
          }
          _messages.sort(
            (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            ),
          );
        });

        // Guardar en cache
        if (_cache.isInitialized) {
          for (final message in newMessages) {
            await _cache.addMessage(widget.incidentId, message);
          }
        }

        // Solo hacer scroll si el usuario está abajo
        if (_isUserAtBottom) {
          _scrollToBottom();
        } else {
          // Incrementar contador de no leídos
          setState(() {
            _unreadNewMessages += newMessages.length;
          });
        }

        debugPrint(
          '✅ Synced ${newMessages.length} messages after reconnection',
        );
      } else {
        debugPrint('✅ No new messages to sync');
      }
    } catch (e) {
      debugPrint('❌ Error syncing after reconnection: $e');
      // No mostrar error al usuario, es una operación en segundo plano
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final message = Message.fromJson(data);

      // Avoid duplicates
      if (!_messages.any((m) => m.id == message.id)) {
        setState(() {
          _messages.add(message);

          // Incrementar contador de no leídos si usuario no está abajo
          if (!_isUserAtBottom && message.senderId != widget.currentUserId) {
            _unreadNewMessages++;
          }
        });

        // Animar inserción si AnimatedList está inicializado
        if (_listKey.currentState != null) {
          _listKey.currentState!.insertItem(
            _getItemCount() - 1,
            duration: const Duration(milliseconds: 300),
          );
        }

        // Guardar en cache
        if (_cache.isInitialized) {
          _cache.addMessage(widget.incidentId, message);
        }

        // Solo hacer scroll automático si el usuario está abajo
        if (_isUserAtBottom) {
          _scrollToBottom();
        }

        // Mark as read if not from current user
        if (message.senderId != widget.currentUserId && message.id != null) {
          _scheduleMarkAsRead(message.id!);
        }

        debugPrint('✅ New message received: ${message.message}');
      }
    } catch (e) {
      debugPrint('Error handling incoming message: $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Crear mensaje temporal para envío optimista
    final tempMessage = Message.temporary(
      incidentId: widget.incidentId,
      senderId: widget.currentUserId,
      senderName: 'Tú',
      messageText: text.trim(),
    );

    // 2. Agregar mensaje temporal a la lista INMEDIATAMENTE
    setState(() {
      _messages.add(tempMessage);
    });

    // Animar inserción
    if (_listKey.currentState != null) {
      _listKey.currentState!.insertItem(
        _getItemCount() - 1,
        duration: const Duration(milliseconds: 250),
      );
    }

    // Guardar en cache inmediatamente
    if (_cache.isInitialized) {
      await _cache.addMessage(widget.incidentId, tempMessage);
    }

    // 3. Scroll automático
    _scrollToBottom();

    // 4. Enviar al backend en segundo plano
    try {
      final sentMessage = await _chatService.sendMessage(
        widget.token,
        widget.incidentId,
        text.trim(),
      );

      // 5. Reemplazar mensaje temporal con mensaje del servidor
      setState(() {
        final index = _messages.indexWhere(
          (m) => m.localId == tempMessage.localId,
        );

        if (index != -1) {
          _messages[index] = sentMessage.copyWith(
            status: MessageStatus.sent,
            sentAt: DateTime.now(),
          );
        }
      });

      debugPrint('✅ Mensaje enviado: ${sentMessage.id}');
    } catch (e) {
      // 6. Marcar mensaje como fallido
      setState(() {
        final index = _messages.indexWhere(
          (m) => m.localId == tempMessage.localId,
        );

        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            status: MessageStatus.failed,
            errorMessage: e.toString(),
          );
        }
      });

      debugPrint('❌ Error al enviar mensaje: $e');

      // Mostrar snackbar discreto
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo enviar el mensaje'),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: () => _retryMessage(tempMessage.localId!),
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
      final sentMessage = await _chatService.sendMessage(
        widget.token,
        widget.incidentId,
        failedMessage.message,
      );

      setState(() {
        _messages[messageIndex] = sentMessage.copyWith(
          status: MessageStatus.sent,
          sentAt: DateTime.now(),
        );
      });

      debugPrint('✅ Mensaje reenviado: ${sentMessage.id}');
    } catch (e) {
      setState(() {
        _messages[messageIndex] = failedMessage.copyWith(
          status: MessageStatus.failed,
          errorMessage: e.toString(),
        );
      });

      _showError('Error al reenviar mensaje: $e');
    }
  }

  /// Marcar mensajes visibles como leídos al abrir el chat
  void _markVisibleMessagesAsRead() {
    for (final message in _messages) {
      if (message.id != null &&
          message.senderId != widget.currentUserId &&
          !(message.isRead ?? false)) {
        _scheduleMarkAsRead(message.id!);
      }
    }
  }

  /// Programar marcado de mensaje como leído (con debounce)
  void _scheduleMarkAsRead(int messageId) {
    // No marcar mensajes propios
    final message = _messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => _messages.first,
    );
    if (message.senderId == widget.currentUserId) return;

    // No marcar si ya está leído
    if (_alreadyReadMessages.contains(messageId)) return;

    // Agregar a pendientes
    _pendingReadMessages.add(messageId);

    // Cancelar timer anterior
    _markAsReadTimer?.cancel();

    // Crear nuevo timer con debounce de 1 segundo
    _markAsReadTimer = Timer(const Duration(seconds: 1), () {
      _flushPendingReadMessages();
    });
  }

  /// Enviar mensajes pendientes al backend
  Future<void> _flushPendingReadMessages() async {
    if (_pendingReadMessages.isEmpty) return;

    final messageIds = _pendingReadMessages.toList();
    _pendingReadMessages.clear();

    try {
      // Usar el método existente que marca todo el incidente
      // TODO: Cuando backend tenga endpoint batch, usar markMessagesAsReadBatch
      await _chatService.markAsRead(widget.token, widget.incidentId);

      // Marcar como leídos localmente
      _alreadyReadMessages.addAll(messageIds);

      // Actualizar estado local
      setState(() {
        for (final messageId in messageIds) {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              isRead: true,
              readAt: DateTime.now(),
              status: MessageStatus.read,
            );
          }
        }
      });

      debugPrint('✅ Marked ${messageIds.length} messages as read');
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
      // Volver a agregar a pendientes para reintentar
      _pendingReadMessages.addAll(messageIds);
    }
  }

  void _scrollToBottom({bool animated = true, bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Solo hacer scroll si el usuario está abajo o es forzado
        if (_isUserAtBottom || force) {
          if (animated) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        }
      }
    });
  }

  /// Métodos delegados al mixin ChatScreenHelpers
  int _getItemCount() => getItemCount();

  Widget _buildItem(int index) => buildItem(index);

  // ==================== CANCELLATION METHODS ====================

  /// Load pending cancellation request
  Future<void> _loadPendingCancellation() async {
    try {
      final cancellation = await _cancellationService.getPendingCancellation(
        incidentId: widget.incidentId,
        token: widget.token,
      );

      if (mounted) {
        setState(() {
          _pendingCancellation = cancellation;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending cancellation: $e');
    }
  }

  /// Show cancellation dialog
  Future<void> _showCancellationDialog() async {
    final receiverName = widget.currentUserRole == 'client'
        ? 'el taller'
        : 'el cliente';

    showDialog(
      context: context,
      builder: (context) => CancellationDialog(
        receiverName: receiverName,
        onConfirm: _requestCancellation,
      ),
    );
  }

  /// Request cancellation
  Future<void> _requestCancellation(String reason) async {
    try {
      final cancellation = await _cancellationService.requestCancellation(
        incidentId: widget.incidentId,
        reason: reason,
        token: widget.token,
      );

      if (mounted) {
        setState(() {
          _pendingCancellation = cancellation;
        });

        // Add system message
        _addSystemMessage('📋 Solicitud de cancelación enviada: $reason');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud enviada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show success dialog and redirect to incidents list
  void _showSuccessDialogAndRedirect() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated checkmark
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 64,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Cancelación Aceptada',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'El sistema buscará un nuevo taller automáticamente.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Redirigiendo a la lista de incidencias...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Redirect after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pop(); // Close chat screen
        // The user will be back at the incidents list
      }
    });
  }

  /// Respond to cancellation request
  Future<void> _respondToCancellation(bool accept) async {
    if (_pendingCancellation == null) return;

    setState(() {
      _isLoadingCancellation = true;
    });

    try {
      final responseMessage = accept
          ? 'Acepto cancelar el servicio'
          : 'No acepto cancelar el servicio';

      await _cancellationService.respondToCancellation(
        requestId: _pendingCancellation!.id,
        accept: accept,
        responseMessage: responseMessage,
        token: widget.token,
      );

      if (mounted) {
        setState(() {
          _isLoadingCancellation = false;
        });

        if (accept) {
          _addSystemMessage(
            '✅ Cancelación aceptada. El sistema buscará un nuevo taller automáticamente.',
          );

          // Mostrar diálogo de éxito y redirigir
          _showSuccessDialogAndRedirect();
        } else {
          _addSystemMessage(
            '❌ Cancelación rechazada. El servicio continúa normalmente.',
          );

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _pendingCancellation = null;
              });
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCancellation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Add system message to chat
  void _addSystemMessage(String messageText) {
    final systemMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch,
      incidentId: widget.incidentId,
      senderId: 0, // System message
      message: messageText,
      type: 'system',
      isRead: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(systemMessage);
    });

    _scrollToBottom();
  }

  // ==================== END CANCELLATION METHODS ====================

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // Fondo iOS
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF007AFF),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
        ),
        title: Row(
          children: [
            // Avatar circular con inicial
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
              child: Text(
                widget.otherPartyName.isNotEmpty
                    ? widget.otherPartyName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.otherPartyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.incident.esAmbiguo) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AMBIGUO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_isTyping)
                    const Text(
                      'escribiendo...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_pendingCancellation == null)
            IconButton(
              icon: const Icon(
                Icons.cancel_outlined,
                color: Color(0xFFFF3B30),
                size: 22,
              ),
              tooltip: 'Solicitar cancelación',
              onPressed: _showCancellationDialog,
            ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF007AFF),
              size: 22,
            ),
            onPressed: _loadMessages,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
        ),
      ),
      body: Column(
        children: [
          // Ambiguous case notice (solo para casos ambiguos y sin cancelación pendiente)
          if (widget.incident.esAmbiguo && _pendingCancellation == null)
            AmbiguousCaseNotice(onRequestCancellation: _showCancellationDialog),

          // Pending cancellation request card
          if (_pendingCancellation != null)
            CancellationRequestCard(
              cancellationRequest: _pendingCancellation!,
              isOwnRequest:
                  _pendingCancellation!.requestedByUserId ==
                  widget.currentUserId,
              onAccept: () => _respondToCancellation(true),
              onReject: () => _respondToCancellation(false),
              isLoading: _isLoadingCancellation,
            ),

          // Messages list
          Expanded(
            child: Stack(
              children: [
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF007AFF),
                          strokeWidth: 2,
                        ),
                      )
                    : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 64,
                              color: Colors.grey.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay mensajes aún',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Envía un mensaje para iniciar la conversación',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _getItemCount(),
                        itemBuilder: (context, index) {
                          return _buildItem(index);
                        },
                      ),

                // Botón flotante para bajar
                if (!_isUserAtBottom)
                  ScrollToBottomButton(
                    onPressed: () {
                      _scrollToBottom(force: true);
                      setState(() {
                        _unreadNewMessages = 0;
                      });
                    },
                    unreadCount: _unreadNewMessages,
                  ),
              ],
            ),
          ),

          // Input area
          ChatInput(onSend: _sendMessage),
        ],
      ),
    );
  }
}
