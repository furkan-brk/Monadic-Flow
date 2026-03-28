import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/community_state.dart';

/// Live Monad TPS (transactions per second) counter.
///
/// Computes a rolling 1-second window delta from [CommunityStateNotifier]'s
/// [CommunitySnapshot.settlementCount] and displays it as a glowing pill.
///
/// Colour coding:
///   - Green    (>= 1 tx/s) — active throughput
///   - Amber    (> 0 tx/s)  — low throughput
///   - White 38 (== 0)      — idle
class MonadTpsCounter extends StatefulWidget {
  const MonadTpsCounter({super.key});

  @override
  State<MonadTpsCounter> createState() => _MonadTpsCounterState();
}

class _MonadTpsCounterState extends State<MonadTpsCounter> {
  Timer? _timer;
  int _prevCount = 0;
  double _tps = 0.0;

  @override
  void initState() {
    super.initState();
    // Sample the settlement counter every second.
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer _) {
    if (!mounted) return;
    final current =
        context.read<CommunityStateNotifier>().snapshot.settlementCount;
    final delta = current - _prevCount;
    _prevCount = current;
    setState(() => _tps = delta.toDouble().clamp(0.0, 9999.0));
  }

  @override
  Widget build(BuildContext context) {
    final color = _tpsColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Monad logo pill ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF6366F1).withAlpha(80), width: 1),
            ),
            child: const Text(
              'MONAD',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ── TPS value ────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Parallel EVM Throughput',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    key: ValueKey(_tps),
                    '⚡ ${_tps.toStringAsFixed(1)} tx/s',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Status dot ───────────────────────────────────────────────────
          _StatusDot(color: color, active: _tps > 0),
        ],
      ),
    );
  }

  Color _tpsColor() {
    if (_tps >= 1.0) return Colors.greenAccent;
    if (_tps > 0.0) return Colors.amber;
    return Colors.white38;
  }
}

// ---------------------------------------------------------------------------
// Animated status dot
// ---------------------------------------------------------------------------

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
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
    if (!widget.active) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(120),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
