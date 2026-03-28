import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/wallet_state.dart';

/// Full-screen wallet onboarding / login screen.
///
/// Two connection paths:
///   1. **Paste address** — user enters their 0x Ethereum address manually.
///      No private key is stored; the app uses the address for display only.
///   2. **Demo mode** — generates a random demo address so the hackathon
///      presentation works without a real wallet.
class WalletConnectScreen extends StatefulWidget {
  const WalletConnectScreen({super.key});

  @override
  State<WalletConnectScreen> createState() => _WalletConnectScreenState();
}

class _WalletConnectScreenState extends State<WalletConnectScreen> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _isConnecting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onConnect() async {
    setState(() {
      _errorText = null;
      _isConnecting = true;
    });

    final notifier = context.read<WalletStateNotifier>();
    final error = await notifier.connect(_controller.text);

    if (!mounted) return;
    setState(() {
      _errorText = error;
      _isConnecting = false;
    });
  }

  Future<void> _onDemoMode() async {
    setState(() => _isConnecting = true);
    await context.read<WalletStateNotifier>().connectDemo();
    // Auth gate in main.dart will rebuild automatically.
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // ── Branding ────────────────────────────────────────────────
              _BrandingHeader(),

              const SizedBox(height: 56),

              // ── Connect card ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.indigo.withAlpha(80),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cüzdanı Bağla',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Monad ağındaki BESS adresinizi girin',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                    const SizedBox(height: 20),

                    // Address text field
                    TextField(
                      controller: _controller,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: '0x…',
                        hintStyle: const TextStyle(color: Colors.white30),
                        errorText: _errorText,
                        filled: true,
                        fillColor: const Color(0xFF0D0D1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.paste, color: Colors.white54),
                          tooltip: 'Panodan Yapıştır',
                          onPressed: _pasteFromClipboard,
                        ),
                      ),
                      onSubmitted: (_) => _onConnect(),
                    ),

                    const SizedBox(height: 16),

                    // Connect button
                    FilledButton.icon(
                      onPressed: _isConnecting ? null : _onConnect,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.account_balance_wallet_outlined),
                      label: Text(_isConnecting ? 'Bağlanıyor…' : 'Bağlan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Divider ──────────────────────────────────────────────────
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'veya',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white12)),
                ],
              ),

              const SizedBox(height: 20),

              // ── Demo mode ────────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _isConnecting ? null : _onDemoMode,
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Demo Modu ile Devam Et'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // ── Footer ───────────────────────────────────────────────────
              Center(
                child: Text(
                  'Powered by Monad ⚡ Parallel EVM',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Branding header widget
// ---------------------------------------------------------------------------

class _BrandingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Lightning bolt icon in gradient container
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withAlpha(100),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.bolt,
            color: Colors.white,
            size: 44,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'ParallelPulse',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Merkezi Olmayan Enerji Topluluğu',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
                letterSpacing: 0.3,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Feature chips
        Wrap(
          spacing: 8,
          children: [
            _FeatureChip(label: '10K+ TPS', icon: Icons.speed),
            _FeatureChip(label: 'BESS Ödülleri', icon: Icons.battery_charging_full),
            _FeatureChip(label: 'Parallel EVM', icon: Icons.hub),
          ],
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 14, color: Colors.indigo.shade300),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
      backgroundColor: const Color(0xFF1A1A2E),
      side: BorderSide(color: Colors.indigo.withAlpha(50)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
