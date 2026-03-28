import 'package:flutter/material.dart';

import '../../../core/models/community_state.dart';

/// Savings KPI card — displays community-level financial and environmental
/// benefits derived from the current [CommunitySnapshot].
///
/// Calculations (mock/derived from snapshot):
///   - Şebeke Tasarrufu (EUR): totalEnergyWh / 1000 * 0.08
///   - Öz-Yeterlilik (%): min(100, totalEnergyWh / 5000 * 100)
///   - CO₂ Tasarrufu (kg): totalEnergyWh / 1000 * 0.5
///   - MON Kazanım (mMON): settlementCount * 150
class SavingsKpiCard extends StatelessWidget {
  const SavingsKpiCard({super.key, required this.snapshot});

  final CommunitySnapshot snapshot;

  // Derived metrics
  double get _billSavedEur => snapshot.totalEnergyWh / 1000 * 0.08;
  double get _selfSufficiency =>
      (snapshot.totalEnergyWh / 5000 * 100).clamp(0.0, 100.0);
  double get _co2SavedKg => snapshot.totalEnergyWh / 1000 * 0.5;
  int get _monEarned => snapshot.settlementCount * 150;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A2A1A),
            const Color(0xFF0D1F0D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withAlpha(60), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.savings_outlined,
                  color: Colors.greenAccent.shade200,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tasarruf KPI · Singularity',
                  style: TextStyle(
                    color: Colors.greenAccent.shade200,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 2x2 metric grid ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _MetricTile(
                        icon: Icons.euro_outlined,
                        color: Colors.greenAccent,
                        label: 'Şebeke Tasarrufu',
                        value: '€${_billSavedEur.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _MetricTile(
                        icon: Icons.eco_outlined,
                        color: Colors.lightGreen,
                        label: 'CO₂ Tasarrufu',
                        value: '${_co2SavedKg.toStringAsFixed(2)} kg',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _MetricTile(
                        icon: Icons.self_improvement,
                        color: Colors.tealAccent,
                        label: 'Öz-Yeterlilik',
                        value: '%${_selfSufficiency.toStringAsFixed(1)}',
                      ),
                      const SizedBox(height: 8),
                      _MetricTile(
                        icon: Icons.token_outlined,
                        color: Colors.amberAccent,
                        label: 'MON Kazanım',
                        value: '$_monEarned mMON',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual metric tile
// ---------------------------------------------------------------------------

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
