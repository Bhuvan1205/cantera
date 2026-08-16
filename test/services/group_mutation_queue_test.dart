
import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/user_console/services/group_mutation_queue.dart';

void main() {
  group('GroupMutationQueue', () {
    late GroupMutationQueue queue;

    setUp(() {
      queue = GroupMutationQueue(groupId: 'test-group-1');
    });

    // Test 1: Group + enqueues and resolves.
    test('1: single successful add completes without rollback', () async {
      var callCount = 0;
      var rollbackCount = 0;

      await queue.enqueue(
        work: () async {
          callCount++;
        },
        onRollback: (_) => rollbackCount++,
      );

      expect(callCount, 1);
      expect(rollbackCount, 0);
    });

    // Test 2: Failed mutation calls rollback.
    test('2: failed mutation triggers rollback with message', () async {
      String? capturedMessage;
      var rollbackCalled = false;

      await queue.enqueue(
        work: () async {
          throw Exception('StatusCode 500: Server error');
        },
        onRollback: (msg) {
          rollbackCalled = true;
          capturedMessage = msg;
        },
      );

      expect(rollbackCalled, true);
      expect(capturedMessage, contains('Server error'));
    });

    // Test 3: Multiple successful mutations execute sequentially.
    test('3: rapid + + + + all execute in order', () async {
      final executionOrder = <int>[];

      for (var i = 1; i <= 4; i++) {
        final captured = i;
        queue.enqueue(
          work: () async => executionOrder.add(captured),
          onRollback: (_) {},
        );
      }

      // Wait for the entire chain to settle.
      await queue.enqueue(work: () async {}, onRollback: (_) {});

      expect(executionOrder, [1, 2, 3, 4]);
    });

    // Test 4: Fatal error halts queue; subsequent work calls rollback.
    test('4: 409 halts queue and subsequent mutations rollback immediately', () async {
      final rollbacks = <String>[];

      // Op 1: halting error (409 PAYING)
      queue.enqueue(
        work: () async {
          throw Exception('StatusCode 409: Group is not open for changes.');
        },
        onRollback: (msg) => rollbacks.add('op1: $msg'),
      );

      // Ops 2, 3: should be immediately rolled back after queue halts.
      queue.enqueue(
        work: () async => rollbacks.add('op2 executed (SHOULD NOT HAPPEN)'),
        onRollback: (msg) => rollbacks.add('op2 rolled back'),
      );
      queue.enqueue(
        work: () async => rollbacks.add('op3 executed (SHOULD NOT HAPPEN)'),
        onRollback: (msg) => rollbacks.add('op3 rolled back'),
      );

      // Settle the chain.
      await queue.enqueue(work: () async {}, onRollback: (_) {});

      expect(queue.isHalted, true);
      expect(rollbacks.any((r) => r.startsWith('op1')), true);
      expect(rollbacks.any((r) => r == 'op2 rolled back'), true);
      expect(rollbacks.any((r) => r == 'op3 rolled back'), true);
      expect(rollbacks.any((r) => r.contains('SHOULD NOT HAPPEN')), false);
    });

    // Test 5: Transient error (500) does NOT halt the queue.
    test('5: 500 error is transient and queue continues', () async {
      var op2Called = false;

      // Op 1: transient 500 error
      queue.enqueue(
        work: () async => throw Exception('StatusCode 500: Internal server error'),
        onRollback: (_) {},
      );

      // Op 2: should still execute (queue not halted by 500)
      queue.enqueue(
        work: () async => op2Called = true,
        onRollback: (_) {},
      );

      await queue.enqueue(work: () async {}, onRollback: (_) {});

      expect(queue.isHalted, false);
      expect(op2Called, true);
    });

    // Test 6: Rollback is precise - only the failed op rolls back.
    test('6: precise rollback - only op 2 rolls back out of 4 operations', () async {
      // Simulates: + + + + where op 2 fails.
      // The other 3 should succeed without rollback.
      var rollbackCount = 0;
      final successes = <int>[];

      queue.enqueue(
        work: () async => successes.add(1),
        onRollback: (_) => rollbackCount++,
      );
      queue.enqueue(
        work: () async => throw Exception('StatusCode 500: transient'),
        onRollback: (_) => rollbackCount++,
      );
      queue.enqueue(
        work: () async => successes.add(3),
        onRollback: (_) => rollbackCount++,
      );
      queue.enqueue(
        work: () async => successes.add(4),
        onRollback: (_) => rollbackCount++,
      );

      await queue.enqueue(work: () async {}, onRollback: (_) {});

      // Exactly 1 rollback (for op 2 only).
      expect(rollbackCount, 1);
      // Ops 1, 3, 4 succeeded.
      expect(successes, [1, 3, 4]);
    });

    // Test 7: Decrement-then-remove ordering preserved.
    test('7: + - ordering is preserved', () async {
      final ops = <String>[];

      queue.enqueue(
        work: () async => ops.add('add'),
        onRollback: (_) {},
      );
      queue.enqueue(
        work: () async => ops.add('remove'),
        onRollback: (_) {},
      );

      await queue.enqueue(work: () async {}, onRollback: (_) {});

      expect(ops, ['add', 'remove']);
    });

    // Test 8: Queue halted from the start rejects immediately.
    test('8: pre-halted queue rejects immediately', () async {
      queue.halt();
      var rollbackCalled = false;

      queue.enqueue(
        work: () async {},
        onRollback: (_) => rollbackCalled = true,
      );

      await queue.enqueue(work: () async {}, onRollback: (_) {});

      expect(rollbackCalled, true);
    });
  });

  group('GroupMutationQueueRegistry', () {
    setUp(() {
      // Clean state between tests.
      GroupMutationQueueRegistry.instance.disposeAll();
    });

    // Test 9: Different groups get independent queues.
    test('9: different groupIds have independent queues', () {
      final q1 = GroupMutationQueueRegistry.instance.queueFor('group-A');
      final q2 = GroupMutationQueueRegistry.instance.queueFor('group-B');
      expect(q1, isNot(same(q2)));
    });

    // Test 10: Same groupId returns same queue.
    test('10: same groupId returns the same queue instance', () {
      final q1 = GroupMutationQueueRegistry.instance.queueFor('group-X');
      final q2 = GroupMutationQueueRegistry.instance.queueFor('group-X');
      expect(q1, same(q2));
    });

    // Test 11: dispose halts and removes queue.
    test('11: dispose halts queue for that group', () async {
      final q = GroupMutationQueueRegistry.instance.queueFor('group-D');
      GroupMutationQueueRegistry.instance.dispose('group-D');
      expect(q.isHalted, true);
    });

    // Test 12: disposeAll cleans everything.
    test('12: disposeAll halts all active queues', () {
      final q1 = GroupMutationQueueRegistry.instance.queueFor('grp-1');
      final q2 = GroupMutationQueueRegistry.instance.queueFor('grp-2');
      GroupMutationQueueRegistry.instance.disposeAll();
      expect(q1.isHalted, true);
      expect(q2.isHalted, true);
    });
  });

  group('GroupMutationQueue._extractMessage', () {
    // Test 13: Error message extraction from HTTP detail.
    test('13: extracts detail field from JSON-style error', () {
      final msg = GroupMutationQueue.extractMessageForTest(
        Exception('{"detail": "Group is not open for changes."}')
      );
      expect(msg, 'Group is not open for changes.');
    });

    // Test 14: Extracts from StatusCode pattern.
    test('14: extracts from StatusCode pattern', () {
      final msg = GroupMutationQueue.extractMessageForTest(
        Exception('StatusCode 409: Group is PAYING')
      );
      expect(msg, 'Group is PAYING');
    });
  });
}
