import 'package:flutter/material.dart';

import '../../../core/models/community_state.dart';

/// Ranked list of BESS providers by cumulative earnings.
///
/// Shows top-5 entries with rank medal, truncated address, energy contributed,
/// and earnings. The connected wallet's entry is highlighted.
class BessLeaderboard extends StatelessWidget {
  const BessLeaderboard({
    super.key,
    required this.entries,
    this.myAddress,
  });

  final List<LeaderboardEntry> entries;

  /// The currently connected wallet address, used to highlight "my" row.
  final String? myAddress;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyLeaderboard();
    }

    final displayed = entries.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'BESS Lider Tablosu',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
        ),
        ...displayed.asMap().entries.map((e) {
          final rank = e.key + 1;
          final entry = e.value;
          final isMe = myAddress != null &&
              entry.address.toLowerCase() == myAddress!.toLowerCase();
          return _LeaderboardRow(
            rank: rank,
            entry: entry,
            isMe: isMe,
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Row widget
// ---------------------------------------------------------------------------

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.indigo.withAlpha(40)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: Colors.indigo.withAlpha(120), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // Rank medal / number
          SizedBox(
            width: 32,
            child: Center(child: _RankBadge(rank: rank)),
          ),
          const SizedBox(width: 12),

          // Address + energy contributed
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.shortAddress,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withAlpha(80),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BEN',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatEnergy(entry.totalEnergyWh)} sağlandı',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          // Earnings
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatEarnings(entry.earningsWei),
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Text(
                'kazanç',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatEnergy(int wh) {
    if (wh >= 1_000) return '${(wh / 1_000).toStringAsFixed(1)} kWh';
    return '$wh Wh';
  }

  String _formatEarnings(int wei) {
    // Show in mMON (milli-MONAD) for readability in hackathon context.
    final mmon = wei / 1e15;
    if (mmon >= 1000) return '${(mmon / 1000).toStringAsFixed(2)} MON';
    return '${mmon.toStringAsFixed(3)} mMON';
  }
}

// ---------------------------------------------------------------------------
// Rank badge
// ---------------------------------------------------------------------------

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    if (rank == 1) {
      return const Text('🥇', style: TextStyle(fontSize: 20));
    } else if (rank == 2) {
      return const Text('🥈', style: TextStyle(fontSize: 20));
    } else if (rank == 3) {
      return const Text('🥉', style: TextStyle(fontSize: 20));
    }
    return Text(
      '#$rank',
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyLeaderboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 40),
            SizedBox(height: 12),
            Text(
              'Henüz transfer yok',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'İlk enerji transferi gerçekleşince lider tablosu burada görünecek.',
              style: TextStyle(color: Colors.white24, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
