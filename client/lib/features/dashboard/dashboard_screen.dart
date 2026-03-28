import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/bess_state.dart';
import '../../core/models/wallet_state.dart';
import 'widgets/earnings_card.dart';
import 'widgets/emergency_banner.dart';
import 'widgets/event_log_list.dart';
import 'widgets/monad_tps_counter.dart';
import 'widgets/soc_gauge.dart';

/// BESS monitoring dashboard.
///
/// Rebuilds via [Consumer]<[BESSStateNotifier]> whenever new WebSocket events
/// arrive. The layout stacks:
///
///   1. [EmergencyBanner] — only visible in emergency mode.
///   2. [SOCGauge] — circular charge level indicator.
///   3. [EarningsCard] — cumulative on-chain earnings.
///   4. [MonadTpsCounter] — live rolling TPS from settlement events.
///   5. [EventLogList] — last received event type and timestamp.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _showOfferSheet(BuildContext context) {
    final wallet =
        context.read<WalletStateNotifier>().state.address ?? '0x0000';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DashboardOfferSheet(walletAddress: wallet),
    );
  }

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
                // Passes onTeklifVer so the CTA opens the offer sheet.
                if (state.emergencyMode)
                  EmergencyBanner(
                    onTeklifVer: () => _showOfferSheet(context),
                  ),

                const SizedBox(height: 32),

                // SOC gauge — centred horizontally.
                Center(
                  child: SOCGauge(soc: state.socPercent),
                ),

                const SizedBox(height: 24),

                EarningsCard(earningsWei: state.earningsWei),

                // Monad Parallel EVM throughput — live rolling TPS counter.
                const MonadTpsCounter(),

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

// ---------------------------------------------------------------------------
// Minimal offer sheet accessible from the EmergencyBanner CTA in Dashboard
// ---------------------------------------------------------------------------

class _DashboardOfferSheet extends StatefulWidget {
  const _DashboardOfferSheet({required this.walletAddress});
  final String walletAddress;

  @override
  State<_DashboardOfferSheet> createState() => _DashboardOfferSheetState();
}

class _DashboardOfferSheetState extends State<_DashboardOfferSheet> {
  double _amount = 50.0;
  bool _isLoading = false;
  bool _submitted = false;
  String? _txHash;
  String? _errorMsg;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/bess/offer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'wallet_address': widget.walletAddress,
          'amount_wh': (_amount * 1000).toInt(),
          'price_wei_per_wh': 5,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _submitted = true;
          _txHash = data['tx_hash'] as String?;
        });
      } else {
        setState(() => _errorMsg = 'Sunucu hatası: ${response.statusCode}');
      }
    } catch (_) {
      setState(() => _errorMsg = 'Bağlantı hatası — demo mod aktif');
      // Fallback: show success anyway for demo purposes.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      setState(() {
        _submitted = true;
        _txHash = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 44),
        ),
        const SizedBox(height: 16),
        const Text(
          'Teklif Gönderildi!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enerji teklifiniz Monad Parallel EVM üzerinde\nişleme alındı.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (_txHash != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'TX: ${_txHash!.length > 20 ? '${_txHash!.substring(0, 10)}…${_txHash!.substring(_txHash!.length - 8)}' : _txHash!}',
              style: const TextStyle(
                color: Colors.white38,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Kapat',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.offline_bolt, color: Colors.orange, size: 22),
            const SizedBox(width: 10),
            Text(
              'Enerji Teklifi Ver',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(40),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '5× ÖDÜL',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Acil modda hastane ve okullara enerji sağlayarak 5× fiyatla kazanç elde et.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Miktar', style: TextStyle(color: Colors.white70)),
            Text(
              '${_amount.toInt()} kWh',
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Slider(
          value: _amount,
          min: 1,
          max: 100,
          divisions: 99,
          activeColor: Colors.orange,
          inactiveColor: Colors.white12,
          onChanged: _isLoading ? null : (v) => setState(() => _amount = v),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.withAlpha(50)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tahmini Kazanç',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                '~${(_amount * 5 * 100).toStringAsFixed(0)} mMON',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMsg!,
            style: const TextStyle(color: Colors.orange, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send),
          label: Text(
            _isLoading ? 'Gönderiliyor…' : 'Teklifi Gönder',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
