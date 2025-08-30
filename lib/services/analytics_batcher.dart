import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

/// Batches analytics writes to reduce Firebase costs and improve performance
class AnalyticsBatcher {
  static final Logger _logger = Logger('AnalyticsBatcher');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Batch configuration
  static const int _maxBatchSize =
      450; // Firestore limit is 500, leave some margin
  static const Duration _batchTimeout = Duration(
    seconds: 30,
  ); // Auto-flush every 30s (individual actions)
  static const Duration _turnCompletionTimeout = Duration(
    seconds: 5,
  ); // Fast flush after turn completion
  static const Duration _criticalFlushTimeout = Duration(
    seconds: 1,
  ); // Immediate flush for critical events (round end, etc.)

  // Batch queues by collection
  static final Map<String, Queue<Map<String, dynamic>>> _batches = {};
  static final Map<String, Timer?> _flushTimers = {};
  static final Map<String, Completer<void>?> _flushCompleters = {};

  static bool _enabled = true;

  /// Enable or disable batching (for testing/debugging)
  static void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      // Flush all pending batches immediately when disabling
      flushAllBatches();
    }
  }

  /// Add a document to the batch queue
  static Future<void> addToBatch({
    required String collection,
    required Map<String, dynamic> data,
    bool priority = false, // High priority items flush faster
    bool turnCompletion = false, // Turn completion gets medium priority
  }) async {
    if (!_enabled) {
      // If batching is disabled, write immediately
      await _firestore.collection(collection).add(data);
      return;
    }

    // Initialize batch queue if needed
    if (!_batches.containsKey(collection)) {
      _batches[collection] = Queue<Map<String, dynamic>>();
    }

    // Add to queue
    _batches[collection]!.add(data);

    // Check if we need to flush
    final queueSize = _batches[collection]!.length;

    if (queueSize >= _maxBatchSize) {
      // Batch is full, flush immediately
      await _flushBatch(collection);
    } else {
      // Set up or reset flush timer based on priority
      _scheduleFlush(collection, priority, turnCompletion);
    }
  }

  /// Schedule a flush for a collection
  static void _scheduleFlush(
    String collection,
    bool priority,
    bool turnCompletion,
  ) {
    // Cancel existing timer
    _flushTimers[collection]?.cancel();

    // Set new timer based on priority
    Duration timeout;
    if (priority) {
      timeout = _criticalFlushTimeout; // 1 second - immediate
    } else if (turnCompletion) {
      timeout = _turnCompletionTimeout; // 5 seconds - turn completion
    } else {
      timeout = _batchTimeout; // 30 seconds - individual actions
    }

    _flushTimers[collection] = Timer(timeout, () {
      _flushBatch(collection);
    });
  }

  /// Flush a specific batch
  static Future<void> _flushBatch(String collection) async {
    final batch = _batches[collection];
    if (batch == null || batch.isEmpty) return;

    // Cancel any pending flush timer
    _flushTimers[collection]?.cancel();
    _flushTimers[collection] = null;

    try {
      // Convert queue to list and clear the queue
      final documents = batch.toList();
      batch.clear();

      if (documents.isEmpty) return;

      // Create Firestore batch write
      final firestoreBatch = _firestore.batch();
      final collectionRef = _firestore.collection(collection);

      for (final doc in documents) {
        final docRef = collectionRef.doc(); // Auto-generate ID
        firestoreBatch.set(docRef, doc);
      }

      // Execute the batch
      await firestoreBatch.commit();

      _logger.fine('Flushed ${documents.length} documents to $collection');

      // Complete any waiting operations
      _flushCompleters[collection]?.complete();
      _flushCompleters[collection] = null;
    } catch (e) {
      _logger.severe('Failed to flush batch for $collection: $e');

      // Complete with error
      _flushCompleters[collection]?.completeError(e);
      _flushCompleters[collection] = null;
    }
  }

  /// Flush all batches immediately
  static Future<void> flushAllBatches() async {
    final futures = <Future<void>>[];

    for (final collection in _batches.keys.toList()) {
      if (_batches[collection]?.isNotEmpty ?? false) {
        futures.add(_flushBatch(collection));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      _logger.info('Flushed all pending analytics batches');
    }
  }

  /// Force flush on turn completion (optimized timing)
  static Future<void> flushOnTurnCompletion() async {
    final futures = <Future<void>>[];

    for (final collection in _batches.keys.toList()) {
      if (_batches[collection]?.isNotEmpty ?? false) {
        // Cancel existing timers and flush immediately
        _flushTimers[collection]?.cancel();
        futures.add(_flushBatch(collection));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      _logger.fine('Flushed analytics on turn completion');
    }
  }

  /// Wait for a specific collection's batch to flush
  static Future<void> waitForFlush(String collection) async {
    if (_batches[collection]?.isEmpty ?? true) return;

    // Create or reuse completer
    _flushCompleters[collection] ??= Completer<void>();
    return _flushCompleters[collection]!.future;
  }

  /// Get current batch statistics
  static Map<String, dynamic> getBatchStats() {
    final stats = <String, dynamic>{
      'enabled': _enabled,
      'collections': <String, Map<String, dynamic>>{},
      'totalPending': 0,
    };

    int totalPending = 0;
    for (final entry in _batches.entries) {
      final collection = entry.key;
      final queue = entry.value;
      final pendingCount = queue.length;
      totalPending += pendingCount;

      stats['collections'][collection] = {
        'pending': pendingCount,
        'hasTimer': _flushTimers[collection] != null,
        'timerRemaining': _flushTimers[collection]?.isActive ?? false
            ? 'active'
            : 'inactive',
      };
    }

    stats['totalPending'] = totalPending;
    return stats;
  }

  /// Force immediate flush and cleanup (call on app shutdown)
  static Future<void> shutdown() async {
    _logger.info('Shutting down analytics batcher...');

    // Cancel all timers
    for (final timer in _flushTimers.values) {
      timer?.cancel();
    }
    _flushTimers.clear();

    // Flush all remaining batches
    await flushAllBatches();

    // Clear all data structures
    _batches.clear();
    _flushCompleters.clear();

    _logger.info('Analytics batcher shutdown complete');
  }
}
