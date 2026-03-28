---
name: Docker Compose Microservices Architecture
description: Compose services, Dockerfiles, profiles, and startup commands for ParallelPulse
type: project
---

## Docker Compose microservices architecture is complete.

### Files created
- `docker-compose.yml` — Full dev + prod spec
- `docker-compose.prod.yml` — Monad Testnet overlay
- `.env.example` — Root environment template
- `backend/Dockerfile` — python:3.12-slim, curl + gcc + web3
- `energy/Dockerfile.parallelpulse` — python:3.12-slim, parallel_pulse only (demo mode)
- `contracts/Dockerfile.deployer` — ghcr.io/foundry-rs/foundry:latest, one-shot deploy
- `backend/.dockerignore`, `energy/.dockerignore`, `contracts/.dockerignore`

### Services
| Service | Profile | Image/Build | Port |
|---------|---------|-------------|------|
| anvil | dev | ghcr.io/foundry-rs/foundry:latest | 8545 |
| deployer | dev | contracts/Dockerfile.deployer | — |
| backend | (always) | backend/Dockerfile | 8000 |
| energy | (always) | energy/Dockerfile.parallelpulse | — |

### Startup commands
```bash
# Dev (local Anvil EVM):
docker compose --profile dev up --build

# Prod (Monad Testnet, requires .env with real CONTRACT_ADDRESS + PRIVATE_KEY):
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build
```

### Key design decisions
- Separate mappings in EnergyMarket (not struct) → parallel EVM: each BESS address writes to non-overlapping storage slot
- `depends_on: deployer: required: false` — backend waits for deployer in dev, skips in prod (Docker Compose 2.4+ feature)
- Deterministic Anvil contract address: `0x5FbDB2315678afecb367f032d93F642f64180aa3` (account #0, nonce=0)
- energy container uses demo SOC sawtooth mode (gsy-e not installed in Docker)
- Network: `parallelpulse-net` (bridge)

**Why:** The `required: false` dependency avoids maintaining two separate compose files for dev vs prod service ordering.
**How to apply:** When adding new services, follow same pattern: no profile for always-on services, `dev` profile for local-only infrastructure.
