import 'package:flutter/material.dart';

/// Pulsing red banner shown when the grid enters emergency / 5× pricing mode.
///
/// The banner fades between 70 % and 100 % opacity using a repeating
/// reverse animation to draw the operator's attention.
///
/// Optionally accepts an [onTeklifVer] callback — when provided, a
/// "Teklif Ver →" action button is shown on the right side of the banner so
/// operators can jump straight to the offer sheet from any screen.
class EmergencyBanner extends StatefulWidget {
  const EmergencyBanner({super.key, this.onTeklifVer});

  /// Called when the user taps the "Teklif Ver" CTA inside the banner.
  /// If null, no CTA is rendered (banner stays display-only).
  final VoidCallback? onTeklifVer;

  @override
  State<EmergencyBanner> createState() => _EmergencyBannerState();
}

class _EmergencyBannerState extends State<EmergencyBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: Colors.red[700],
        child: Row(
          children: [
            // ── Warning text ──────────────────────────────────────────────
            const Expanded(
              child: Text(
                '⚠️ ACİL MOD — 5× Fiyat Aktif',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            // ── CTA button (only when callback provided) ──────────────────
            if (widget.onTeklifVer != null)
              TextButton.icon(
                onPressed: widget.onTeklifVer,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withAlpha(30),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white38, width: 1),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.offline_bolt, size: 14),
                label: const Text(
                  'Teklif Ver →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
