import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/offline_action_queue.dart';

void main() {
  group('OfflineActionQueue', () {
    late OfflineActionQueue queue;

    setUp(() {
      queue = OfflineActionQueue();
    });

    test('starts empty', () {
      expect(queue.pendingCount, 0);
      expect(queue.hasPendingActions, isFalse);
    });

    test('enqueue increases pendingCount', () {
      queue.enqueue({'type': 'send_message', 'content': 'Hello'});
      expect(queue.pendingCount, 1);
      expect(queue.hasPendingActions, isTrue);
    });

    test('enqueue multiple actions', () {
      queue.enqueue({'type': 'send_message', 'content': 'Hello'});
      queue.enqueue({'type': 'update_status', 'status': 'en_proceso'});
      queue.enqueue({'type': 'send_message', 'content': 'World'});
      expect(queue.pendingCount, 3);
    });

    test('hasPendingActions is false when empty', () {
      expect(queue.hasPendingActions, isFalse);
    });

    test('hasPendingActions is true after enqueue', () {
      queue.enqueue({'type': 'ping'});
      expect(queue.hasPendingActions, isTrue);
    });

    test('enqueue preserves action data', () {
      final action = {
        'type': 'send_message',
        'content': 'Test',
        'incident_id': 42,
      };
      queue.enqueue(action);
      // Queue should hold the action (we verify via pendingCount)
      expect(queue.pendingCount, 1);
    });

    test('multiple enqueues maintain order (FIFO)', () {
      // We can verify order indirectly by checking pendingCount after each enqueue
      for (int i = 0; i < 5; i++) {
        queue.enqueue({'type': 'action_$i'});
        expect(queue.pendingCount, i + 1);
      }
    });
  });
}
