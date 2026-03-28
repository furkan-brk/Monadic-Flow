import 'package:latlong2/latlong.dart';

/// Geographic coordinates and line topology for the IEEE 33-bus test feeder.
///
/// Centered in Kadıköy, Istanbul at approximately (40.9920, 29.0100).
/// The layout mirrors the academic bus topology:
///   - Main feeder: Bus 1–18 (east–west)
///   - Branch A: Bus 2 → 19–22 (south)
///   - Branch B: Bus 3 → 23–25 (north)
///   - Branch C: Bus 6 → 26–33 (south, then east)
class BusGeoData {
  BusGeoData._();

  static const Map<int, LatLng> coordinates = {
    // ── Main feeder (east–west) ───────────────────────────────────────────────
    1:  LatLng(40.9920, 29.0100), // Substation
    2:  LatLng(40.9920, 29.0160),
    3:  LatLng(40.9920, 29.0220),
    4:  LatLng(40.9920, 29.0280),
    5:  LatLng(40.9920, 29.0340),
    6:  LatLng(40.9920, 29.0400), // Hospital_Bus6
    7:  LatLng(40.9920, 29.0460),
    8:  LatLng(40.9920, 29.0520),
    9:  LatLng(40.9920, 29.0580), // School_Bus9
    10: LatLng(40.9920, 29.0640),
    11: LatLng(40.9920, 29.0700),
    12: LatLng(40.9920, 29.0760), // BESS_B
    13: LatLng(40.9920, 29.0820),
    14: LatLng(40.9920, 29.0880),
    15: LatLng(40.9920, 29.0940),
    16: LatLng(40.9920, 29.1000),
    17: LatLng(40.9920, 29.1060), // Hospital_Bus17
    18: LatLng(40.9920, 29.1120),
    // ── Branch A: Bus 2 → south ──────────────────────────────────────────────
    19: LatLng(40.9870, 29.0160),
    20: LatLng(40.9870, 29.0220),
    21: LatLng(40.9870, 29.0280),
    22: LatLng(40.9870, 29.0340), // BESS_A
    // ── Branch B: Bus 3 → north ──────────────────────────────────────────────
    23: LatLng(40.9970, 29.0220),
    24: LatLng(40.9970, 29.0280),
    25: LatLng(40.9970, 29.0340), // School_Bus25
    // ── Branch C: Bus 6 → south then east ────────────────────────────────────
    26: LatLng(40.9850, 29.0400),
    27: LatLng(40.9850, 29.0460),
    28: LatLng(40.9850, 29.0520),
    29: LatLng(40.9850, 29.0580),
    30: LatLng(40.9810, 29.0580),
    31: LatLng(40.9810, 29.0640),
    32: LatLng(40.9810, 29.0700),
    33: LatLng(40.9810, 29.0760),
  };

  /// Line connections [fromBus, toBus] following the IEEE 33-bus radial topology.
  static const List<List<int>> lines = [
    // Main feeder
    [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9],
    [9, 10], [10, 11], [11, 12], [12, 13], [13, 14], [14, 15], [15, 16],
    [16, 17], [17, 18],
    // Branch A
    [2, 19], [19, 20], [20, 21], [21, 22],
    // Branch B
    [3, 23], [23, 24], [24, 25],
    // Branch C
    [6, 26], [26, 27], [27, 28], [28, 29], [29, 30], [30, 31], [31, 32],
    [32, 33],
  ];
}
