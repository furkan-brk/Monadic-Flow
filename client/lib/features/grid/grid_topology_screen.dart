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
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: Colors.grey.shade900,
            title: const Text(
              'IEEE 33-Bus Grid',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (hasEmergency)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _PulsingIcon(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
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
      height: 72,
      color: Colors.grey.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          if (bessB != null)
            Expanded(child: _BESSCard(label: 'BESS_B', busId: 12, node: bessB)),
          const SizedBox(width: 8),
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
        borderRadius: BorderRadius.circular(8),
        color: isFeeding
            ? Colors.green.withAlpha(40)
            : Colors.grey.shade800,
        border: Border.all(
          color: isFeeding ? Colors.greenAccent : Colors.grey.shade600,
          width: isFeeding ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Icon(
            isFeeding
                ? Icons.battery_charging_full
                : Icons.battery_std,
            color: isFeeding ? Colors.greenAccent : Colors.grey,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$label · Bus $busId',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (soc != null)
                  Text(
                    'SOC: ${soc.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                if (isFeeding)
                  const Text(
                    '⚡ Feeding Grid',
                    style: TextStyle(fontSize: 9, color: Colors.greenAccent),
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
    return FadeTransition(
      opacity: _anim,
      child: Icon(widget.icon, color: widget.color),
    );
  }
}
