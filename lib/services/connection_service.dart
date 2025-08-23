import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';

/// Service for monitoring network connectivity and managing offline/online state
class ConnectionService {
  static final Logger _logger = Logger('ConnectionService');
  static final Connectivity _connectivity = Connectivity();

  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  static bool _isConnected = true;
  static bool _isInitialized = false;

  /// Stream of connection state changes (true = connected, false = disconnected)
  static Stream<bool> get connectionStream => _connectionController.stream;

  /// Current connection state
  static bool get isConnected => _isConnected;

  /// Initialize connection monitoring
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _isConnected = _hasInternetConnectivity(result);

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasConnected = _isConnected;
          _isConnected = _hasInternetConnectivity(results);

          if (wasConnected != _isConnected) {
            _logger.info(
              'Connection state changed: ${_isConnected ? "ONLINE" : "OFFLINE"}',
            );
            _connectionController.add(_isConnected);
          }
        },
        onError: (error) {
          _logger.warning('Connectivity monitoring error: $error');
        },
      );

      _isInitialized = true;
      _logger.info(
        'Connection monitoring initialized - Current state: ${_isConnected ? "ONLINE" : "OFFLINE"}',
      );
    } catch (e) {
      _logger.severe('Failed to initialize connection monitoring: $e');
    }
  }

  /// Check if any of the connectivity results indicate internet access
  static bool _hasInternetConnectivity(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Wait for connection to be restored
  static Future<void> waitForConnection({Duration? timeout}) async {
    if (_isConnected) return;

    final completer = Completer<void>();
    late StreamSubscription<bool> subscription;
    Timer? timeoutTimer;

    subscription = connectionStream.listen((isConnected) {
      if (isConnected) {
        subscription.cancel();
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    // Set timeout if specified
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('Connection timeout', timeout),
          );
        }
      });
    }

    return completer.future;
  }

  /// Dispose of resources
  static void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _connectionController.close();
    _isInitialized = false;
  }
}
