import 'package:flutter/material.dart';

/// Card displaying cumulative BESS earnings, converted from wei to Gwei.
class EarningsCard extends StatelessWidget {
  const EarningsCard({super.key, required this.earningsWei});

  /// Cumulative earnings expressed in wei.
  final int earningsWei;

  /// Converts wei to Gwei for a more human-readable value.
  ///
  /// 1 Gwei = 1 × 10⁹ wei.
  double get _earningsGwei => earningsWei / 1e9;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('\ud83d\udcb0', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Total Earnings',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_earningsGwei.toStringAsFixed(4)} Gwei',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'on Monad Testnet',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
