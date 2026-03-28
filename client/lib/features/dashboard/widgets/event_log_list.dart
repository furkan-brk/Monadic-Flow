import 'package:flutter/material.dart';

/// Displays the most recent backend event — its type and timestamp.
///
/// When no event has been received yet (e.g. backend not running) it shows a
/// "Connecting…" placeholder so the operator always sees connection status.
class EventLogList extends StatelessWidget {
  const EventLogList({
    super.key,
    required this.lastEventType,
    required this.lastTimestampMs,
  });

  final String? lastEventType;
  final int? lastTimestampMs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Event',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (lastEventType == null)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Connecting to backend\u2026',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              )
            else ...[
              _EventChip(eventType: lastEventType!),
              const SizedBox(height: 6),
              if (lastTimestampMs != null)
                Text(
                  _formatTimestamp(lastTimestampMs!),
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return '${dt.toIso8601String().replaceFirst('T', ' ').substring(0, 19)} UTC';
  }
}

/// Small chip that colour-codes event types for quick recognition.
class _EventChip extends StatelessWidget {
  const _EventChip({required this.eventType});

  final String eventType;

  Color _chipColor() {
    switch (eventType) {
      case 'EmergencyActivated':
        return Colors.red;
      case 'TransferSettled':
        return Colors.blue;
      case 'SOCUpdate':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _chipColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color.withAlpha(120)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        eventType,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
