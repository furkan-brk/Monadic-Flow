import 'package:latlong2/latlong.dart';

enum SimNodeType { producer, house, battery }

enum SimulationScenario { scenario1, scenario2, scenario3 }

enum ContractStatus { pending, active, rejected, complete }

/// A node participating in the smart-contract energy simulation.
class SimNode {
  final String id;
  final String label;
  final SimNodeType type;
  final LatLng position;

  // Producer
  double capacityKwh;
  double pricePerKwh; // MON tokens per kWh

  // House
  double demandKwh;

  // Battery
  double maxCapacityKwh;
  double currentSocPercent;
  double thresholdPercent;

  SimNode({
    required this.id,
    required this.label,
    required this.type,
    required this.position,
    this.capacityKwh = 50.0,
    this.pricePerKwh = 2.0,
    this.demandKwh = 40.0,
    this.maxCapacityKwh = 100.0,
    this.currentSocPercent = 80.0,
    this.thresholdPercent = 30.0,
  });
}

/// An energy transfer contract between two simulation nodes.
class EnergyContract {
  final String contractId;
  final String fromNodeId;
  final String toNodeId;
  final double amountKwh;
  final double pricePerKwh;
  final double totalTokens;
  final DateTime timestamp;
  ContractStatus status;

  EnergyContract({
    required this.contractId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.amountKwh,
    required this.pricePerKwh,
    required this.totalTokens,
    required this.timestamp,
    this.status = ContractStatus.pending,
  });

  String get shortId => '0x${contractId.substring(0, 8)}';
}

/// A human-readable contract log entry shown in the UI.
class ContractLogEntry {
  final EnergyContract contract;
  final String fromLabel;
  final String toLabel;
  final String message;
  final DateTime timestamp;

  const ContractLogEntry({
    required this.contract,
    required this.fromLabel,
    required this.toLabel,
    required this.message,
    required this.timestamp,
  });
}
