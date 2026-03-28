import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/models/community_state.dart';

/// Trade Profile chart — custom-painted price/volume history over 10 time slots.
///
/// Renders entirely with [Canvas] / [CustomPainter]; no external chart package.
/// Mock price data is derived from [CommunitySnapshot.settlementCount] so it
/// varies realistically between sessions.
class TradeProfileChart extends StatelessWidget {
  const TradeProfileChart({super.key, required this.snapshot});

  final CommunitySnapshot snapshot;

  /// Generate 10 mock price points anchored to [settlementCount].
  List<double> _buildPrices() {
    final seed = snapshot.settlementCount;
    final rng = math.Random(seed);
    return List.generate(10, (i) {
      // Simulate a price time series with random walk + mean reversion.
      final base = 8.0 + (seed % 5);
      final noise = (rng.nextDouble() - 0.5) * 6.0;
      // If emergency and last slot: spike to ~40 ¢/kWh.
      if (snapshot.isEmergency && i == 9) return 40.0;
      return (base + noise + i * 0.3).clamp(2.0, 30.0);
    });
  }

  /// Generate mock relative volume (0–1) for each slot.
  List<double> _buildVolumes() {
    final seed = snapshot.settlementCount + 7;
    final rng = math.Random(seed);
    return List.generate(10, (i) {
      if (snapshot.isEmergency && i == 9) return 1.0;
      return 0.2 + rng.nextDouble() * 0.8;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prices = _buildPrices();
    final volumes = _buildVolumes();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withAlpha(60), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.timeline, color: Colors.indigo, size: 18),
              const SizedBox(width: 8),
              const Text(
                'İşlem Profili',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (snapshot.isEmergency)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withAlpha(80)),
                  ),
                  child: const Text(
                    'FİYAT ARTIŞI',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (!snapshot.isEmergency)
                const Text(
                  '¢/kWh',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Canvas chart ─────────────────────────────────────────────────
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _TradeProfilePainter(
                prices: prices,
                volumes: volumes,
                isEmergency: snapshot.isEmergency,
              ),
              size: Size.infinite,
            ),
          ),

          const SizedBox(height: 8),

          // ── X-axis labels ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              10,
              (i) => Text(
                'T-${9 - i}',
                style: TextStyle(
                  color: (i == 9 && snapshot.isEmergency)
                      ? Colors.red
                      : Colors.white24,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _TradeProfilePainter extends CustomPainter {
  _TradeProfilePainter({
    required this.prices,
    required this.volumes,
    required this.isEmergency,
  });

  final List<double> prices;
  final List<double> volumes;
  final bool isEmergency;

  static const double _yMin = 0.0;
  static const double _yMax = 30.0;
  static const double _yMaxEmergency = 45.0;
  static const double _chartBottomFraction = 0.75; // top 75% for price line
  static const double _volumeTopFraction = 0.80;   // bottom 20% for bars

  @override
  void paint(Canvas canvas, Size size) {
    final maxPrice = isEmergency ? _yMaxEmergency : _yMax;
    final chartH = size.height * _chartBottomFraction;
    final volAreaTop = size.height * _volumeTopFraction;
    final volAreaH = size.height - volAreaTop;
    final slotW = size.width / (prices.length - 1);

    // ── Y-axis grid lines ─────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int step = 0; step <= 3; step++) {
      final y = chartH * (1 - step / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // Y-axis label
      final label = '${(maxPrice * step / 3).toStringAsFixed(0)}¢';
      _drawText(
        canvas,
        label,
        Offset(2, y - 10),
        const TextStyle(color: Colors.white24, fontSize: 8),
      );
    }

    // ── Volume bars ───────────────────────────────────────────────────────
    final volBarW = size.width / prices.length * 0.6;
    for (int i = 0; i < volumes.length; i++) {
      final x = i * size.width / (prices.length - 1);
      final barH = volAreaH * volumes[i];
      final barTop = volAreaTop + (volAreaH - barH);
      final isLast = i == prices.length - 1;

      final volPaint = Paint()
        ..color = (isLast && isEmergency)
            ? Colors.red.withAlpha(120)
            : Colors.white.withAlpha(30)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - volBarW / 2, barTop, volBarW, barH),
          const Radius.circular(2),
        ),
        volPaint,
      );
    }

    // ── Emergency vertical marker at T-0 ─────────────────────────────────
    if (isEmergency) {
      final emPaint = Paint()
        ..color = Colors.red.withAlpha(120)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height),
        emPaint,
      );
    }

    // ── Filled area under price line ──────────────────────────────────────
    final fillPath = Path();
    for (int i = 0; i < prices.length; i++) {
      final x = i * slotW;
      final y = chartH * (1 - (prices[i] - _yMin) / (maxPrice - _yMin));
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo((prices.length - 1) * slotW, chartH);
    fillPath.lineTo(0, chartH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.indigo.withAlpha(isEmergency ? 60 : 90),
          Colors.indigo.withAlpha(10),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // ── Price line ────────────────────────────────────────────────────────
    final linePath = Path();
    for (int i = 0; i < prices.length; i++) {
      final x = i * slotW;
      final y = chartH * (1 - (prices[i] - _yMin) / (maxPrice - _yMin));
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = isEmergency ? Colors.orange : Colors.indigoAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // ── Price point dots ──────────────────────────────────────────────────
    final dotPaint = Paint()
      ..color = isEmergency ? Colors.orange : Colors.white
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF0D0D2A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < prices.length; i++) {
      final x = i * slotW;
      final y = chartH * (1 - (prices[i] - _yMin) / (maxPrice - _yMin));
      if (i == prices.length - 1 || i == 0) {
        canvas.drawCircle(Offset(x, y), 4.0, dotPaint);
        canvas.drawCircle(Offset(x, y), 4.0, dotBorderPaint);
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(
        textDirection: TextDirection.ltr,
        fontSize: style.fontSize ?? 10,
      ),
    )
      ..pushStyle(style.getTextStyle())
      ..addText(text);
    final paragraph = paragraphBuilder.build()
      ..layout(const ParagraphConstraints(width: 40));
    canvas.drawParagraph(paragraph, offset);
  }

  @override
  bool shouldRepaint(_TradeProfilePainter oldDelegate) {
    return oldDelegate.prices != prices ||
        oldDelegate.isEmergency != isEmergency;
  }
}
