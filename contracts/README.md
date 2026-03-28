# ParallelPulse — Smart Contracts

Solidity smart contract layer for the ParallelPulse decentralised energy market demo, deployed on the Monad blockchain.

## Contract overview

### `EnergyMarket.sol`

A single market contract that coordinates peer-to-peer energy trading between BESS (Battery Energy Storage System) owners and consumer loads.

| Concern | Design choice |
|---|---|
| Ownership | OpenZeppelin `Ownable` (v5). The deployer (Python backend) is the owner. |
| Reentrancy | OpenZeppelin `ReentrancyGuard` on all ETH-moving functions. |
| Emergency pricing | Owner activates an emergency for a specific grid bus; subsequent offers are stored at 5x the submitted price, mirroring balancing-market scarcity in the gsy-e engine. |
| Settlement | Owner calls `settleTransfer` after the off-chain simulation resolves optimal dispatch for a time slot. ETH earnings are credited to the BESS and withdrawn by the BESS owner at any time. |
| Monad parallelism | All per-actor state lives in separate top-level mappings (`offerAmount`, `offerPrice`, `isCriticalLoad`, `earnings`). Concurrent `submitEnergyOffer` calls from different BESS addresses write to non-overlapping storage slots and execute in parallel without contention. |

## Prerequisites

- [Foundry](https://getfoundry.sh/) installed (`forge`, `cast`, `anvil`)
- A funded wallet on Monad testnet

## Setup

```bash
# 1. Install OpenZeppelin Contracts v5
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit

# 2. Copy the environment template
cp .env.example .env
# Edit .env and fill in your PRIVATE_KEY
```

## Build

```bash
forge build
```

## Test

```bash
# Verbose output with gas reports
forge test -vv

# Extra verbosity (shows traces on failure)
forge test -vvvv
```

## Deploy to Monad testnet

```bash
source .env   # load PRIVATE_KEY

forge script script/Deploy.s.sol \
  --rpc-url https://testnet-rpc.monad.xyz \
  --broadcast \
  -vvvv
```

The deployed address is printed to stdout and written to `broadcast/Deploy.s.sol/<chainId>/run-latest.json`.

## Export ABI (for Flutter client / Python backend)

```bash
forge build
cat out/EnergyMarket.sol/EnergyMarket.json | python3 -m json.tool | grep -A9999 '"abi"'
```

Or copy `out/EnergyMarket.sol/EnergyMarket.json` directly — it contains the full ABI, bytecode, and metadata.

## Key function signatures

| Function | Caller | Purpose |
|---|---|---|
| `activateEmergency(uint256, address[])` | Owner | Mark a bus as in emergency; 5x price multiplier activates |
| `deactivateEmergency()` | Owner | Clear emergency mode |
| `submitEnergyOffer(uint256, uint256)` | Any BESS | Post energy (Wh) at a price (wei/Wh) |
| `settleTransfer(address, address, uint256)` | Owner | Record an energy delivery; credit earnings to the BESS |
| `withdrawEarnings()` | Any BESS | Pull accumulated ETH earnings |
| `receive()` | Backend | Fund the contract with ETH for earnings payouts |
