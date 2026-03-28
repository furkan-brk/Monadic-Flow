---
name: ParallelPulse Architecture
description: Full stack architecture — layers, file locations, data flow, and key design decisions for ParallelPulse
type: project
---

ParallelPulse is a 4-layer system deployed in the Monad Blitz Hackathon monorepo.

**Why:** Solve "Line Fail" (Power Outage) using decentralized BESS assets settled on Monad's 10,000+ TPS Parallel EVM.

## Data Flow
```
Python IEEE-33 Simulation (energy/parallel_pulse/)
  → FaultSignal → MonadBridge.emit_fault_signal() [web3.py]
  → EnergyMarket.activateEmergency() on Monad Testnet
  → Contract emits EmergencyActivated event
  → FastAPI backend chain_listener polls via web3.py filter
  → WebSocket /ws broadcasts EventMessage JSON
  → Flutter WebSocketService.events Stream
  → BESSStateNotifier → DashboardScreen rebuild
```

## Layer Locations
- **contracts/src/EnergyMarket.sol** — Solidity, Foundry toolchain, OpenZeppelin v5.0.2
- **energy/parallel_pulse/** — Python package (NOT inside gsy-e submodule), WSL2 only
- **energy/src/gsy_e/setup/ieee33_bus.py** — gsy-e setup module for IEEE 33-bus topology
- **energy/src/gsy_e/models/strategy/bess_emergency_strategy.py** — StorageStrategy subclass
- **backend/app/** — Python FastAPI service, WebSocket relay + chain listener
- **client/lib/** — Flutter, Provider + ChangeNotifier pattern

## Key Design Decisions
- Foundry (not Hardhat) for contracts — no npm, saf Solidity testleri
- FastAPI (not Go/Node) for backend — same language as simulation, zero context switch
- Separate mappings (not structs) in EnergyMarket.sol → Monad parallel EVM optimization
- `BESSStateNotifier` (ChangeNotifier) not raw StreamBuilder → accumulates state across events
- WSL2 required for all Python/gsy-e work — NOT native Windows

## Monad Testnet
- RPC: https://testnet-rpc.monad.xyz
- Deploy: `forge script script/Deploy.s.sol --rpc-url https://testnet-rpc.monad.xyz --broadcast`

**How to apply:** Reference these locations when implementing features. Always verify file exists before recommending paths.
