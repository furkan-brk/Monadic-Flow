import 'dart:async';

import 'package:flutter/foundation.dart';

import '../websocket_service.dart';
import 'event_message.dart';

// ---------------------------------------------------------------------------
// Enumerations
// ---------------------------------------------------------------------------

/// Functional role of a bus in the IEEE 33-bus network.
enum BusType {
  /// Bus 1 — main substation / grid connection point.
  substation,

  /// Level-1 critical load (hospitals): Bus 6, Bus 17.
  criticalL1,

  /// Level-2 critical load (schools): Bus 9, Bus 25.
  criticalL2,

  /// BESS (Battery Energy Storage System) node: Bus 12 (BESS_B), Bus 22 (BESS_A).
  bess,

  /// All other load buses (non-critical).
  normal,
}

/// Current operational status of a bus node.
enum BusStatus {
  /// Grid-connected and operating normally.
  normal,

  /// Upstream line has failed — bus is islanded.
  islanded,

  /// BESS at this bus is actively feeding energy into the grid.
  feeding,

  /// Node is offline / not responding.
  offline,
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// Directional energy flow from a BESS bus to a load bus.
class FeedingFlow {
  final int fromBus;
  final int toBus;
  final int amountWh;

  const FeedingFlow({
    required this.fromBus,
    required this.toBus,
    required this.amountWh,
  });
}

/// Mutable state of a single bus node; updated by [GridTopologyNotifier].
class BusNodeState {
  final int busId;
  final BusType type;
  BusStatus status;

  /// State-of-charge percentage (0–100). Non-null only for [BusType.bess] nodes.
  double? socPercent;

  BusNodeState({
    required this.busId,
    required this.type,
    this.status = BusStatus.normal,
    this.socPercent,
  });
}

// ---------------------------------------------------------------------------
// Topology notifier
// ---------------------------------------------------------------------------

/// [ChangeNotifier] that tracks live IEEE 33-bus topology state.
///
/// Subscribes to the [WebSocketService] event stream and applies incoming
/// [EventMessage] payloads of type "GridStatusUpdate" to the per-bus state
/// map and failed-line set, then calls [notifyListeners] so that
/// [Ieee33BusPainter] repaints.
class GridTopologyNotifier extends ChangeNotifier {
  GridTopologyNotifier(WebSocketService ws) {
    // ws.connect() is NOT called here — BESSStateNotifier handles that.
    _subscription = ws.events.listen(applyEvent);
  }

  late final StreamSubscription<EventMessage> _subscription;

  /// All 33 bus nodes, keyed by bus ID (1–33).
  final Map<int, BusNodeState> busNodes = _buildInitialNodes();

  /// Set of "from-to" string keys (e.g. "6-7") for lines that are open /
  /// failed. Both "6-7" and "7-6" are stored for easy bidirectional lookup.
  final Set<String> failedLineKeys = {};

  /// Active energy flows from BESS to load buses this cycle.
  final List<FeedingFlow> feedingFlows = [];

  // -------------------------------------------------------------------------
  // Event handling
  // -------------------------------------------------------------------------

  /// Apply an incoming [EventMessage] to the topology state.
  ///
  /// Only "GridStatusUpdate" events are handled; other event types are ignored.
  void applyEvent(EventMessage event) {
    if (event.eventType != 'GridStatusUpdate') return;

    // --- Reset transient feeding state so old arrows don't linger ---
    feedingFlows.clear();
    for (final node in busNodes.values) {
      if (node.status == BusStatus.feeding) {
        node.status = BusStatus.normal;
      }
    }

    // --- Apply failed lines ---
    if (event.failedLines != null) {
      for (final pair in event.failedLines!) {
        if (pair.length >= 2) {
          failedLineKeys.add('${pair[0]}-${pair[1]}');
          failedLineKeys.add('${pair[1]}-${pair[0]}');
        }
      }
    }

    // --- Mark islanded buses (downstream of a failed line) ---
    if (event.failedBuses != null) {
      for (final busId in event.failedBuses!) {
        busNodes[busId]?.status = BusStatus.islanded;
      }
    }

    // --- Mark BESS buses that are currently feeding ---
    if (event.feedingBessBuses != null) {
      for (final busId in event.feedingBessBuses!) {
        busNodes[busId]?.status = BusStatus.feeding;
      }
    }

    // --- Collect energy flow vectors ---
    if (event.feedingFlows != null) {
      for (final f in event.feedingFlows!) {
        final fromBus = f['from_bus'] as int?;
        final toBus = f['to_bus'] as int?;
        final amountWh = f['amount_wh'] as int?;
        if (fromBus != null && toBus != null && amountWh != null) {
          feedingFlows.add(FeedingFlow(
            fromBus: fromBus,
            toBus: toBus,
            amountWh: amountWh,
          ));
        }
      }
    }

    // --- Update BESS SOC percentages ---
    if (event.bessSOCMap != null) {
      event.bessSOCMap!.forEach((busIdStr, soc) {
        final busId = int.tryParse(busIdStr);
        if (busId != null) {
          busNodes[busId]?.socPercent = soc;
        }
      });
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Static helpers
  // -------------------------------------------------------------------------

  /// Build the initial 33-node map with static bus type assignments.
  static Map<int, BusNodeState> _buildInitialNodes() {
    const typeMap = <int, BusType>{
      1: BusType.substation,
      6: BusType.criticalL1,   // Hospital_Bus6
      9: BusType.criticalL2,   // School_Bus9
      12: BusType.bess,        // BESS_B
      17: BusType.criticalL1,  // Hospital_Bus17
      22: BusType.bess,        // BESS_A
      25: BusType.criticalL2,  // School_Bus25
    };

    return {
      for (int i = 1; i <= 33; i++)
        i: BusNodeState(
          busId: i,
          type: typeMap[i] ?? BusType.normal,
          // Initialise BESS nodes at 80% SOC (matches gsy-e setup defaults).
          socPercent: (typeMap[i] == BusType.bess) ? 80.0 : null,
        ),
    };
  }
}
