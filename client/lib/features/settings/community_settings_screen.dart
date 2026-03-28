import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// SharedPreferences key constants
// ---------------------------------------------------------------------------

const _kMarketType = 'pp_market_type';
const _kFeeType = 'pp_fee_type';
const _kFeeValue = 'pp_fee_value';
const _kSlotLen = 'pp_slot_len';
const _kTickLen = 'pp_tick_len';
const _kSimDays = 'pp_sim_days';

// ---------------------------------------------------------------------------
// Market type options
// ---------------------------------------------------------------------------

const Map<String, String> _marketTypeOptions = {
  'one_sided': 'Tek Taraflı (Pay-as-Offer)',
  'two_sided_bid': 'Çift Taraflı (Pay-as-Bid)',
  'two_sided_clear': 'Çift Taraflı (Pay-as-Clear)',
};

/// Settings screen for market simulation parameters.
///
/// Accessible from the CommunityScreen AppBar via settings icon.
/// Persists all values to [SharedPreferences] on save.
class CommunitySettingsScreen extends StatefulWidget {
  const CommunitySettingsScreen({super.key});

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  // State — defaults match gsy-e simulation defaults
  String _marketType = 'one_sided';
  String _feeType = 'constant';
  double _feeValue = 1.0;
  int _slotLen = 15;
  int _tickLen = 15;
  double _simDays = 1.0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _marketType = prefs.getString(_kMarketType) ?? 'one_sided';
      _feeType = prefs.getString(_kFeeType) ?? 'constant';
      _feeValue = prefs.getDouble(_kFeeValue) ?? 1.0;
      _slotLen = prefs.getInt(_kSlotLen) ?? 15;
      _tickLen = prefs.getInt(_kTickLen) ?? 15;
      _simDays = (prefs.getInt(_kSimDays) ?? 1).toDouble();
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMarketType, _marketType);
    await prefs.setString(_kFeeType, _feeType);
    await prefs.setDouble(_kFeeValue, _feeValue);
    await prefs.setInt(_kSlotLen, _slotLen);
    await prefs.setInt(_kTickLen, _tickLen);
    await prefs.setInt(_kSimDays, _simDays.round());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ayarlar kaydedildi'),
        backgroundColor: Color(0xFF1A2A1A),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: Colors.indigo, size: 20),
            SizedBox(width: 8),
            Text(
              'Piyasa Ayarları',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Market Type ───────────────────────────────────────────
                  _SectionCard(
                    title: 'Piyasa Tipi',
                    icon: Icons.store_outlined,
                    child: DropdownButtonFormField<String>(
                      value: _marketType,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration(),
                      items: _marketTypeOptions.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _marketType = v);
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Grid Fee Type ─────────────────────────────────────────
                  _SectionCard(
                    title: 'Şebeke Ücreti Tipi',
                    icon: Icons.percent_outlined,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'constant',
                          label: Text('Sabit (¢/kWh)'),
                          icon: Icon(Icons.attach_money, size: 16),
                        ),
                        ButtonSegment(
                          value: 'percentage',
                          label: Text('Yüzde (%)'),
                          icon: Icon(Icons.percent, size: 16),
                        ),
                      ],
                      selected: {_feeType},
                      onSelectionChanged: (s) {
                        setState(() {
                          _feeType = s.first;
                          // Reset fee value to a sensible default for the type.
                          _feeValue = _feeType == 'constant' ? 1.0 : 5.0;
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.indigo.withAlpha(120)
                              : Colors.transparent,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : Colors.white54,
                        ),
                        side: WidgetStateProperty.all(
                          const BorderSide(color: Colors.indigo, width: 0.8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Grid Fee Value ────────────────────────────────────────
                  _SectionCard(
                    title: _feeType == 'constant'
                        ? 'Sabit Şebeke Ücreti (¢/kWh)'
                        : 'Şebeke Ücreti Oranı (%)',
                    icon: Icons.tune_outlined,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _feeType == 'constant' ? '0 ¢/kWh' : '%0',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _feeType == 'constant'
                                  ? '${_feeValue.toStringAsFixed(1)} ¢/kWh'
                                  : '%${_feeValue.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _feeType == 'constant' ? '20 ¢/kWh' : '%30',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _feeValue,
                          min: 0.0,
                          max: _feeType == 'constant' ? 20.0 : 30.0,
                          divisions: _feeType == 'constant' ? 40 : 60,
                          activeColor: Colors.indigo,
                          inactiveColor: Colors.white12,
                          onChanged: (v) => setState(() => _feeValue = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Slot Length ───────────────────────────────────────────
                  _SectionCard(
                    title: 'Zaman Dilimi Uzunluğu',
                    icon: Icons.schedule_outlined,
                    child: DropdownButtonFormField<int>(
                      value: _slotLen,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 dakika')),
                        DropdownMenuItem(value: 30, child: Text('30 dakika')),
                        DropdownMenuItem(value: 60, child: Text('60 dakika')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _slotLen = v);
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Tick Length ───────────────────────────────────────────
                  _SectionCard(
                    title: 'Tik Uzunluğu',
                    icon: Icons.timer_outlined,
                    child: DropdownButtonFormField<int>(
                      value: _tickLen,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 saniye')),
                        DropdownMenuItem(value: 30, child: Text('30 saniye')),
                        DropdownMenuItem(value: 60, child: Text('60 saniye')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _tickLen = v);
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Simulation Length ─────────────────────────────────────
                  _SectionCard(
                    title: 'Simülasyon Süresi',
                    icon: Icons.calendar_month_outlined,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '1 gün',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${_simDays.round()} gün',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              '30 gün',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _simDays,
                          min: 1.0,
                          max: 30.0,
                          divisions: 29,
                          activeColor: Colors.indigo,
                          inactiveColor: Colors.white12,
                          onChanged: (v) => setState(() => _simDays = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      // ── Save button ──────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _loading ? null : _saveSettings,
            icon: const Icon(Icons.save_outlined),
            label: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.indigo,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.indigo, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.indigo.withAlpha(80), width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.indigo, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable section card
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.indigo.shade300, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
