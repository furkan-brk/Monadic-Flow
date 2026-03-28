import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/grid_state.dart';
import 'logic/simulation_models.dart';
import 'logic/simulation_notifier.dart';
import 'models/bus_geo_data.dart';
import 'widgets/sim_control_panel.dart';

/// Interactive geo-map of the IEEE 33-bus network — the 4th tab "Harita".
///
/// Uses OpenStreetMap tiles via flutter_map (no API key required).
/// Marker appearance and polyline colour are driven by [GridTopologyNotifier].
class SingularityMapScreen extends StatefulWidget {
  const SingularityMapScreen({super.key});

  @override
  State<SingularityMapScreen> createState() => _SingularityMapScreenState();
}

class _SingularityMapScreenState extends State<SingularityMapScreen>
    with TickerProviderStateMixin {
  static const LatLng _initialCenter = LatLng(40.9920, 29.0640);
  static const double _initialZoom = 13.5;

  final MapController _mapController = MapController();

  // Pulse animation for islanded / feeding nodes.
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Flow animation — drives the animated BESS→load energy flow polylines.
  late AnimationController _flowCtrl;
  late Animation<double> _flowAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _flowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _flowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flowCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _flowCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<GridTopologyNotifier>(
      builder: (context, topo, _) {
        final hasEmergency = topo.failedLineKeys.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          body: Stack(
            children: [
              // ── Map ────────────────────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: _initialZoom,
                  minZoom: 11.0,
                  maxZoom: 17.0,
                ),
                children: [
                  // OpenStreetMap tile layer — no API key required.
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.parallelpulse.app',
                    tileBuilder: _darkModeTileBuilder,
                  ),

                  // ── Power lines ─────────────────────────────────────────
                  PolylineLayer(
                    polylines: _buildPolylines(topo),
                  ),

                  // ── Animated BESS→Load energy flow lines ────────────────
                  AnimatedBuilder(
                    animation: _flowAnim,
                    builder: (_, __) => PolylineLayer(
                      polylines: _buildFlowPolylines(topo, _flowAnim.value),
                    ),
                  ),

                  // ── Bus markers ─────────────────────────────────────────
                  MarkerLayer(
                    markers: _buildMarkers(context, topo),
                  ),

                  // ── Simulation contract flow lines ───────────────────────
                  // Uses AnimatedBuilder referencing the parent state's
                  // _flowAnim and reads sim from Provider inside the builder.
                  AnimatedBuilder(
                    animation: _flowAnim,
                    builder: (ctx, __) {
                      final sim = ctx.read<SimulationNotifier>();
                      return PolylineLayer(
                        polylines: _buildSimFlowPolylines(sim, _flowAnim.value),
                      );
                    },
                  ),

                  // ── Simulation node markers ──────────────────────────────
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (ctx, __) {
                      final sim = ctx.read<SimulationNotifier>();
                      return MarkerLayer(
                        markers: _buildSimMarkers(context, sim),
                      );
                    },
                  ),
                ],
              ),

              // ── AppBar overlay ─────────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _MapAppBar(hasEmergency: hasEmergency),
              ),

              // ── Emergency info panel ───────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _EmergencyPanel(topo: topo),
              ),

              // ── Simulation control panel ───────────────────────────────────
              const SimControlPanel(),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tile builder: darken OSM tiles to match app dark theme
  // ---------------------------------------------------------------------------

  Widget _darkModeTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.4, 0, 0, 0, 0,
        0, 0.4, 0, 0, 0,
        0, 0, 0.5, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  // ---------------------------------------------------------------------------
  // Polylines
  // ---------------------------------------------------------------------------

  List<Polyline> _buildPolylines(GridTopologyNotifier topo) {
    final polylines = <Polyline>[];

    for (final line in BusGeoData.lines) {
      final fromBus = line[0];
      final toBus = line[1];
      final fromCoord = BusGeoData.coordinates[fromBus];
      final toCoord = BusGeoData.coordinates[toBus];
      if (fromCoord == null || toCoord == null) continue;

      final key = '$fromBus-$toBus';
      final isFailed = topo.failedLineKeys.contains(key);

      if (isFailed) {
        // Dashed-effect: two overlapping polylines — gap via a short solid then
        // a transparent polyline of the same length; simplest approach in
        // flutter_map is to alternate dot/dash segments.
        final midLat = (fromCoord.latitude + toCoord.latitude) / 2;
        final midLng = (fromCoord.longitude + toCoord.longitude) / 2;
        final mid = LatLng(midLat, midLng);

        polylines.add(Polyline(
          points: [fromCoord, mid],
          color: Colors.red,
          strokeWidth: 3.0,
        ));
        polylines.add(Polyline(
          points: [mid, toCoord],
          color: Colors.red.withAlpha(80),
          strokeWidth: 3.0,
        ));
      } else {
        polylines.add(Polyline(
          points: [fromCoord, toCoord],
          color: const Color(0xFF5DADE2),
          strokeWidth: 3.0,
        ));
      }
    }

    return polylines;
  }

  // ---------------------------------------------------------------------------
  // Animated flow polylines (BESS → Critical Load during emergency)
  // ---------------------------------------------------------------------------

  List<Polyline> _buildFlowPolylines(
    GridTopologyNotifier topo,
    double animValue,
  ) {
    final polylines = <Polyline>[];

    for (final flow in topo.feedingFlows) {
      final fromCoord = BusGeoData.coordinates[flow.fromBus];
      final toCoord = BusGeoData.coordinates[flow.toBus];
      if (fromCoord == null || toCoord == null) continue;

      // Animated glow line — strokes wider and more opaque as animValue → 1.
      polylines.add(Polyline(
        points: [fromCoord, toCoord],
        color: Colors.greenAccent.withAlpha((animValue * 200).toInt()),
        strokeWidth: 2.0 + animValue * 3.0,
      ));

      // Thin white core for a "light beam" effect.
      polylines.add(Polyline(
        points: [fromCoord, toCoord],
        color: Colors.white.withAlpha((animValue * 80).toInt()),
        strokeWidth: 1.0,
      ));
    }

    return polylines;
  }

  // ---------------------------------------------------------------------------
  // Simulation contract flow polylines
  // ---------------------------------------------------------------------------

  List<Polyline> _buildSimFlowPolylines(
    SimulationNotifier sim,
    double animValue,
  ) {
    final polylines = <Polyline>[];
    if (!sim.isRunning && sim.activeContracts.isEmpty) return polylines;

    for (final contract in sim.activeContracts) {
      if (contract.status == ContractStatus.rejected) {
        // Red dashed line for rejected contracts
        final from = sim.nodeById(contract.fromNodeId).position;
        final to = sim.nodeById(contract.toNodeId).position;
        final mid = LatLng(
          (from.latitude + to.latitude) / 2,
          (from.longitude + to.longitude) / 2,
        );
        polylines.add(Polyline(
          points: [from, mid],
          color: Colors.red.withAlpha(140),
          strokeWidth: 2.5,
        ));
        polylines.add(Polyline(
          points: [mid, to],
          color: Colors.red.withAlpha(50),
          strokeWidth: 2.5,
        ));
        continue;
      }

      final from = sim.nodeById(contract.fromNodeId).position;
      final to = sim.nodeById(contract.toNodeId).position;

      // Outer glow
      polylines.add(Polyline(
        points: [from, to],
        color: Colors.greenAccent.withAlpha((animValue * 200).toInt()),
        strokeWidth: 3.0 + animValue * 3.0,
      ));
      // White core
      polylines.add(Polyline(
        points: [from, to],
        color: Colors.white.withAlpha((animValue * 90).toInt()),
        strokeWidth: 1.2,
      ));
    }
    return polylines;
  }

  // ---------------------------------------------------------------------------
  // Simulation node markers
  // ---------------------------------------------------------------------------

  List<Marker> _buildSimMarkers(
    BuildContext context,
    SimulationNotifier sim,
  ) {
    return sim.simNodes.map((node) {
      return Marker(
        point: node.position,
        width: 72,
        height: 72,
        child: GestureDetector(
          onTap: () => _showSimNodeDetail(context, node, sim),
          child: _SimNodeMarker(node: node, sim: sim, pulseValue: _pulseAnim.value),
        ),
      );
    }).toList();
  }

  void _showSimNodeDetail(BuildContext context, SimNode node, SimulationNotifier sim) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SimNodeDetailSheet(node: node, sim: sim),
    );
  }

  // ---------------------------------------------------------------------------
  // Markers
  // ---------------------------------------------------------------------------

  List<Marker> _buildMarkers(
    BuildContext context,
    GridTopologyNotifier topo,
  ) {
    final markers = <Marker>[];

    for (final entry in BusGeoData.coordinates.entries) {
      final busId = entry.key;
      final coord = entry.value;
      final node = topo.busNodes[busId];
      if (node == null) continue;

      markers.add(
        Marker(
          point: coord,
          width: _markerWidth(node.type),
          height: _markerHeight(node.type),
          child: GestureDetector(
            onTap: () => _showBusDetail(context, node, topo),
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => _BusMarker(
                node: node,
                pulseValue: _pulseAnim.value,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  double _markerWidth(BusType type) {
    switch (type) {
      case BusType.substation:
        return 48;
      case BusType.bess:
      case BusType.criticalL1:
      case BusType.criticalL2:
        return 40;
      case BusType.normal:
        return 18;
    }
  }

  double _markerHeight(BusType type) {
    switch (type) {
      case BusType.substation:
        return 48;
      case BusType.bess:
      case BusType.criticalL1:
      case BusType.criticalL2:
        return 40;
      case BusType.normal:
        return 18;
    }
  }

  // ---------------------------------------------------------------------------
  // Bus detail bottom sheet
  // ---------------------------------------------------------------------------

  void _showBusDetail(
    BuildContext context,
    BusNodeState node,
    GridTopologyNotifier topo,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BusDetailSheet(node: node, topo: topo),
    );
  }
}

// ---------------------------------------------------------------------------
// Map AppBar overlay
// ---------------------------------------------------------------------------

class _MapAppBar extends StatelessWidget {
  const _MapAppBar({required this.hasEmergency});
  final bool hasEmergency;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D1A).withAlpha(230),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          const Icon(Icons.map, color: Colors.indigo, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Harita · Singularity',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (hasEmergency) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: const Text(
                '⚡ ARIZA',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emergency / status panel at the bottom of the map
// ---------------------------------------------------------------------------

class _EmergencyPanel extends StatelessWidget {
  const _EmergencyPanel({required this.topo});
  final GridTopologyNotifier topo;

  @override
  Widget build(BuildContext context) {
    final faultLineCount = topo.failedLineKeys.length ~/ 2; // stored bidirectional
    final feedingCount = topo.busNodes.values
        .where((n) => n.status == BusStatus.feeding)
        .length;

    return Container(
      color: const Color(0xFF0D0D1A).withAlpha(220),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 10,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PanelStat(
            icon: Icons.warning_amber_rounded,
            color: faultLineCount > 0 ? Colors.red : Colors.white38,
            label: 'Arızalı Hat',
            value: faultLineCount.toString(),
          ),
          _PanelStat(
            icon: Icons.battery_charging_full,
            color: feedingCount > 0 ? Colors.green : Colors.white38,
            label: 'Aktif BESS',
            value: feedingCount.toString(),
          ),
          _PanelStat(
            icon: Icons.electric_bolt,
            color: Colors.indigo.shade300,
            label: 'Toplam Hat',
            value: '${BusGeoData.lines.length}',
          ),
          _PanelStat(
            icon: Icons.account_tree_outlined,
            color: Colors.cyan.shade300,
            label: 'Düğüm',
            value: '${BusGeoData.coordinates.length}',
          ),
        ],
      ),
    );
  }
}

class _PanelStat extends StatelessWidget {
  const _PanelStat({
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual bus marker widget
// ---------------------------------------------------------------------------

class _BusMarker extends StatelessWidget {
  const _BusMarker({required this.node, required this.pulseValue});

  final BusNodeState node;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    switch (node.type) {
      case BusType.substation:
        return _substationMarker();
      case BusType.bess:
        return _bessMarker();
      case BusType.criticalL1:
        return _criticalL1Marker();
      case BusType.criticalL2:
        return _criticalL2Marker();
      case BusType.normal:
        return _normalMarker();
    }
  }

  Widget _substationMarker() {
    return _solidCircle(
      color: const Color(0xFFF6BE00),
      child: const Icon(Icons.bolt, color: Colors.white, size: 28),
      size: 48,
    );
  }

  Widget _bessMarker() {
    final soc = node.socPercent ?? 80.0;

    return Stack(
      alignment: Alignment.topRight,
      clipBehavior: Clip.none,
      children: [
        _solidCircle(
          color: const Color(0xFF27AE60),
          child: const Icon(Icons.battery_charging_full, color: Colors.white, size: 24),
          size: 40,
        ),
        Positioned(
          top: -2,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Text(
              '${soc.toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _criticalL1Marker() {
    return _solidCircle(
      color: const Color(0xFFE74C3C),
      child: const Icon(Icons.add, color: Colors.white, size: 28),
      size: 40,
    );
  }

  Widget _criticalL2Marker() {
    return _solidCircle(
      color: const Color(0xFF2E86C1),
      child: const Icon(Icons.school, color: Colors.white, size: 22),
      size: 40,
    );
  }

  Widget _normalMarker() {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: Color(0xFF95A5A6),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _solidCircle({
    required Color color,
    required Widget child,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Bus detail bottom sheet
// ---------------------------------------------------------------------------

class _BusDetailSheet extends StatelessWidget {
  const _BusDetailSheet({required this.node, required this.topo});

  final BusNodeState node;
  final GridTopologyNotifier topo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bus ID + type row
          Row(
            children: [
              _typeIcon(),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bus ${node.busId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _typeLabel(),
                    style: TextStyle(
                      color: _typeColor().withAlpha(200),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _statusBadge(),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Details grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DetailChip(
                label: 'Durum',
                value: _statusLabel(),
                color: _statusColor(),
              ),
              if (node.socPercent != null)
                _DetailChip(
                  label: 'Doluluk',
                  value: '${node.socPercent!.toStringAsFixed(1)}%',
                  color: Colors.green,
                ),
              if (node.type == BusType.criticalL1)
                const _DetailChip(
                  label: 'Öncelik',
                  value: 'Acil Öncelik L1',
                  color: Colors.red,
                ),
              if (node.type == BusType.criticalL2)
                const _DetailChip(
                  label: 'Öncelik',
                  value: 'Acil Öncelik L2',
                  color: Colors.blue,
                ),
            ],
          ),

          if (node.type != BusType.substation && node.type != BusType.criticalL1 && node.type != BusType.criticalL2)
            ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (node.type == BusType.bess) {
                      topo.removeBess(node.busId);
                    } else {
                      topo.addBess(node.busId);
                    }
                    Navigator.of(context).pop();
                  },
                  icon: Icon(
                    node.type == BusType.bess ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    color: node.type == BusType.bess ? Colors.redAccent : Colors.greenAccent,
                  ),
                  label: Text(
                    node.type == BusType.bess ? 'BESS Kaldır' : 'BESS Ekle',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: node.type == BusType.bess ? Colors.red.withAlpha(40) : Colors.green.withAlpha(40),
                    foregroundColor: node.type == BusType.bess ? Colors.redAccent : Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

          // Feeding flows involving this bus
          ..._buildFeedingInfo(context),
        ],
      ),
    );
  }

  List<Widget> _buildFeedingInfo(BuildContext context) {
    final flows = topo.feedingFlows
        .where((f) => f.fromBus == node.busId || f.toBus == node.busId)
        .toList();

    if (flows.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      const Text(
        'Enerji Akışları',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 8),
      ...flows.map(
        (f) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.arrow_forward, color: Colors.greenAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                'Bus ${f.fromBus} → Bus ${f.toBus}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${f.amountWh} Wh',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _typeIcon() {
    final color = _typeColor();
    IconData icon;
    switch (node.type) {
      case BusType.substation:
        icon = Icons.bolt;
      case BusType.bess:
        icon = Icons.battery_charging_full;
      case BusType.criticalL1:
        icon = Icons.local_hospital;
      case BusType.criticalL2:
        icon = Icons.school;
      case BusType.normal:
        icon = Icons.circle;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        shape: BoxShape.circle,
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _statusBadge() {
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        _statusLabel(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _typeLabel() {
    switch (node.type) {
      case BusType.substation:
        return 'Trafo';
      case BusType.bess:
        return 'BESS';
      case BusType.criticalL1:
        return 'Hastane';
      case BusType.criticalL2:
        return 'Okul';
      case BusType.normal:
        return 'Yük Noktası';
    }
  }

  String _statusLabel() {
    switch (node.status) {
      case BusStatus.normal:
        return 'Normal';
      case BusStatus.islanded:
        return 'Adalanmış';
      case BusStatus.feeding:
        return 'Enerji Besliyor';
      case BusStatus.offline:
        return 'Çevrimdışı';
    }
  }

  Color _typeColor() {
    switch (node.type) {
      case BusType.substation:
        return Colors.amber;
      case BusType.bess:
        return Colors.green;
      case BusType.criticalL1:
        return Colors.red;
      case BusType.criticalL2:
        return Colors.blue;
      case BusType.normal:
        return Colors.grey;
    }
  }

  Color _statusColor() {
    switch (node.status) {
      case BusStatus.normal:
        return Colors.green;
      case BusStatus.islanded:
        return Colors.orange;
      case BusStatus.feeding:
        return Colors.greenAccent;
      case BusStatus.offline:
        return Colors.red;
    }
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Simulation node marker
// ===========================================================================

class _SimNodeMarker extends StatelessWidget {
  const _SimNodeMarker({
    required this.node,
    required this.sim,
    required this.pulseValue,
  });

  final SimNode node;
  final SimulationNotifier sim;
  final double pulseValue;

  Color get _baseColor {
    switch (node.type) {
      case SimNodeType.producer:
        return node.id == 'sim_p1' ? Colors.amber : Colors.cyan;
      case SimNodeType.house:
        return Colors.deepPurple;
      case SimNodeType.battery:
        return Colors.tealAccent;
    }
  }

  IconData get _icon {
    switch (node.type) {
      case SimNodeType.producer:
        return node.id == 'sim_p1' ? Icons.wb_sunny : Icons.air;
      case SimNodeType.house:
        return Icons.home;
      case SimNodeType.battery:
        return Icons.battery_charging_full;
    }
  }

  bool get _isActive {
    return sim.activeContracts.any(
      (c) =>
          (c.fromNodeId == node.id || c.toNodeId == node.id) &&
          c.status == ContractStatus.active,
    );
  }

  @override
  Widget build(BuildContext context) {
    final glowIntensity = _isActive ? pulseValue : 0.5;
    final color = _baseColor;

    return Stack(
      alignment: Alignment.topRight,
      children: [
        // Main circle
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.withAlpha((_isActive ? 230 : 180).toInt()),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(80), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha((glowIntensity * 180).toInt()),
                blurRadius: 14,
                spreadRadius: _isActive ? 4 : 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(_icon, color: Colors.white, size: 24),
          ),
        ),

        // Label tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _shortLabel,
            style: TextStyle(
              color: color,
              fontSize: 7,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        // Battery SOC bar
        if (node.type == SimNodeType.battery)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BatterySocBar(soc: sim.animatedSoc),
          ),
      ],
    );
  }

  String get _shortLabel {
    switch (node.type) {
      case SimNodeType.producer:
        return node.id == 'sim_p1' ? '☀️ P1' : '💨 P2';
      case SimNodeType.house:
        return '🏠 Ev';
      case SimNodeType.battery:
        return '🔋 ${sim.animatedSoc.toInt()}%';
    }
  }
}

// ---------------------------------------------------------------------------
// Battery mini bar
// ---------------------------------------------------------------------------

class _BatterySocBar extends StatelessWidget {
  const _BatterySocBar({required this.soc});
  final double soc;

  @override
  Widget build(BuildContext context) {
    final fraction = (soc / 100).clamp(0.0, 1.0);
    final color = soc < 30 ? Colors.red : Colors.tealAccent;

    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Simulation node detail bottom sheet
// ===========================================================================

class _SimNodeDetailSheet extends StatelessWidget {
  const _SimNodeDetailSheet({required this.node, required this.sim});
  final SimNode node;
  final SimulationNotifier sim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              Icon(_typeIcon, color: _typeColor, size: 28),
              const SizedBox(width: 12),
              Text(
                node.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _typeColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _typeColor.withAlpha(80)),
                ),
                child: Text(
                  _typeLabel,
                  style: TextStyle(
                    color: _typeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Details
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _chips,
          ),
        ],
      ),
    );
  }

  List<Widget> get _chips {
    switch (node.type) {
      case SimNodeType.producer:
        return [
          _Chip('Kapasite', '${node.capacityKwh.toStringAsFixed(0)} kWh', Colors.amber),
          _Chip('Fiyat', '${node.pricePerKwh.toStringAsFixed(1)} MON/kWh', Colors.orange),
        ];
      case SimNodeType.house:
        return [
          _Chip('İhtiyaç', '${node.demandKwh.toStringAsFixed(0)} kWh', Colors.deepPurple),
        ];
      case SimNodeType.battery:
        return [
          _Chip('Maks Kapasite', '${node.maxCapacityKwh.toStringAsFixed(0)} kWh', Colors.tealAccent),
          _Chip('Mevcut SOC', '${sim.animatedSoc.toStringAsFixed(1)}%', sim.animatedSoc < node.thresholdPercent ? Colors.red : Colors.tealAccent),
          _Chip('Eşik', '${node.thresholdPercent.toStringAsFixed(0)}%', Colors.orange),
        ];
    }
  }

  IconData get _typeIcon {
    switch (node.type) {
      case SimNodeType.producer:
        return node.id == 'sim_p1' ? Icons.wb_sunny : Icons.air;
      case SimNodeType.house:
        return Icons.home;
      case SimNodeType.battery:
        return Icons.battery_charging_full;
    }
  }

  Color get _typeColor {
    switch (node.type) {
      case SimNodeType.producer:
        return node.id == 'sim_p1' ? Colors.amber : Colors.cyan;
      case SimNodeType.house:
        return Colors.deepPurple.shade200;
      case SimNodeType.battery:
        return Colors.tealAccent;
    }
  }

  String get _typeLabel {
    switch (node.type) {
      case SimNodeType.producer:
        return 'Enerji Üreticisi';
      case SimNodeType.house:
        return 'Tüketici';
      case SimNodeType.battery:
        return 'Batarya';
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
