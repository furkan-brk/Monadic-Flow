import 'package:flutter/material.dart';

/// Legend row matching the IEEE 33-bus diagram colour scheme.
///
/// Place at the bottom of [GridTopologyScreen] to explain node colours.
class GridLegend extends StatelessWidget {
  const GridLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 12,
        runSpacing: 4,
        children: const [
          _LegendDot(color: Color(0xFFFF8C00), label: '1st Critical'),
          _LegendDot(color: Color(0xFFFF69B4), label: '2nd Critical'),
          _LegendDot(color: Color(0xFF66BB6A), label: 'BESS'),
          _LegendDot(color: Colors.cyan, label: 'Normal'),
          _LegendDot(color: Color(0xFF1565C0), label: 'Substation'),
          _LegendX(),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}

class _LegendX extends StatelessWidget {
  const _LegendX();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.close, color: Colors.red, size: 9),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'Line Fail',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}
