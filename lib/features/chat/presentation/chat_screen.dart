import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/data/models/message.dart';
import 'package:merchanic_repair/data/models/cancellation_request.dart';
import 'package:merchanic_repair/services/api_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

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
  bool _isSending = false;
  StreamSubscription? _wsSubscription;

  // Usuario actual
  int? _currentUserId;
  String? _currentUserRole; // 'client', 'workshop', 'technician'

  // Datos del incidente (para saber si es ambiguo)
  bool _isAmbiguous = false;

  // Cancelación mutua
  CancellationRequest? _pendingCancellation;
  bool _isLoadingCancellation = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWebSocket();
    _getCurrentUser();
    _loadIncidentInfo();
    _loadPendingCancellation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _wsSubscription?.cancel();
    super.dispose();
  }

  // ─── Carga de datos ───────────────────────────────────────────────────────

  Future<void> _getCurrentUser() async {
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

  Future<void> _loadMessages() async {
    if (mounted) setState(() => _isLoading = true);
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

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(data.map((j) => Message.fromJson(j)));
          // Invertir la lista para que el más reciente esté al final
          // Esto es necesario porque reverse: true en ListView muestra el último elemento abajo
          _messages.sort(
            (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar mensajes: $e')));
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
      final type = message['type'] as String?;
      final incidentId = message['incident_id'];

      if (incidentId != null && incidentId != widget.incidentId) return;

      if (type == 'new_message') {
        final msgData = message['message'];
        if (msgData != null) {
          setState(() {
            _messages.add(Message.fromJson(msgData as Map<String, dynamic>));
          });
          _scrollToBottom();
        }
      } else if (type == 'cancellation_request' ||
          type == 'cancellation_response') {
        // Recargar estado de cancelación cuando llega notificación WS
        _loadPendingCancellation();
      }
    });

    wsService.connect(
      '${ApiConfig.wsIncidents}/${widget.incidentId}',
      token: token,
    );
  }

  // ─── Envío de mensajes ────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.post(
        '${ApiConfig.chat}/incidents/${widget.incidentId}/messages',
        data: {'message': text},
      );
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al enviar mensaje: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Cancelación aceptada. El sistema buscará un nuevo taller.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          // Volver atrás después de un momento
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.of(context).pop();
          });
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Con reverse: true, la posición 0 es el final (mensajes más recientes)
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
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

  bool get _isOwnCancellationRequest =>
      _pendingCancellation?.requestedByUserId == _currentUserId;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Chat'),
            if (_isAmbiguous) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber[700],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'CASO AMBIGUO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Botón de cancelación mutua (siempre visible si no hay solicitud pendiente)
          if (_pendingCancellation == null)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _showCancellationDialog,
              tooltip: 'Solicitar cancelación',
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
        ],
      ),
      body: Column(
        children: [
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
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    reverse:
                        true, // Invertir para que los nuevos aparezcan abajo
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      // Con reverse: true, el índice 0 es el último mensaje
                      final msg = _messages[index];
                      final isMe = msg.senderId == _currentUserId;
                      final isSystem = msg.type == 'system';
                      if (isSystem) return _buildSystemMessage(msg);
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),

          // ── Input ──
          _buildInput(),
        ],
      ),
    );
  }

  // ─── Widgets de cancelación ───────────────────────────────────────────────

  Widget _buildAmbiguousNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
        ),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Caso Ambiguo Detectado',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Usa el chat para coordinar detalles. Si no se puede resolver, solicita cancelación mutua.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _showCancellationDialog,
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('Solicitar Cancelación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
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

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.senderName!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            Text(
              message.message,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay mensajes aún',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inicia la conversación enviando un mensaje',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
