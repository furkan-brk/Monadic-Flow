import 'package:flutter/material.dart';

import '../../../core/models/community_state.dart';

/// A single row in the live transfer feed.
///
/// Shows: BESS address → Load address, energy amount, earnings, and
/// a relative timestamp.
class TransferFeedTile extends StatelessWidget {
  const TransferFeedTile({
    super.key,
    required this.record,
    required this.index,
  });

  final TransferRecord record;

  /// List index — used to vary the accent colour slightly.
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColors[index % _accentColors.length];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          // Transfer icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.swap_horiz, color: accent, size: 18),
          ),
          const SizedBox(width: 12),

          // Addresses
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BESS → Load
                Row(
                  children: [
                    _AddressChip(label: record.shortBess, color: Colors.cyan),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward, size: 12, color: Colors.white38),
                    ),
                    _AddressChip(
                      label: _shortAddress(record.loadAddress),
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Amount
                Text(
                  '${_formatEnergy(record.amountWh)}  •  ${_timeAgo(record.timestampMs)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          // Earnings
          Text(
            '+${_formatEarnings(record.earningsWei)}',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  static const _accentColors = [
    Colors.cyan,
    Colors.indigo,
    Colors.teal,
    Colors.purple,
    Colors.blue,
  ];

  String _shortAddress(String addr) {
    if (addr.length < 10) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }

  String _formatEnergy(int wh) {
    if (wh >= 1_000) return '${(wh / 1_000).toStringAsFixed(1)} kWh';
    return '$wh Wh';
  }

  String _formatEarnings(int wei) {
    final mmon = wei / 1e15;
    return '${mmon.toStringAsFixed(3)} mMON';
  }

  String _timeAgo(int timestampMs) {
    final delta = DateTime.now().millisecondsSinceEpoch - timestampMs;
    final secs = delta ~/ 1000;
    if (secs < 60) return '${secs}s önce';
    final mins = secs ~/ 60;
    if (mins < 60) return '${mins}dk önce';
    return '${mins ~/ 60}sa önce';
  }
}

// ---------------------------------------------------------------------------
// Address chip
// ---------------------------------------------------------------------------

class _AddressChip extends StatelessWidget {
  const _AddressChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
