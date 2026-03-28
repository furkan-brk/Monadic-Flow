import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/grid_state.dart';
import 'widgets/grid_legend.dart';
import 'widgets/ieee33_painter.dart';

/// Full-screen IEEE 33-bus grid topology visualisation.
///
/// Layout:
/// 1. [AppBar] — "IEEE 33-Bus Grid" title + live emergency indicator.
/// 2. [InteractiveViewer] — zoomable/pannable canvas with [Ieee33BusPainter].
/// 3. [_BessFeedSummaryRow] — horizontal cards for BESS_B (Bus 12) and
///    BESS_A (Bus 22) showing SOC and feeding status.
/// 4. [GridLegend] — colour key matching the WhatsApp schematic.
class GridTopologyScreen extends StatefulWidget {
  const GridTopologyScreen({super.key});

  @override
  State<GridTopologyScreen> createState() => _GridTopologyScreenState();
}

class _GridTopologyScreenState extends State<GridTopologyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowCtrl;
  late final Animation<double> _flowAnim;

  @override
  void initState() {
    super.initState();
    _flowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _flowAnim = CurvedAnimation(parent: _flowCtrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _flowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GridTopologyNotifier>(
      builder: (context, notifier, _) {
        final hasEmergency = notifier.failedLineKeys.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D0D1A),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                const Icon(Icons.grid_on, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'IEEE 33-Bus Şebeke',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            actions: [
              if (hasEmergency)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(80), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulsingIcon(
                          icon: Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'ACİL MOD',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // ---------------------------------------------------------------
              // Grid canvas
              // ---------------------------------------------------------------
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      minScale: 0.4,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        // Enforce a 2.4:1 aspect ratio that matches the schematic.
                        height: constraints.maxWidth / 2.4,
                        child: AnimatedBuilder(
                          animation: _flowAnim,
                          builder: (_, __) => CustomPaint(
                            painter: Ieee33BusPainter(
                              busNodes: notifier.busNodes,
                              failedLineKeys: notifier.failedLineKeys,
                              feedingFlows: notifier.feedingFlows,
                              flowAnimation: _flowAnim,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ---------------------------------------------------------------
              // BESS summary cards
              // ---------------------------------------------------------------
              _BessFeedSummaryRow(notifier: notifier),

              // ---------------------------------------------------------------
              // Legend
              // ---------------------------------------------------------------
              const GridLegend(),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// BESS summary row
// ---------------------------------------------------------------------------

class _BessFeedSummaryRow extends StatelessWidget {
  const _BessFeedSummaryRow({required this.notifier});

  final GridTopologyNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final bessB = notifier.busNodes[12];
    final bessA = notifier.busNodes[22];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16162C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withAlpha(40), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (bessB != null)
            Expanded(child: _BESSCard(label: 'BESS_B', busId: 12, node: bessB)),
          if (bessB != null && bessA != null) const SizedBox(width: 12),
          if (bessA != null)
            Expanded(child: _BESSCard(label: 'BESS_A', busId: 22, node: bessA)),
        ],
      ),
    );
  }
}

class _BESSCard extends StatelessWidget {
  const _BESSCard({
    required this.label,
    required this.busId,
    required this.node,
  });

  final String label;
  final int busId;
  final BusNodeState node;

  @override
  Widget build(BuildContext context) {
    final isFeeding = node.status == BusStatus.feeding;
    final soc = node.socPercent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isFeeding
            ? LinearGradient(
                colors: [
                  Colors.green.shade900.withAlpha(80),
                  Colors.green.shade800.withAlpha(40),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF222442), Color(0xFF121326)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isFeeding
              ? Colors.greenAccent.withAlpha(80)
              : Colors.indigo.withAlpha(30),
          width: 1,
        ),
        boxShadow: isFeeding
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isFeeding ? Colors.greenAccent.withAlpha(20) : Colors.indigo.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isFeeding ? Icons.battery_charging_full : Icons.battery_std,
              color: isFeeding ? Colors.greenAccent : Colors.indigo.shade300,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$label · Bus $busId',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                if (soc != null)
                  Text(
                    'SOC: ${soc.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                if (isFeeding) ...[
                  const SizedBox(height: 2),
                  const Text(
                    '⚡ Şebekeye Besleme',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing icon widget (emergency indicator in AppBar)
// ---------------------------------------------------------------------------

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Icon(widget.icon, color: widget.color, size: 16),
      ),
    );
  }
}
