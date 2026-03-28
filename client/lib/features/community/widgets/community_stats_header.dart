import 'package:flutter/material.dart';

import '../../../core/models/community_state.dart';

/// Top-of-screen summary card: total energy, active BESS count, settlement
/// count, and an emergency status indicator.
class CommunityStatsHeader extends StatelessWidget {
  const CommunityStatsHeader({
    super.key,
    required this.snapshot,
  });

  final CommunitySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: snapshot.isEmergency
              ? [const Color(0xFF7C1F1F), const Color(0xFF3D0000)]
              : [const Color(0xFF1F2A5C), const Color(0xFF0D1A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: snapshot.isEmergency
              ? Colors.red.withAlpha(120)
              : Colors.indigo.withAlpha(80),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Icon(
                snapshot.isEmergency ? Icons.warning_amber : Icons.hub,
                color: snapshot.isEmergency ? Colors.orange : Colors.indigo.shade300,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                snapshot.isEmergency ? 'ACİL MOD AKTİF' : 'Enerji Topluluğu',
                style: TextStyle(
                  color: snapshot.isEmergency ? Colors.orange : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              // Live indicator dot
              _PulseDot(emergency: snapshot.isEmergency),
            ],
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Toplam Enerji',
                  value: _formatEnergy(snapshot.totalEnergyWh),
                  icon: Icons.bolt,
                  color: Colors.amber,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatCell(
                  label: 'Aktif BESS',
                  value: snapshot.activeBessCount.toString(),
                  icon: Icons.battery_charging_full,
                  color: Colors.green,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatCell(
                  label: 'Transferler',
                  value: snapshot.settlementCount.toString(),
                  icon: Icons.swap_horiz,
                  color: Colors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatEnergy(int wh) {
    if (wh >= 1_000_000) return '${(wh / 1_000_000).toStringAsFixed(1)} MWh';
    if (wh >= 1_000) return '${(wh / 1_000).toStringAsFixed(1)} kWh';
    return '${wh} Wh';
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.emergency});
  final bool emergency;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.emergency ? Colors.red : Colors.green;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(100),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'CANLI',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
