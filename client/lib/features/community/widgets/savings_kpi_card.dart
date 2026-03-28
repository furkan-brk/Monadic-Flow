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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF13221A),
            const Color(0xFF0D1410),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withAlpha(30), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.savings_outlined,
                    color: Colors.greenAccent.shade400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tasarruf KPI',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(80),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.greenAccent.shade200, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Singularity',
                        style: TextStyle(
                          color: Colors.greenAccent.shade100,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 2x2 metric grid ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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
                      const SizedBox(height: 10),
                      _MetricTile(
                        icon: Icons.eco_outlined,
                        color: Colors.lightGreenAccent,
                        label: 'CO₂ Tasarrufu',
                        value: '${_co2SavedKg.toStringAsFixed(2)} kg',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      _MetricTile(
                        icon: Icons.self_improvement,
                        color: Colors.tealAccent,
                        label: 'Öz-Yeterlilik',
                        value: '%${_selfSufficiency.toStringAsFixed(1)}',
                      ),
                      const SizedBox(height: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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

