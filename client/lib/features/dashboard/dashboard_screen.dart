import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/bess_state.dart';
import '../../core/models/wallet_state.dart';
import 'widgets/earnings_card.dart';
import 'widgets/emergency_banner.dart';
import 'widgets/event_log_list.dart';
import 'widgets/soc_gauge.dart';

/// BESS monitoring dashboard.
///
/// Rebuilds via [Consumer]<[BESSStateNotifier]> whenever new WebSocket events
/// arrive. The layout stacks:
///
///   1. [EmergencyBanner] — only visible in emergency mode.
///   2. [SOCGauge] — circular charge level indicator.
///   3. [EarningsCard] — cumulative on-chain earnings.
///   4. [EventLogList] — last received event type and timestamp.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletState = context.watch<WalletStateNotifier>().state;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            const Text(
              'BESS Paneli',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          // Connected wallet chip + disconnect button
          if (walletState.isConnected)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _WalletChip(walletState: walletState),
            ),
        ],
      ),
      body: Consumer<BESSStateNotifier>(
        builder: (context, notifier, _) {
          final state = notifier.state;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Emergency banner is only shown when relevant.
                if (state.emergencyMode) const EmergencyBanner(),

                const SizedBox(height: 32),

                // SOC gauge — centred horizontally.
                Center(
                  child: SOCGauge(soc: state.socPercent),
                ),

                const SizedBox(height: 24),

                EarningsCard(earningsWei: state.earningsWei),

                EventLogList(
                  lastEventType: state.lastEventType,
                  lastTimestampMs: state.lastTimestampMs,
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wallet chip shown in AppBar
// ---------------------------------------------------------------------------

class _WalletChip extends StatelessWidget {
  const _WalletChip({required this.walletState});

  final WalletState walletState;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDisconnectDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.indigo.withAlpha(40),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.indigo.withAlpha(80), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (walletState.isDemo)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.science_outlined,
                    size: 12, color: Colors.orange),
              ),
            Text(
              walletState.shortAddress,
              style: const TextStyle(
                color: Colors.indigo,
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisconnectDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Cüzdan Bağlantısını Kes',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${context.read<WalletStateNotifier>().state.address ?? ""}\n\n'
          'Bu cihazdan çıkış yapmak istiyor musunuz?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<WalletStateNotifier>().disconnect();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}
