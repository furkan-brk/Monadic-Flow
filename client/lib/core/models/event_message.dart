/// Represents a single event received from the ParallelPulse WebSocket backend.
///
/// All fields except [eventType] and [timestampMs] are nullable because
/// different event subtypes carry different payloads.
///
/// Event types:
/// - "EmergencyActivated" — grid fault detected, emergency pricing active.
/// - "TransferSettled"   — BESS → Load energy transfer settled on-chain.
/// - "SOCUpdate"         — BESS state-of-charge tick from the simulation.
/// - "GridStatusUpdate"  — (Sprint 2) topology overlay: failed lines, feeding
///                         BESS buses, and per-bus SOC map.
/// - "CommunityUpdate"   — (Sprint 3) community aggregates: total energy,
///                         active BESS count, leaderboard, recent transfers.
class EventMessage {
  const EventMessage({
    required this.eventType,
    required this.timestampMs,
    this.busId,
    this.bessAddress,
    this.loadAddress,
    this.amountWh,
    this.costWei,
    this.socPercent,
    this.earningsWei,
    this.emergencyMode,
    // Sprint 2 grid topology fields
    this.failedBuses,
    this.failedLines,
    this.feedingBessBuses,
    this.feedingFlows,
    this.bessSOCMap,
    // Sprint 3 community aggregation fields
    this.communityTotalEnergyWh,
    this.communityActiveBessCount,
    this.communitySettlementCount,
    this.communityIsEmergency,
    this.communityLeaderboard,
    this.communityRecentTransfers,
  });

  /// Discriminator — one of: "EmergencyActivated", "TransferSettled",
  /// "SOCUpdate", "GridStatusUpdate".
  final String eventType;

  /// Unix epoch in milliseconds.
  final int timestampMs;

  final int? busId;
  final String? bessAddress;
  final String? loadAddress;
  final int? amountWh;
  final int? costWei;

  /// Battery state-of-charge expressed as a percentage (0–100).
  final double? socPercent;

  final int? earningsWei;
  final bool? emergencyMode;

  // -------------------------------------------------------------------------
  // Sprint 2: GridStatusUpdate fields
  // -------------------------------------------------------------------------

  /// Bus IDs that have a failed upstream line (e.g. [7] when feeder 6→7
  /// is open). Populated in "GridStatusUpdate" events.
  final List<int>? failedBuses;

  /// Pairs [[from, to]] identifying the specific broken line segments.
  /// Example: [[6, 7]] means the line between Bus 6 and Bus 7 is open.
  final List<List<int>>? failedLines;

  /// BESS bus IDs that are currently injecting power into the grid.
  final List<int>? feedingBessBuses;

  /// Energy flow vectors. Each entry is a map with keys:
  /// "from_bus" (int), "to_bus" (int), "amount_wh" (int).
  final List<Map<String, dynamic>>? feedingFlows;

  /// Maps str(bus_id) → soc_percent for every known BESS unit.
  /// Example: {"12": 67.4, "22": 45.2}
  final Map<String, double>? bessSOCMap;

  // -------------------------------------------------------------------------
  // Sprint 3: CommunityUpdate fields
  // -------------------------------------------------------------------------

  /// Total energy contributed by all BESS units this session (Wh).
  final int? communityTotalEnergyWh;

  /// Number of distinct BESS addresses that have contributed this session.
  final int? communityActiveBessCount;

  /// Total number of settled transfers.
  final int? communitySettlementCount;

  /// True when the grid is in emergency mode.
  final bool? communityIsEmergency;

  /// Leaderboard entries: [{address, earnings_wei, total_energy_wh, rank}]
  final List<Map<String, dynamic>>? communityLeaderboard;

  /// 5 most recent settled transfers:
  /// [{bess_address, load_address, amount_wh, earnings_wei, timestamp_ms}]
  final List<Map<String, dynamic>>? communityRecentTransfers;

  // -------------------------------------------------------------------------
  // Factory
  // -------------------------------------------------------------------------

  /// Parses a raw JSON map from the WebSocket into an [EventMessage].
  ///
  /// Uses safe cast patterns so that both int-valued and float-valued JSON
  /// numbers are handled correctly.
  factory EventMessage.fromJson(Map<String, dynamic> json) {
    // Helper: parse [[int, int], ...] from a JSON array of arrays.
    List<List<int>>? parseIntMatrix(Object? raw) {
      if (raw == null) return null;
      return (raw as List)
          .map((row) => (row as List).map((v) => v as int).toList())
          .toList();
    }

    // Helper: parse List<Map<String, dynamic>> from a JSON array of objects.
    List<Map<String, dynamic>>? parseMapList(Object? raw) {
      if (raw == null) return null;
      return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    // Helper: parse Map<String, double> from a JSON object.
    Map<String, double>? parseStringDoubleMap(Object? raw) {
      if (raw == null) return null;
      return (raw as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    }

    return EventMessage(
      eventType: json['event_type'] as String,
      timestampMs: json['timestamp_ms'] as int,
      busId: json['bus_id'] as int?,
      bessAddress: json['bess_address'] as String?,
      loadAddress: json['load_address'] as String?,
      amountWh: json['amount_wh'] as int?,
      costWei: json['cost_wei'] as int?,
      socPercent: (json['soc_percent'] as num?)?.toDouble(),
      earningsWei: json['earnings_wei'] as int?,
      emergencyMode: json['emergency_mode'] as bool?,
      // Sprint 2
      failedBuses: (json['failed_buses'] as List?)?.map((e) => e as int).toList(),
      failedLines: parseIntMatrix(json['failed_lines']),
      feedingBessBuses:
          (json['feeding_bess_buses'] as List?)?.map((e) => e as int).toList(),
      feedingFlows: parseMapList(json['feeding_flows']),
      bessSOCMap: parseStringDoubleMap(json['bess_soc_map']),
      // Sprint 3 community fields
      communityTotalEnergyWh: json['community_total_energy_wh'] as int?,
      communityActiveBessCount: json['community_active_bess_count'] as int?,
      communitySettlementCount: json['community_settlement_count'] as int?,
      communityIsEmergency: json['community_is_emergency'] as bool?,
      communityLeaderboard: parseMapList(json['community_leaderboard']),
      communityRecentTransfers: parseMapList(json['community_recent_transfers']),
    );
  }

  @override
  String toString() => 'EventMessage($eventType @ $timestampMs)';
}
