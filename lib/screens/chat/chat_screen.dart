import 'package:flutter/material.dart';
import 'dart:async';
import 'package:merchanic_repair/data/models/message.dart';
import 'package:merchanic_repair/data/models/incident.dart';
import 'package:merchanic_repair/data/models/cancellation_request.dart';
import 'package:merchanic_repair/services/chat_service.dart';
import 'package:merchanic_repair/services/cancellation_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/shared/widgets/message_bubble.dart';
import 'package:merchanic_repair/shared/widgets/chat_input.dart';
import 'package:merchanic_repair/shared/widgets/ambiguous_case_notice.dart';
import 'package:merchanic_repair/shared/widgets/cancellation_request_card.dart';
import 'package:merchanic_repair/shared/widgets/cancellation_dialog.dart';
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

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final CancellationService _cancellationService = CancellationService();
  final WebSocketService _wsService = WebSocketService();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  CancellationRequest? _pendingCancellation;
  bool _isLoadingCancellation = false;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadPendingCancellation();
    _connectWebSocket();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _wsSubscription?.cancel();
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
        messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
        _messages.addAll(messages);
        _isLoading = false;
      });

      _scrollToBottom();
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
        if (message.senderId != widget.currentUserId) {
          _markAsRead();
        }
      }
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final message = Message.fromJson(data);

      // Avoid duplicates
      if (!_messages.any((m) => m.id == message.id)) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();

        // Mark as read if not from current user
        if (message.senderId != widget.currentUserId) {
          _markAsRead();
        }

        debugPrint('✅ New message received: ${message.message}');
      }
    } catch (e) {
      debugPrint('Error handling incoming message: $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final message = await _chatService.sendMessage(
        widget.token,
        widget.incidentId,
        text.trim(),
      );

      setState(() {
        _messages.add(message);
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      _showError('Error al enviar mensaje: $e');
    }
  }

  Future<void> _markAsRead() async {
    try {
      await _chatService.markAsRead(widget.token, widget.incidentId);
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF007AFF)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.otherPartyName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.incident.esAmbiguo) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AMBIGUO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
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
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF8E8E93),
                ),
              ),
          ],
        ),
        actions: [
          // Ícono discreto de cancelación (disponible en todos los casos)
          if (_pendingCancellation == null)
            IconButton(
              icon: const Icon(
                Icons.cancel_outlined,
                color: Color(0xFFFF3B30),
                size: 22,
              ),
              tooltip: 'Solicitar cancelación del servicio',
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
            child: _isLoading
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
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == widget.currentUserId;

                      return MessageBubble(message: message, isMe: isMe);
                    },
                  ),
          ),

          // Input area
          ChatInput(onSend: _sendMessage, enabled: !_isSending),
        ],
      ),
    );
  }
}
