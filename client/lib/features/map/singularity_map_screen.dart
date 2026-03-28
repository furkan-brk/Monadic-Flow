import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/grid_state.dart';
import 'models/bus_geo_data.dart';

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
          color: Colors.indigo.withAlpha(180),
          strokeWidth: 2.5,
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
        return 52;
      case BusType.bess:
      case BusType.criticalL1:
      case BusType.criticalL2:
        return 44;
      case BusType.normal:
        return 20;
    }
  }

  double _markerHeight(BusType type) {
    switch (type) {
      case BusType.substation:
        return 52;
      case BusType.bess:
      case BusType.criticalL1:
      case BusType.criticalL2:
        return 44;
      case BusType.normal:
        return 20;
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
    return _glowContainer(
      color: Colors.amber,
      child: const Icon(Icons.bolt, color: Colors.white, size: 26),
    );
  }

  Widget _bessMarker() {
    final soc = node.socPercent ?? 80.0;
    final isFeeding = node.status == BusStatus.feeding;
    final glowColor = isFeeding ? Colors.greenAccent : Colors.green;

    return Stack(
      alignment: Alignment.topRight,
      children: [
        _glowContainer(
          color: glowColor,
          glowIntensity: isFeeding ? pulseValue : 0.5,
          child: Icon(
            Icons.battery_charging_full,
            color: Colors.white,
            size: 20,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${soc.toInt()}%',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _criticalL1Marker() {
    final isIslanded = node.status == BusStatus.islanded;
    return _glowContainer(
      color: isIslanded ? Colors.orange : Colors.red,
      glowIntensity: isIslanded ? pulseValue : 0.6,
      child: const Icon(Icons.local_hospital, color: Colors.white, size: 20),
    );
  }

  Widget _criticalL2Marker() {
    final isIslanded = node.status == BusStatus.islanded;
    return _glowContainer(
      color: isIslanded ? Colors.orange : Colors.blue,
      glowIntensity: isIslanded ? pulseValue : 0.6,
      child: const Icon(Icons.school, color: Colors.white, size: 20),
    );
  }

  Widget _normalMarker() {
    final isIslanded = node.status == BusStatus.islanded;
    final color = isIslanded ? Colors.orange : Colors.grey.shade500;
    return Opacity(
      opacity: isIslanded ? pulseValue : 1.0,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
      ),
    );
  }

  Widget _glowContainer({
    required Color color,
    required Widget child,
    double glowIntensity = 0.6,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(200),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((glowIntensity * 160).toInt()),
            blurRadius: 10,
            spreadRadius: 3,
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
