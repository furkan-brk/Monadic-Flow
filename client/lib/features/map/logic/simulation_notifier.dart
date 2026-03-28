import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'simulation_engine.dart';
import 'simulation_models.dart';

/// ChangeNotifier that drives the smart-contract energy simulation.
///
/// The four simulation nodes are placed south of the existing IEEE 33-bus
/// network so they do not overlap with it on the map.
class SimulationNotifier extends ChangeNotifier {
  // --------------------------------------------------------------------------
  // Node factories
  // --------------------------------------------------------------------------

  static SimNode _defP1() => SimNode(
        id: 'sim_p1',
        label: 'Güneş Santrali',
        type: SimNodeType.producer,
        position: const LatLng(40.9660, 29.0480),
        capacityKwh: 50.0,
        pricePerKwh: 2.5,
      );

  static SimNode _defP2() => SimNode(
        id: 'sim_p2',
        label: 'Rüzgar Santrali',
        type: SimNodeType.producer,
        position: const LatLng(40.9660, 29.0980),
        capacityKwh: 60.0,
        pricePerKwh: 1.8,
      );

  static SimNode _defHouse() => SimNode(
        id: 'sim_house',
        label: 'Ev',
        type: SimNodeType.house,
        position: const LatLng(40.9620, 29.0730),
        demandKwh: 40.0,
      );

  static SimNode _defBattery() => SimNode(
        id: 'sim_battery',
        label: 'Batarya',
        type: SimNodeType.battery,
        position: const LatLng(40.9700, 29.0730),
        maxCapacityKwh: 100.0,
        currentSocPercent: 25.0,
        thresholdPercent: 30.0,
      );

  // --------------------------------------------------------------------------
  // State
  // --------------------------------------------------------------------------

  late SimNode producer1 = _defP1();
  late SimNode producer2 = _defP2();
  late SimNode house = _defHouse();
  late SimNode battery = _defBattery();

  SimulationScenario currentScenario = SimulationScenario.scenario1;
  List<EnergyContract> activeContracts = [];
  List<ContractLogEntry> contractLog = [];
  bool isRunning = false;
  bool isPanelOpen = false;

  /// Animated SOC value used for smooth battery fill during Scenario 3.
  double animatedSoc = 25.0;

  Timer? _batteryTimer;

  // --------------------------------------------------------------------------
  // Accessors
  // --------------------------------------------------------------------------

  List<SimNode> get simNodes => [producer1, producer2, house, battery];

  SimNode nodeById(String id) =>
      simNodes.firstWhere((n) => n.id == id, orElse: () => producer1);

  // --------------------------------------------------------------------------
  // Panel
  // --------------------------------------------------------------------------

  void togglePanel() {
    isPanelOpen = !isPanelOpen;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Scenario selection
  // --------------------------------------------------------------------------

  void selectScenario(SimulationScenario s) {
    currentScenario = s;
    _clearRunState();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Run
  // --------------------------------------------------------------------------

  void runScenario() {
    _clearRunState();
    isRunning = true;
    notifyListeners();

    late final List<EnergyContract> contracts;

    switch (currentScenario) {
      case SimulationScenario.scenario1:
        contracts = SimulationEngine.evaluateScenario1(
          producer1: producer1,
          producer2: producer2,
          house: house,
        );
        activeContracts = contracts;
        _appendLog(contracts);
        Future.delayed(const Duration(seconds: 4), _markComplete);

      case SimulationScenario.scenario2:
        contracts = SimulationEngine.evaluateScenario2(
          producer1: producer1,
          producer2: producer2,
          house: house,
        );
        activeContracts = contracts;
        _appendLog(contracts);
        Future.delayed(const Duration(seconds: 4), _markComplete);

      case SimulationScenario.scenario3:
        contracts = SimulationEngine.evaluateScenario3(
          producer1: producer1,
          producer2: producer2,
          battery: battery,
        );
        activeContracts = contracts;
        _appendLog(contracts);
        if (contracts.isEmpty) {
          _addInfoLog('🔋 Batarya eşiğin üzerinde — kontrat gerekmez!');
          isRunning = false;
        } else {
          _animateBatteryCharge(contracts);
        }
    }

    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Reset
  // --------------------------------------------------------------------------

  void resetSimulation() {
    _batteryTimer?.cancel();
    _clearRunState();
    battery.currentSocPercent = _defBattery().currentSocPercent;
    animatedSoc = battery.currentSocPercent;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Parameter setters
  // --------------------------------------------------------------------------

  void setP1Capacity(double v) => _set(() => producer1.capacityKwh = v);
  void setP1Price(double v) => _set(() => producer1.pricePerKwh = v);
  void setP2Capacity(double v) => _set(() => producer2.capacityKwh = v);
  void setP2Price(double v) => _set(() => producer2.pricePerKwh = v);
  void setHouseDemand(double v) => _set(() => house.demandKwh = v);
  void setBatteryMax(double v) => _set(() => battery.maxCapacityKwh = v);
  void setBatterySoc(double v) {
    battery.currentSocPercent = v;
    animatedSoc = v;
    notifyListeners();
  }

  void setBatteryThreshold(double v) => _set(() => battery.thresholdPercent = v);

  void _set(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Internals
  // --------------------------------------------------------------------------

  void _clearRunState() {
    _batteryTimer?.cancel();
    isRunning = false;
    activeContracts = [];
  }

  void _appendLog(List<EnergyContract> contracts) {
    for (final c in contracts.reversed) {
      final from = nodeById(c.fromNodeId).label;
      final to = nodeById(c.toNodeId).label;
      final msg = c.status == ContractStatus.rejected
          ? '❌ $from teklifi reddedildi (${c.pricePerKwh.toStringAsFixed(1)} MON/kWh)'
          : '✅ $from → $to | ${c.amountKwh.toStringAsFixed(1)} kWh × ${c.pricePerKwh.toStringAsFixed(1)} = ${c.totalTokens.toStringAsFixed(2)} MON';
      contractLog.insert(
        0,
        ContractLogEntry(
          contract: c,
          fromLabel: from,
          toLabel: to,
          message: msg,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void _addInfoLog(String msg) {
    final dummy = EnergyContract(
      contractId: '0' * 16,
      fromNodeId: '',
      toNodeId: '',
      amountKwh: 0,
      pricePerKwh: 0,
      totalTokens: 0,
      timestamp: DateTime.now(),
      status: ContractStatus.complete,
    );
    contractLog.insert(
      0,
      ContractLogEntry(
        contract: dummy,
        fromLabel: '',
        toLabel: '',
        message: msg,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _markComplete() {
    for (final c in activeContracts) {
      if (c.status == ContractStatus.active) c.status = ContractStatus.complete;
    }
    isRunning = false;
    notifyListeners();
  }

  void _animateBatteryCharge(List<EnergyContract> contracts) {
    const targetSoc = 80.0;
    final startSoc = battery.currentSocPercent;
    const steps = 80; // 80 × 50 ms = 4 s
    int step = 0;

    _batteryTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      step++;
      final progress = step / steps;
      animatedSoc = startSoc + (targetSoc - startSoc) * progress;
      battery.currentSocPercent = animatedSoc;
      notifyListeners();

      if (step >= steps) {
        t.cancel();
        _markComplete();
      }
    });
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    super.dispose();
  }
}
