import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/grid_state.dart';

/// [CustomPainter] that renders the IEEE 33-bus test feeder topology onto a
/// Flutter [Canvas].
///
/// Layout matches the WhatsApp schematic:
/// - Main trunk (buses 1-18) runs left → right at y≈50%.
/// - Lateral A1 (buses 19-22) hangs below the trunk from Bus 2.
/// - Lateral A2 (buses 23-25) rises above the trunk from Bus 3.
/// - Lateral B  (buses 26-33) rises further above the trunk from Bus 6.
///
/// All positions are normalised to [0, 1] × [0, 1] and scaled to the actual
/// canvas [Size] at paint time.  Wrap this painter in an [InteractiveViewer]
/// for zoom/pan.
///
/// Repaint is driven by [Animation<double> flowAnimation] (0→1 loop) so that
/// feeding-flow dots animate smoothly without requiring a full [setState].
class Ieee33BusPainter extends CustomPainter {
  Ieee33BusPainter({
    required this.busNodes,
    required this.failedLineKeys,
    required this.feedingFlows,
    required this.flowAnimation,
  }) : super(repaint: flowAnimation);

  final Map<int, BusNodeState> busNodes;
  final Set<String> failedLineKeys;
  final List<FeedingFlow> feedingFlows;
  final Animation<double> flowAnimation;

  // -------------------------------------------------------------------------
  // Normalised node positions  (x ∈ [0,1], y ∈ [0,1])
  // -------------------------------------------------------------------------

  static const Map<int, Offset> _pos = {
    // Main trunk (y ≈ 0.50)
    1:  Offset(0.09, 0.50),
    2:  Offset(0.15, 0.50),
    3:  Offset(0.21, 0.50),
    4:  Offset(0.27, 0.50),
    5:  Offset(0.33, 0.50),
    6:  Offset(0.39, 0.50),
    7:  Offset(0.45, 0.50),
    8:  Offset(0.50, 0.50),
    9:  Offset(0.55, 0.50),
    10: Offset(0.59, 0.50),
    11: Offset(0.63, 0.50),
    12: Offset(0.67, 0.50),
    13: Offset(0.71, 0.50),
    14: Offset(0.75, 0.50),
    15: Offset(0.79, 0.50),
    16: Offset(0.83, 0.50),
    17: Offset(0.87, 0.50),
    18: Offset(0.91, 0.50),
    // Lateral A1 — below trunk, from Bus 2
    19: Offset(0.15, 0.78),
    20: Offset(0.21, 0.78),
    21: Offset(0.27, 0.78),
    22: Offset(0.33, 0.78),
    // Lateral A2 — above trunk, from Bus 3
    23: Offset(0.21, 0.25),
    24: Offset(0.27, 0.25),
    25: Offset(0.33, 0.25),
    // Lateral B — top of diagram, from Bus 6
    26: Offset(0.39, 0.13),
    27: Offset(0.45, 0.13),
    28: Offset(0.50, 0.13),
    29: Offset(0.55, 0.13),
    30: Offset(0.59, 0.13),
    31: Offset(0.63, 0.13),
    32: Offset(0.67, 0.13),
    33: Offset(0.71, 0.13),
  };

  /// Grid source icon position (left of Bus 1).
  static const Offset _gridPos = Offset(0.03, 0.50);

  // -------------------------------------------------------------------------
  // Adjacency list — matches IEEE 33-bus standard topology
  // -------------------------------------------------------------------------

  static const List<List<int>> _lines = [
    // Main trunk
    [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9],
    [9, 10], [10, 11], [11, 12], [12, 13], [13, 14], [14, 15], [15, 16],
    [16, 17], [17, 18],
    // Lateral A1
    [2, 19], [19, 20], [20, 21], [21, 22],
    // Lateral A2
    [3, 23], [23, 24], [24, 25],
    // Lateral B
    [6, 26], [26, 27], [27, 28], [28, 29], [29, 30], [30, 31], [31, 32], [32, 33],
  ];

  // -------------------------------------------------------------------------
  // Paint
  // -------------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw all feeder lines (grey; dashed-red if failed).
    for (final pair in _lines) {
      final a = pair[0], b = pair[1];
      final p1 = _s(_pos[a]!, size);
      final p2 = _s(_pos[b]!, size);
      final isFailed =
          failedLineKeys.contains('$a-$b') || failedLineKeys.contains('$b-$a');
      if (isFailed) {
        _drawDashedLine(canvas, p1, p2, Colors.red, strokeWidth: 2.5);
      } else {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = Colors.grey.shade400
            ..strokeWidth = 1.5,
        );
      }
    }

    // 2. Draw animated energy flow dots along active feeding paths.
    final t = flowAnimation.value;
    for (final flow in feedingFlows) {
      final from = _pos[flow.fromBus];
      final to = _pos[flow.toBus];
      if (from != null && to != null) {
        _drawAnimatedFlow(canvas, _s(from, size), _s(to, size), t);
      }
    }

    // 3. Draw ✕ markers at midpoints of failed lines.
    for (final key in failedLineKeys) {
      final parts = key.split('-');
      if (parts.length != 2) continue;
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      if (a == null || b == null) continue;
      // Only draw for the canonical direction (a < b) to avoid duplicates.
      if (a >= b) continue;
      final pa = _pos[a];
      final pb = _pos[b];
      if (pa != null && pb != null) {
        final mid = Offset(
          (pa.dx + pb.dx) / 2,
          (pa.dy + pb.dy) / 2,
        );
        _drawFailX(canvas, _s(mid, size));
      }
    }

    // 4. Draw grid source icon and its connection line to Bus 1.
    final gridPx = _s(_gridPos, size);
    final bus1Px = _s(_pos[1]!, size);
    canvas.drawLine(
      gridPx,
      bus1Px,
      Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1.5,
    );
    _drawGridIcon(canvas, gridPx);

    // 5. Draw bus nodes (on top of lines).
    for (final entry in busNodes.entries) {
      final pos = _pos[entry.key];
      if (pos == null) continue;
      _drawBusNode(canvas, _s(pos, size), entry.value);
    }
  }

  // -------------------------------------------------------------------------
  // Node rendering helpers
  // -------------------------------------------------------------------------

  void _drawBusNode(Canvas canvas, Offset px, BusNodeState node) {
    final isBess = node.type == BusType.bess;
    final isCritical =
        node.type == BusType.criticalL1 || node.type == BusType.criticalL2;
    final radius = (isBess || isCritical) ? 13.0 : 9.0;
    final color = _colorForBus(node);

    // Glow ring for feeding / islanded state.
    if (node.status == BusStatus.feeding) {
      canvas.drawCircle(
        px,
        radius + 5,
        Paint()
          ..color = Colors.greenAccent.withAlpha(80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    } else if (node.status == BusStatus.islanded) {
      canvas.drawCircle(
        px,
        radius + 5,
        Paint()
          ..color = Colors.red.withAlpha(60)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Fill circle.
    canvas.drawCircle(px, radius, Paint()..color = color);

    // White border.
    canvas.drawCircle(
      px,
      radius,
      Paint()
        ..color = Colors.white.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Bus ID label inside the circle.
    _paintText(
      canvas,
      '${node.busId}',
      px,
      fontSize: radius * 0.85,
      color: Colors.white,
      bold: true,
    );

    // SOC label below BESS nodes.
    if (isBess && node.socPercent != null) {
      _paintText(
        canvas,
        '${node.socPercent!.toStringAsFixed(0)}%',
        Offset(px.dx, px.dy + radius + 8),
        fontSize: 8.5,
        color: Colors.white70,
      );
    }
  }

  void _drawGridIcon(Canvas canvas, Offset px) {
    const r = 13.0;
    // Dark blue square.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: px, width: r * 2, height: r * 2),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF1A237E),
    );
    // Lightning bolt "G" label.
    _paintText(canvas, 'G', px, fontSize: 11, color: Colors.white, bold: true);
  }

  // -------------------------------------------------------------------------
  // Line rendering helpers
  // -------------------------------------------------------------------------

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color, {
    double strokeWidth = 2.0,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final delta = to - from;
    final distance = delta.distance;
    if (distance == 0) return;

    const dashLen = 7.0;
    const gapLen = 5.0;
    double traveled = 0;
    bool drawing = true;

    while (traveled < distance) {
      final segLen = drawing ? dashLen : gapLen;
      final end = math.min(traveled + segLen, distance);
      if (drawing) {
        final t0 = traveled / distance;
        final t1 = end / distance;
        canvas.drawLine(
          from + delta * t0,
          from + delta * t1,
          paint,
        );
      }
      traveled += segLen;
      drawing = !drawing;
    }
  }

  /// Draws an animated glowing dot travelling from [from] to [to].
  ///
  /// [t] is the animation value in [0, 1]; the dot is positioned at
  /// `Offset.lerp(from, to, t)`.
  void _drawAnimatedFlow(Canvas canvas, Offset from, Offset to, double t) {
    final pos = Offset.lerp(from, to, t)!;

    // Outer glow.
    canvas.drawCircle(
      pos,
      8,
      Paint()
        ..color = Colors.greenAccent.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Core dot.
    canvas.drawCircle(pos, 4, Paint()..color = Colors.greenAccent);
  }

  void _drawFailX(Canvas canvas, Offset center) {
    // White background disc.
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const r = 6.0;
    canvas.drawLine(
      Offset(center.dx - r, center.dy - r),
      Offset(center.dx + r, center.dy + r),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + r, center.dy - r),
      Offset(center.dx - r, center.dy + r),
      paint,
    );
  }

  // -------------------------------------------------------------------------
  // Utilities
  // -------------------------------------------------------------------------

  /// Scale a normalised [Offset] to canvas pixel coordinates.
  Offset _s(Offset normalised, Size size) =>
      Offset(normalised.dx * size.width, normalised.dy * size.height);

  Color _colorForBus(BusNodeState node) {
    if (node.status == BusStatus.feeding) return Colors.greenAccent.shade400;
    if (node.status == BusStatus.islanded) return Colors.red.shade400;
    return switch (node.type) {
      BusType.criticalL1 => const Color(0xFFFF8C00), // orange — hospital
      BusType.criticalL2 => const Color(0xFFFF69B4), // pink — school
      BusType.bess       => Colors.green.shade400,
      BusType.substation => const Color(0xFF1565C0), // deep blue
      BusType.normal     => Colors.cyan.shade300,
    };
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center, {
    double fontSize = 10,
    Color color = Colors.white,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          // Use a compact font for bus-ID labels inside small circles.
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(Ieee33BusPainter old) =>
      // The Animation<double> repaint is handled by `super(repaint:)`.
      // Additional structural changes also trigger a repaint.
      old.busNodes != busNodes ||
      old.failedLineKeys != failedLineKeys ||
      old.feedingFlows != feedingFlows;
}
