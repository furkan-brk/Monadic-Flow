---
name: ParallelPulse contract layer — initial implementation
description: Records the initial smart contract architecture built for ParallelPulse, including design decisions, file layout, and integration points.
type: project
---

Initial smart contract layer for ParallelPulse is live under `contracts/`.

**Why:** Hackathon demo on Monad testnet; Python gsy-e backend drives settlement; Flutter client consumes ABI.

**Files created:**
- `contracts/foundry.toml` — Foundry project config (solc 0.8.20, OZ remapping, 200 optimizer runs)
- `contracts/.env.example` — PRIVATE_KEY + RPC_URL template
- `contracts/.gitignore` — excludes .env, out/, cache/, lib/, broadcast/
- `contracts/src/EnergyMarket.sol` — single core contract
- `contracts/script/Deploy.s.sol` — Foundry broadcast deploy script
- `contracts/test/EnergyMarket.t.sol` — complete Foundry test suite (11 tests)
- `contracts/README.md` — setup, test, deploy, ABI export guide

**Key design decisions:**

1. Single `EnergyMarket` contract rather than a proxy hierarchy — justified by hackathon time constraints and the fact that all settlement logic is owner-gated.

2. Separate top-level mappings (`offerAmount`, `offerPrice`, `isCriticalLoad`, `earnings`) rather than a struct-per-address mapping. This is the primary Monad parallel-EVM optimisation: concurrent `submitEnergyOffer` calls from N BESS addresses write to N non-overlapping storage slots and execute in parallel.

3. OZ v5.x `Ownable(msg.sender)` constructor syntax — required breaking change from v4.

4. `settleTransfer` is owner-only because gsy-e determines dispatch amounts off-chain; the Python backend is the trusted oracle that calls this function after each simulation time slot.

5. `earnings` is a pull-payment pattern (BESS owners call `withdrawEarnings`); the contract must be pre-funded with ETH by the backend via `receive()`.

6. `EMERGENCY_MULTIPLIER = 5` hard-coded constant mirrors the balancing-market premium in gsy-e; price multiplication happens at offer-submission time so the stored price is always the effective price.

**Integration points:**
- ABI export: `forge build && cat out/EnergyMarket.sol/EnergyMarket.json`
- Flutter client reads `isCriticalLoad`, `offerAmount`, `offerPrice`, `earnings` as view calls
- Python backend uses `web3.py` to call `activateEmergency`, `settleTransfer`, `deactivateEmergency`

**How to apply:** When extending or modifying contracts, preserve the flat-mapping pattern for any new per-address state to keep Monad parallelism benefits.
