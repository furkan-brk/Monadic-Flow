import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/bess_state.dart';
import '../../../core/models/community_state.dart';
import '../../../core/models/wallet_state.dart';

/// Wallet identity + personal BESS stats card.
///
/// Shows the connected address, SOC from [BESSStateNotifier], personal
/// earnings from the leaderboard, and a "Teklif Ver" (Submit Offer) CTA.
class MyWalletCard extends StatelessWidget {
  const MyWalletCard({
    super.key,
    required this.snapshot,
    required this.onSubmitOffer,
  });

  final CommunitySnapshot snapshot;
  final VoidCallback onSubmitOffer;

  @override
  Widget build(BuildContext context) {
    final walletState = context.watch<WalletStateNotifier>().state;
    final bessState = context.watch<BESSStateNotifier>().state;

    // Find this wallet's leaderboard entry if it exists.
    final myEntry = walletState.address != null
        ? snapshot.leaderboard
            .cast<LeaderboardEntry?>()
            .firstWhere(
              (e) => e!.address.toLowerCase() == walletState.address!.toLowerCase(),
              orElse: () => null,
            )
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withAlpha(60), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.account_circle_outlined,
                  color: Colors.indigo, size: 18),
              const SizedBox(width: 8),
              Text(
                'Benim Cüzdanım',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (walletState.isDemo) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DEMO',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Address row with copy button
          GestureDetector(
            onTap: () {
              if (walletState.address != null) {
                Clipboard.setData(ClipboardData(text: walletState.address!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Adres panoya kopyalandı'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    walletState.address ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy_outlined, color: Colors.white38, size: 14),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _MiniStat(
                label: 'SOC',
                value: '${bessState.socPercent.toStringAsFixed(0)}%',
                icon: Icons.battery_charging_full,
                color: _socColor(bessState.socPercent),
              ),
              const SizedBox(width: 12),
              _MiniStat(
                label: 'Katkı',
                value: myEntry != null
                    ? _formatEnergy(myEntry.totalEnergyWh)
                    : '— Wh',
                icon: Icons.bolt,
                color: Colors.amber,
              ),
              const SizedBox(width: 12),
              _MiniStat(
                label: 'Kazanç',
                value: myEntry != null
                    ? _formatEarnings(myEntry.earningsWei)
                    : '0 mMON',
                icon: Icons.monetization_on_outlined,
                color: Colors.greenAccent,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Submit offer CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: bessState.emergencyMode ? onSubmitOffer : null,
              icon: const Icon(Icons.offline_bolt, size: 18),
              label: Text(
                bessState.emergencyMode
                    ? 'Enerji Teklifi Ver 5×'
                    : 'Acil Mod Bekleniyor…',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: bessState.emergencyMode
                    ? Colors.orange
                    : Colors.grey.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _socColor(double soc) {
    if (soc >= 60) return Colors.green;
    if (soc >= 30) return Colors.amber;
    return Colors.red;
  }

  String _formatEnergy(int wh) {
    if (wh >= 1_000) return '${(wh / 1_000).toStringAsFixed(1)}kWh';
    return '${wh}Wh';
  }

  String _formatEarnings(int wei) {
    final mmon = wei / 1e15;
    if (mmon >= 1000) return '${(mmon / 1000).toStringAsFixed(2)} MON';
    return '${mmon.toStringAsFixed(2)} mMON';
  }
}

// ---------------------------------------------------------------------------
// Mini stat tile
// ---------------------------------------------------------------------------

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
