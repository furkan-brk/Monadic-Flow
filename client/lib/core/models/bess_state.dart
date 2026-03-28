import 'dart:async';

import 'package:flutter/foundation.dart';

import '../notification_service.dart';
import '../websocket_service.dart';
import 'event_message.dart';

/// Immutable snapshot of the BESS (Battery Energy Storage System) state.
class BESSState {
  const BESSState({
    this.socPercent = 0.0,
    this.earningsWei = 0,
    this.emergencyMode = false,
    this.lastEventType,
    this.lastTimestampMs,
  });

  /// Battery state-of-charge as a percentage (0–100).
  final double socPercent;

  /// Cumulative earnings in wei.
  final int earningsWei;

  /// Whether the grid is currently in emergency / 5× pricing mode.
  final bool emergencyMode;

  /// The `event_type` string of the most recently processed event.
  final String? lastEventType;

  /// Unix epoch ms of the most recently processed event.
  final int? lastTimestampMs;

  /// Returns a copy of this state with the specified fields overridden.
  BESSState copyWith({
    double? socPercent,
    int? earningsWei,
    bool? emergencyMode,
    String? lastEventType,
    int? lastTimestampMs,
  }) {
    return BESSState(
      socPercent: socPercent ?? this.socPercent,
      earningsWei: earningsWei ?? this.earningsWei,
      emergencyMode: emergencyMode ?? this.emergencyMode,
      lastEventType: lastEventType ?? this.lastEventType,
      lastTimestampMs: lastTimestampMs ?? this.lastTimestampMs,
    );
  }
}

/// [ChangeNotifier] that owns the live [BESSState] and drives UI rebuilds.
///
/// Subscribe to the [WebSocketService] event stream in the constructor so
/// state is always up-to-date with the backend without any manual wiring
/// from the widget layer.
class BESSStateNotifier extends ChangeNotifier {
  BESSStateNotifier(WebSocketService ws) {
    _subscription = ws.events.listen(_handleEvent);
    ws.connect();
  }
  late final StreamSubscription<EventMessage> _subscription;

  BESSState _state = const BESSState();

  /// The current, authoritative BESS state.
  BESSState get state => _state;

  void _handleEvent(EventMessage event) {
    switch (event.eventType) {
      case 'SOCUpdate':
        _state = _state.copyWith(
          socPercent: event.socPercent ?? _state.socPercent,
          earningsWei: event.earningsWei ?? _state.earningsWei,
          lastEventType: event.eventType,
          lastTimestampMs: event.timestampMs,
        );

      case 'EmergencyActivated':
        _state = _state.copyWith(
          emergencyMode: true,
          lastEventType: event.eventType,
          lastTimestampMs: event.timestampMs,
        );
        NotificationService.instance.showEmergencyAlert(
          busId: event.busId ?? 0,
        );

      case 'TransferSettled':
        final incoming = event.earningsWei ?? 0;
        _state = _state.copyWith(
          earningsWei: _state.earningsWei + incoming,
          lastEventType: event.eventType,
          lastTimestampMs: event.timestampMs,
        );
        NotificationService.instance.showEarningsAlert(
          amountWh: event.amountWh ?? 0,
          earningsWei: incoming,
        );

      default:
        // Unknown event type — still update the last-seen metadata so the
        // event log reflects it.
        _state = _state.copyWith(
          lastEventType: event.eventType,
          lastTimestampMs: event.timestampMs,
        );
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
