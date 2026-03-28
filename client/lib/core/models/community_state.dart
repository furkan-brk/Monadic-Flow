import 'dart:async';

import 'package:flutter/foundation.dart';

import '../websocket_service.dart';
import 'event_message.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// A single settlement record shown in the live feed.
class TransferRecord {
  const TransferRecord({
    required this.bessAddress,
    required this.loadAddress,
    required this.amountWh,
    required this.earningsWei,
    required this.timestampMs,
  });

  final String bessAddress;
  final String loadAddress;
  final int amountWh;
  final int earningsWei;
  final int timestampMs;

  /// Short version of [bessAddress] for display: "0x1234…abcd".
  String get shortBess {
    if (bessAddress.length < 10) return bessAddress;
    return '${bessAddress.substring(0, 6)}…${bessAddress.substring(bessAddress.length - 4)}';
  }
}

/// Leaderboard entry aggregated per BESS address.
class LeaderboardEntry {
  LeaderboardEntry({required this.address})
      : earningsWei = 0,
        totalEnergyWh = 0;

  final String address;
  int earningsWei;
  int totalEnergyWh;

  int get rank => 0; // Set by CommunityState when building sorted list.

  String get shortAddress {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
}

// ---------------------------------------------------------------------------
// Immutable community snapshot
// ---------------------------------------------------------------------------

class CommunitySnapshot {
  const CommunitySnapshot({
    this.totalEnergyWh = 0,
    this.activeBessCount = 0,
    this.settlementCount = 0,
    this.isEmergency = false,
    this.recentTransfers = const [],
    this.leaderboard = const [],
  });

  final int totalEnergyWh;
  final int activeBessCount;
  final int settlementCount;
  final bool isEmergency;
  final List<TransferRecord> recentTransfers;
  final List<LeaderboardEntry> leaderboard; // sorted by earningsWei desc
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Subscribes to the shared [WebSocketService] broadcast stream and aggregates
/// community-level statistics from [TransferSettled] and [EmergencyActivated]
/// events.
///
/// Does NOT call [WebSocketService.connect] — [BESSStateNotifier] owns that.
class CommunityStateNotifier extends ChangeNotifier {
  CommunityStateNotifier(WebSocketService ws) {
    _subscription = ws.events.listen(_handleEvent);
  }

  late final StreamSubscription<EventMessage> _subscription;

  // Mutable accumulators — never exposed directly (always return snapshot).
  int _totalEnergyWh = 0;
  int _settlementCount = 0;
  bool _isEmergency = false;
  final List<TransferRecord> _recentTransfers = [];

  // address → entry (mutable, rebuilt into sorted list for snapshot).
  final Map<String, LeaderboardEntry> _byAddress = {};

  CommunitySnapshot _snapshot = const CommunitySnapshot();

  CommunitySnapshot get snapshot => _snapshot;

  // -------------------------------------------------------------------------
  // Event handling
  // -------------------------------------------------------------------------

  void _handleEvent(EventMessage event) {
    switch (event.eventType) {
      case 'TransferSettled':
        _recordTransfer(event);

      case 'EmergencyActivated':
        _isEmergency = true;
        _rebuild();

      default:
        // SOCUpdate, GridStatusUpdate — no community state change.
        return;
    }
  }

  void _recordTransfer(EventMessage event) {
    final bess = event.bessAddress ?? '0x???';
    final load = event.loadAddress ?? '0x???';
    final amount = event.amountWh ?? 0;
    final earnings = event.earningsWei ?? 0;
    final ts = event.timestampMs;

    // Accumulate totals.
    _totalEnergyWh += amount;
    _settlementCount += 1;

    // Update leaderboard entry.
    _byAddress.putIfAbsent(bess, () => LeaderboardEntry(address: bess));
    _byAddress[bess]!.earningsWei += earnings;
    _byAddress[bess]!.totalEnergyWh += amount;

    // Prepend to recent list; cap at 50 entries.
    _recentTransfers.insert(
      0,
      TransferRecord(
        bessAddress: bess,
        loadAddress: load,
        amountWh: amount,
        earningsWei: earnings,
        timestampMs: ts,
      ),
    );
    if (_recentTransfers.length > 50) _recentTransfers.removeLast();

    _rebuild();
  }

  void _rebuild() {
    // Sort leaderboard descending by earnings.
    final sorted = _byAddress.values.toList()
      ..sort((a, b) => b.earningsWei.compareTo(a.earningsWei));

    _snapshot = CommunitySnapshot(
      totalEnergyWh: _totalEnergyWh,
      activeBessCount: _byAddress.length,
      settlementCount: _settlementCount,
      isEmergency: _isEmergency,
      recentTransfers: List.unmodifiable(_recentTransfers),
      leaderboard: List.unmodifiable(sorted),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
