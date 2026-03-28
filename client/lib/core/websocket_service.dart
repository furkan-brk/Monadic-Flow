import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:web_socket_channel/web_socket_channel.dart';

import 'models/event_message.dart';

/// Manages the WebSocket connection to the ParallelPulse backend.
///
/// Parsed [EventMessage] objects are exposed via the [events] broadcast stream.
/// The service automatically schedules a reconnect on error or disconnection
/// so callers don't need to implement retry logic.
class WebSocketService {
  WebSocketService({String? url})
      : _uri = Uri.parse(url ?? 'ws://localhost:8000/ws');

  final Uri _uri;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;

  final StreamController<EventMessage> _controller =
      StreamController<EventMessage>.broadcast();

  bool _disposed = false;
  bool _connecting = false;

  /// Broadcast stream of parsed events from the backend.
  ///
  /// Callers may listen to this stream multiple times; it is a broadcast
  /// stream so late subscribers receive events from the point they subscribe.
  Stream<EventMessage> get events => _controller.stream;

  /// Opens the WebSocket connection.
  ///
  /// Safe to call multiple times — subsequent calls while a connection is
  /// already in progress are silently ignored.
  Future<void> connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;

    try {
      dev.log('WebSocketService: connecting to $_uri');
      _channel = WebSocketChannel.connect(_uri);

      _channelSubscription = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Mark connection as established so future connect() calls (from
      // _scheduleReconnect) are not blocked.
      _connecting = false;
      dev.log('WebSocketService: connected');
    } catch (e, st) {
      dev.log('WebSocketService: connect error — $e', stackTrace: st);
      _connecting = false;
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = EventMessage.fromJson(json);
      _controller.add(event);
    } catch (e) {
      dev.log('WebSocketService: failed to parse message — $e\nRaw: $raw');
    }
  }

  void _onError(Object error, StackTrace stack) {
    dev.log('WebSocketService: stream error — $error', stackTrace: stack);
    _cleanup();
    _scheduleReconnect();
  }

  void _onDone() {
    dev.log('WebSocketService: stream closed, scheduling reconnect');
    _cleanup();
    _scheduleReconnect();
  }

  void _cleanup() {
    _connecting = false;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;
  }

  /// Waits 3 seconds then attempts a fresh connection.
  void _scheduleReconnect() {
    if (_disposed) return;
    dev.log('WebSocketService: reconnect in 3 s…');
    Future.delayed(const Duration(seconds: 3), connect);
  }

  /// Permanently closes the service. After disposal, [connect] is a no-op.
  void dispose() {
    _disposed = true;
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
