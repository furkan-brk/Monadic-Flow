import 'package:flutter/material.dart';

/// Circular gauge showing the battery state-of-charge percentage.
///
/// The ring colour transitions from red (<20 %) → yellow (<50 %) → green
/// to give an at-a-glance health indication.
class SOCGauge extends StatelessWidget {
  const SOCGauge({super.key, required this.soc});

  /// State-of-charge in the range 0–100.
  final double soc;

  Color _gaugeColor() {
    if (soc >= 50) return Colors.green;
    if (soc >= 20) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = _gaugeColor();
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator.adaptive(
                value: (soc / 100).clamp(0.0, 1.0),
                strokeWidth: 12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: color.withAlpha(50),
              ),
              Center(
                child: Text(
                  '${soc.toStringAsFixed(1)}%',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Battery State of Charge',
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
