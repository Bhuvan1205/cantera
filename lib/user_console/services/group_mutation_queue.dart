import 'dart:async';

/// A serialized mutation queue scoped to a single Group Order.
///
/// All item mutations for the same [groupId] are chained onto a single
/// Future. This prevents concurrent HTTP requests from contending on the
/// same Firestore document and causing transaction aborts.
///
/// Usage:
///   final queue = GroupMutationQueue(groupId: id);
///   queue.enqueue(() => apiCall(), onRollback: rollbackFn, onFatal: stopFn);
///
/// Different group IDs get completely independent queues.
class GroupMutationQueue {
  GroupMutationQueue({required this.groupId});

  final String groupId;

  /// The tail of the current chain. Every new enqueue appends to this.
  Future<void> _tail = Future.value();

  /// Whether the queue has encountered a fatal error (409 PAYING, 403, 404).
  /// When true, new work is rejected immediately without an HTTP call.
  bool _halted = false;

  bool get isHalted => _halted;

  /// Halt the queue. All subsequent enqueued work will be short-circuited.
  void halt() => _halted = true;

  /// Reset the halt state (e.g., when the group is restarted).
  void reset() => _halted = false;

  /// Enqueue a mutation.
  ///
  /// [work]       - the async backend call; must complete with either success
  ///               or throw an [Exception] describing the failure.
  ///
  /// [onRollback] - called with the error message when [work] throws. It
  ///               receives the error string so it can undo exactly what
  ///               the optimistic update applied.
  ///
  /// [isFatal]    - optional predicate to determine whether a given error
  ///               should halt the entire queue. Receives the raw exception.
  ///               Defaults to halting on 403/404/409 status codes.
  Future<void> enqueue({
    required Future<void> Function() work,
    required void Function(String errorMessage) onRollback,
    bool Function(Object error)? isFatal,
  }) {
    if (_halted) {
      onRollback('Group order is no longer accepting changes.');
      return _tail;
    }

    _tail = _tail.then((_) async {
      if (_halted) {
        onRollback('Group order is no longer accepting changes.');
        return;
      }
      try {
        await work();
      } catch (e) {
        final message = _extractMessage(e);
        onRollback(message);

        final shouldHalt = isFatal?.call(e) ?? _defaultIsFatal(e);
        if (shouldHalt) {
          _halted = true;
        }
      }
    });

    return _tail;
  }

  /// Test accessor. Do not call from production code.
  static String extractMessageForTest(Object e) => _extractMessage(e);

  static String _extractMessage(Object e) {
    final raw = e.toString();
    final stripped = raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
    final detailMatch = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(stripped);
    if (detailMatch != null) return detailMatch.group(1)!;
    final httpMatch = RegExp(r'StatusCode\s+\d+:\s*(.+)').firstMatch(stripped);
    if (httpMatch != null) return httpMatch.group(1)!.trim();
    return stripped.isNotEmpty ? stripped : 'An unexpected error occurred.';
  }

  static bool _defaultIsFatal(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('403') ||
        s.contains('404') ||
        s.contains('409') ||
        s.contains('unauthorized') ||
        s.contains('not found') ||
        s.contains('paying') ||
        s.contains('only group members') ||
        s.contains('no longer open');
  }
}

/// Registry that maintains one [GroupMutationQueue] per active groupId.
class GroupMutationQueueRegistry {
  GroupMutationQueueRegistry._();
  static final instance = GroupMutationQueueRegistry._();

  final Map<String, GroupMutationQueue> _queues = {};

  GroupMutationQueue queueFor(String groupId) {
    return _queues.putIfAbsent(
      groupId,
      () => GroupMutationQueue(groupId: groupId),
    );
  }

  void dispose(String groupId) {
    _queues.remove(groupId)?.halt();
  }

  void disposeAll() {
    for (final q in _queues.values) {
      q.halt();
    }
    _queues.clear();
  }
}

