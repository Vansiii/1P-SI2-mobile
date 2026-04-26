# Chat Real-Time Features

This directory contains the implementation of real-time chat features for the mobile application, including typing indicators and message delivery/read status.

## Tasks Completed

### Task 2.1: chat.user_typing
- ✅ Send typing indicator when user starts typing
- ✅ Display "Usuario escribiendo..." indicator
- ✅ Automatic 3-second timeout
- ✅ Integration with backend API endpoint

### Task 2.2: chat.user_stopped_typing
- ✅ Send stop typing indicator after 3-second timeout
- ✅ Hide typing indicator
- ✅ Cancel typing timer on message send

### Task 2.3: chat.message_delivered
- ✅ Show single check mark (✓) for delivered messages
- ✅ Subscribe to chat.message_delivered events
- ✅ Update message status in UI

### Task 2.4: chat.message_read
- ✅ Call backend endpoint when message becomes visible
- ✅ Show double check mark (✓✓) for read messages
- ✅ Blue color for read status
- ✅ Subscribe to chat.message_read events

## Architecture

### Services

#### `ChatRealtimeService`
Main service for handling real-time chat events.

**Responsibilities:**
- Subscribe to all chat.* events from EventDispatcherService
- Manage typing indicators with 3-second timeout
- Update message delivery/read status
- Call backend API to mark messages as read
- Integrate with ChatRealtimeNotifier for UI updates

**Key Methods:**
- `sendTypingIndicator(incidentId)` - Send typing indicator to backend
- `sendTypingStopIndicator(incidentId)` - Send stop typing indicator
- `markMessageAsRead(messageId)` - Mark message as read
- `getTypingIndicatorText(incidentId)` - Get formatted typing text
- `getMessageStatusIcon(status)` - Get status icon (✓ or ✓✓)

### Providers

#### `chatRealtimeServiceProvider`
Provider for ChatRealtimeService with automatic initialization and cleanup.

#### `chatRealtimeProvider`
Existing provider for ChatRealtimeNotifier that manages chat state.

### Widgets

#### `ChatTypingIndicatorWidget`
Displays typing indicators for other users in the chat.

**Usage:**
```dart
ChatTypingIndicatorWidget(incidentId: incidentId)
```

#### `MessageStatusWidget`
Displays delivery/read status for messages.

**Usage:**
```dart
MessageStatusWidget(
  messageId: message.id,
  incidentId: incidentId,
)
```

## Integration with Chat Screen

The `ChatScreen` has been updated to:

1. **Typing Indicators:**
   - Call `sendTypingIndicator()` when user starts typing
   - Set up 3-second timer to auto-send stop indicator
   - Display typing indicator above input field
   - Cancel timer when message is sent

2. **Message Status:**
   - Display ✓ for delivered messages
   - Display ✓✓ (blue) for read messages
   - Automatically mark messages as read when visible
   - Update status in real-time via WebSocket events

## Backend API Endpoints

### Typing Indicators
- `POST /api/v1/chat/incidents/{incident_id}/typing` - Send typing indicator
- `POST /api/v1/chat/incidents/{incident_id}/typing/stop` - Send stop typing

### Message Read Receipts
- `POST /api/v1/chat/messages/{message_id}/read` - Mark message as read

## WebSocket Events

### Subscribed Events
- `chat.user_typing` - User started typing
- `chat.user_stopped_typing` - User stopped typing
- `chat.message_delivered` - Message delivered to recipient
- `chat.message_read` - Message read by recipient

### Event Flow

#### Typing Indicator Flow
1. User types in input field
2. `_onTextChanged()` called
3. `sendTypingIndicator()` sends HTTP request
4. Backend emits `chat.user_typing` event
5. EventDispatcher routes to ChatRealtimeNotifier
6. UI updates to show typing indicator
7. After 3 seconds, `sendTypingStopIndicator()` called
8. Backend emits `chat.user_stopped_typing` event
9. UI hides typing indicator

#### Message Read Flow
1. Message becomes visible in ListView
2. `markMessageAsRead()` called
3. HTTP request to backend
4. Backend updates message.read_at
5. Backend emits `chat.message_read` event
6. EventDispatcher routes to ChatRealtimeNotifier
7. Message status updated to `read`
8. UI shows ✓✓ (blue)

## Message Status States

```dart
enum ChatMessageStatus {
  sending,   // Message being sent (no icon)
  sent,      // Message sent (✓)
  delivered, // Message delivered (✓)
  read,      // Message read (✓✓ blue)
}
```

## Example Usage

### In a Chat Screen

```dart
class MyChatScreen extends ConsumerStatefulWidget {
  final int incidentId;
  
  @override
  ConsumerState<MyChatScreen> createState() => _MyChatScreenState();
}

class _MyChatScreenState extends ConsumerState<MyChatScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _typingTimer;
  bool _isTyping = false;

  void _onTextChanged(String text) {
    final service = ref.read(chatRealtimeServiceProvider);
    
    if (text.trim().isNotEmpty && !_isTyping) {
      _isTyping = true;
      service.sendTypingIndicator(widget.incidentId);
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        service.sendTypingStopIndicator(widget.incidentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages list
        Expanded(child: MessagesList()),
        
        // Typing indicator
        ChatTypingIndicatorWidget(incidentId: widget.incidentId),
        
        // Input field
        TextField(
          controller: _controller,
          onChanged: _onTextChanged,
        ),
      ],
    );
  }
}
```

### Displaying Message Status

```dart
Widget buildMessage(Message message, bool isMe) {
  return Row(
    children: [
      Text(message.content),
      if (isMe)
        MessageStatusWidget(
          messageId: message.id,
          incidentId: message.incidentId,
        ),
    ],
  );
}
```

## Testing

### Manual Testing Checklist

- [ ] Typing indicator appears when user types
- [ ] Typing indicator disappears after 3 seconds
- [ ] Typing indicator disappears when message sent
- [ ] Multiple users typing shows correctly
- [ ] Message shows ✓ when delivered
- [ ] Message shows ✓✓ (blue) when read
- [ ] Read receipts work for multiple messages
- [ ] Typing indicators work in multiple chats

### Edge Cases Handled

1. **Multiple typing users:** Shows "Varios usuarios están escribiendo..."
2. **Rapid typing:** Timer resets on each keystroke
3. **Message send during typing:** Timer cancelled, stop indicator sent
4. **Offline messages:** Queued and sent when reconnected
5. **Duplicate events:** Deduplicated by message ID

## Performance Considerations

- Typing indicators are ephemeral (not persisted)
- 3-second debounce prevents excessive API calls
- Message status updates are batched via WebSocket
- Timers are properly cancelled on dispose
- Event subscriptions cleaned up on unmount

## Future Enhancements

- [ ] Voice message support
- [ ] File upload with progress
- [ ] Message reactions
- [ ] Message editing
- [ ] Message deletion with sync
- [ ] Offline message queue with retry
- [ ] Push notifications for new messages
- [ ] Unread message count badge

## Related Files

- `services/chat_realtime_service.dart` - Main service
- `providers/chat_realtime_provider.dart` - State management
- `presentation/chat_screen.dart` - UI implementation
- `widgets/chat_typing_indicator_widget.dart` - Typing indicator
- `widgets/message_status_widget.dart` - Message status
- `../../core/models/realtime_event.dart` - Event definitions
- `../../core/services/event_dispatcher_service.dart` - Event routing
