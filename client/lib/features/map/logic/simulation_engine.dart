import 'dart:math';

import 'simulation_models.dart';

/// Pure contract-evaluation logic — mirrors what an on-chain EnergyMarket
/// Solidity contract would compute, but executed locally for the simulation.
class SimulationEngine {
  SimulationEngine._();

  // --------------------------------------------------------------------------
  // Scenario 1 — single cheapest source wins
  // --------------------------------------------------------------------------

  static List<EnergyContract> evaluateScenario1({
    required SimNode producer1,
    required SimNode producer2,
    required SimNode house,
  }) {
    final cheaper =
        producer1.pricePerKwh <= producer2.pricePerKwh ? producer1 : producer2;
    final expensive = cheaper == producer1 ? producer2 : producer1;

    final amount = min(house.demandKwh, cheaper.capacityKwh);

    return [
      EnergyContract(
        contractId: _newId(),
        fromNodeId: cheaper.id,
        toNodeId: house.id,
        amountKwh: amount,
        pricePerKwh: cheaper.pricePerKwh,
        totalTokens: amount * cheaper.pricePerKwh,
        timestamp: DateTime.now(),
        status: ContractStatus.active,
      ),
      EnergyContract(
        contractId: _newId(),
        fromNodeId: expensive.id,
        toNodeId: house.id,
        amountKwh: 0,
        pricePerKwh: expensive.pricePerKwh,
        totalTokens: 0,
        timestamp: DateTime.now(),
        status: ContractStatus.rejected,
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // Scenario 2 — split optimally across both sources
  // --------------------------------------------------------------------------

  static List<EnergyContract> evaluateScenario2({
    required SimNode producer1,
    required SimNode producer2,
    required SimNode house,
  }) {
    final sorted = [producer1, producer2]
      ..sort((a, b) => a.pricePerKwh.compareTo(b.pricePerKwh));

    final cheaper = sorted[0];
    final pricier = sorted[1];

    double remaining = house.demandKwh;
    final fromCheaper = min(remaining, cheaper.capacityKwh);
    remaining -= fromCheaper;
    final fromPricier = min(remaining, pricier.capacityKwh);

    final contracts = <EnergyContract>[];

    if (fromCheaper > 0) {
      contracts.add(EnergyContract(
        contractId: _newId(),
        fromNodeId: cheaper.id,
        toNodeId: house.id,
        amountKwh: fromCheaper,
        pricePerKwh: cheaper.pricePerKwh,
        totalTokens: fromCheaper * cheaper.pricePerKwh,
        timestamp: DateTime.now(),
        status: ContractStatus.active,
      ));
    }

    if (fromPricier > 0) {
      contracts.add(EnergyContract(
        contractId: _newId(),
        fromNodeId: pricier.id,
        toNodeId: house.id,
        amountKwh: fromPricier,
        pricePerKwh: pricier.pricePerKwh,
        totalTokens: fromPricier * pricier.pricePerKwh,
        timestamp: DateTime.now(),
        status: ContractStatus.active,
      ));
    }

    return contracts;
  }

  // --------------------------------------------------------------------------
  // Scenario 3 — battery self-charges when SOC < threshold
  // --------------------------------------------------------------------------

  static List<EnergyContract> evaluateScenario3({
    required SimNode producer1,
    required SimNode producer2,
    required SimNode battery,
  }) {
    if (battery.currentSocPercent >= battery.thresholdPercent) return [];

    const targetSoc = 80.0;
    final deficitPct = targetSoc - battery.currentSocPercent;
    final neededKwh = (deficitPct / 100.0) * battery.maxCapacityKwh;

    // Reuse Scenario 2 logic with battery acting as the buyer
    final tempBuyer = SimNode(
      id: battery.id,
      label: battery.label,
      type: SimNodeType.house,
      position: battery.position,
      demandKwh: neededKwh,
    );

    return evaluateScenario2(
      producer1: producer1,
      producer2: producer2,
      house: tempBuyer,
    ).map((c) => EnergyContract(
          contractId: c.contractId,
          fromNodeId: c.fromNodeId,
          toNodeId: battery.id,
          amountKwh: c.amountKwh,
          pricePerKwh: c.pricePerKwh,
          totalTokens: c.totalTokens,
          timestamp: c.timestamp,
          status: c.status,
        ))
        .toList();
  }

  // --------------------------------------------------------------------------

  static final _rng = Random();

  static String _newId() {
    const hex = '0123456789abcdef';
    return List.generate(16, (_) => hex[_rng.nextInt(16)]).join();
  }
}
