import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/simulation_models.dart';
import '../logic/simulation_notifier.dart';

/// Floating control panel for the smart-contract simulation.
///
/// Appears as a collapsible card anchored to the left edge of the map.
/// Contains: scenario picker, parameter sliders, run/reset buttons, and
/// a scrollable contract log.
class SimControlPanel extends StatelessWidget {
  const SimControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SimulationNotifier>(
      builder: (context, sim, _) {
        if (!sim.isPanelOpen) {
          return Positioned(
            left: 12,
            bottom: 80,
            child: _ToggleFab(sim: sim),
          );
        }

        return Positioned(
          left: 12,
          top: 60,
          bottom: 72,
          width: 310,
          child: Column(
            children: [
              _ToggleFab(sim: sim, isOpen: true),
              const SizedBox(height: 8),
              Expanded(
                child: _PanelCard(sim: sim),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle FAB
// ---------------------------------------------------------------------------

class _ToggleFab extends StatelessWidget {
  const _ToggleFab({required this.sim, this.isOpen = false});
  final SimulationNotifier sim;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sim.togglePanel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C3DE0), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C3DE0).withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.electric_bolt, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              isOpen ? 'Paneli Kapat' : 'Simülasyon',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main card content
// ---------------------------------------------------------------------------

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.sim});
  final SimulationNotifier sim;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111128).withAlpha(235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Tab bar
              Container(
                color: const Color(0xFF0D0D1A),
                child: const TabBar(
                  indicatorColor: Color(0xFF6C3DE0),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    Tab(text: '⚙️  Kontroller'),
                    Tab(text: '📋  Kontrat Log'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ControlsTab(sim: sim),
                    _LogTab(sim: sim),
                  ],
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
// Controls tab
// ---------------------------------------------------------------------------

class _ControlsTab extends StatelessWidget {
  const _ControlsTab({required this.sim});
  final SimulationNotifier sim;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Scenario selector ---
          _SectionLabel('📊 SENARYO SEÇ'),
          const SizedBox(height: 8),
          _ScenarioPicker(sim: sim),
          const SizedBox(height: 14),

          // --- House demand (shown in scenario 1 & 2) ---
          if (sim.currentScenario != SimulationScenario.scenario3) ...[
            _SectionLabel('🏠 EV İHTİYACI'),
            _SliderRow(
              label: 'İhtiyaç',
              unit: 'kWh',
              value: sim.house.demandKwh,
              min: 5,
              max: 150,
              onChanged: sim.setHouseDemand,
            ),
            const SizedBox(height: 12),
          ],

          // --- Producer 1 ---
          _SectionLabel('☀️ ÜRETİCİ 1 — ${sim.producer1.label}'),
          _SliderRow(
            label: 'Kapasite',
            unit: 'kWh',
            value: sim.producer1.capacityKwh,
            min: 5,
            max: 120,
            onChanged: sim.setP1Capacity,
          ),
          _SliderRow(
            label: 'Fiyat',
            unit: 'MON/kWh',
            value: sim.producer1.pricePerKwh,
            min: 0.1,
            max: 10,
            divisions: 99,
            onChanged: sim.setP1Price,
          ),
          const SizedBox(height: 12),

          // --- Producer 2 ---
          _SectionLabel('💨 ÜRETİCİ 2 — ${sim.producer2.label}'),
          _SliderRow(
            label: 'Kapasite',
            unit: 'kWh',
            value: sim.producer2.capacityKwh,
            min: 5,
            max: 120,
            onChanged: sim.setP2Capacity,
          ),
          _SliderRow(
            label: 'Fiyat',
            unit: 'MON/kWh',
            value: sim.producer2.pricePerKwh,
            min: 0.1,
            max: 10,
            divisions: 99,
            onChanged: sim.setP2Price,
          ),
          const SizedBox(height: 12),

          // --- Battery (shown in scenario 3) ---
          if (sim.currentScenario == SimulationScenario.scenario3) ...[
            _SectionLabel('🔋 BATARYA'),
            _SliderRow(
              label: 'Maks Kapasite',
              unit: 'kWh',
              value: sim.battery.maxCapacityKwh,
              min: 20,
              max: 500,
              onChanged: sim.setBatteryMax,
            ),
            _SliderRow(
              label: 'Mevcut SOC',
              unit: '%',
              value: sim.battery.currentSocPercent,
              min: 0,
              max: 100,
              onChanged: sim.setBatterySoc,
            ),
            _SliderRow(
              label: 'Eşik',
              unit: '%',
              value: sim.battery.thresholdPercent,
              min: 5,
              max: 80,
              onChanged: sim.setBatteryThreshold,
            ),
            const SizedBox(height: 12),
          ],

          // --- Action buttons ---
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: sim.isRunning ? '⏳ Çalışıyor…' : '▶  Çalıştır',
                  color: const Color(0xFF6C3DE0),
                  onPressed: sim.isRunning ? null : sim.runScenario,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: '↺  Sıfırla',
                  color: Colors.blueGrey.shade700,
                  onPressed: sim.resetSimulation,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Log tab
// ---------------------------------------------------------------------------

class _LogTab extends StatelessWidget {
  const _LogTab({required this.sim});
  final SimulationNotifier sim;

  @override
  Widget build(BuildContext context) {
    if (sim.contractLog.isEmpty) {
      return const Center(
        child: Text(
          'Henüz kontrat yok.\nSenaryoyu çalıştır.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: sim.contractLog.length,
      itemBuilder: (_, i) {
        final entry = sim.contractLog[i];
        final isRejected =
            entry.contract.status == ContractStatus.rejected;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isRejected ? Colors.red : Colors.green).withAlpha(18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  (isRejected ? Colors.red : Colors.greenAccent).withAlpha(50),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.contract.shortId,
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.message,
                style: TextStyle(
                  color: isRejected ? Colors.red.shade300 : Colors.white70,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Scenario picker chips
// ---------------------------------------------------------------------------

class _ScenarioPicker extends StatelessWidget {
  const _ScenarioPicker({required this.sim});
  final SimulationNotifier sim;

  static const _labels = [
    ('1', 'Tek Kaynak'),
    ('2', 'Çift Kaynak'),
    ('3', 'Batarya'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final scenario = SimulationScenario.values[i];
        final isSelected = sim.currentScenario == scenario;
        return Expanded(
          child: GestureDetector(
            onTap: () => sim.selectScenario(scenario),
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6C3DE0)
                    : Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6C3DE0)
                      : Colors.white.withAlpha(30),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _labels[i].$1,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _labels[i].$2,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white70 : Colors.white30,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Slider row
// ---------------------------------------------------------------------------

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: const Color(0xFF6C3DE0),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF6C3DE0).withAlpha(40),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions ?? (max - min).toInt(),
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 68,
            child: Text(
              '${value.toStringAsFixed(unit == 'MON/kWh' ? 1 : 0)} $unit',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action button
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: onPressed == null ? Colors.white12 : color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: color.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: onPressed == null ? Colors.white30 : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
