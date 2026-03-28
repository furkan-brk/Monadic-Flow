import 'package:flutter/material.dart';

/// Legend row matching the IEEE 33-bus diagram colour scheme.
///
/// Place at the bottom of [GridTopologyScreen] to explain node colours.
class GridLegend extends StatelessWidget {
  const GridLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16162C).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withAlpha(30), width: 1),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: const [
          _LegendDot(color: Color(0xFFFF8C00), label: '1. Kritik'),
          _LegendDot(color: Color(0xFFFF69B4), label: '2. Kritik'),
          _LegendDot(color: Color(0xFF66BB6A), label: 'BESS'),
          _LegendDot(color: Colors.cyan, label: 'Normal'),
          _LegendDot(color: Color(0xFF1565C0), label: 'Trafo'),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
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
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.redAccent.withAlpha(80)),
          ),
          child: const Center(
            child: Icon(Icons.close, color: Colors.redAccent, size: 10),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Hat Arızası',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
