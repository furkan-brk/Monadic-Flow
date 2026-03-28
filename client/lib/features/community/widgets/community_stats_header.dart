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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: snapshot.isEmergency
              ? [const Color(0xFF5A1A1A), const Color(0xFF2E0909)]
              : [const Color(0xFF222442), const Color(0xFF121326)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: snapshot.isEmergency
                ? Colors.red.withAlpha(20)
                : Colors.indigo.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: snapshot.isEmergency
              ? Colors.red.withAlpha(80)
              : Colors.indigo.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: snapshot.isEmergency
                      ? Colors.orange.withAlpha(30)
                      : Colors.indigo.shade300.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  snapshot.isEmergency ? Icons.warning_amber : Icons.hub_outlined,
                  color: snapshot.isEmergency ? Colors.orange : Colors.indigo.shade300,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                snapshot.isEmergency ? 'ACİL MOD AKTİF' : 'Enerji Topluluğu',
                style: TextStyle(
                  color: snapshot.isEmergency ? Colors.orange : Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Live indicator dot
              _PulseDot(emergency: snapshot.isEmergency),
            ],
          ),

          const SizedBox(height: 20),

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
              const SizedBox(width: 12),
              Expanded(
                child: _StatCell(
                  label: 'Aktif BESS',
                  value: snapshot.activeBessCount.toString(),
                  icon: Icons.battery_charging_full,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCell(
                  label: 'Transferler',
                  value: snapshot.settlementCount.toString(),
                  icon: Icons.swap_horiz,
                  color: Colors.cyanAccent,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54, 
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
    final color = widget.emergency ? Colors.redAccent : Colors.greenAccent;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(150),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'CANLI',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

