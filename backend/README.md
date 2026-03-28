## ParallelPulse Backend

FastAPI WebSocket relay between Monad blockchain and Flutter client.

### Setup

```bash
pip install -r requirements.txt
cp .env.example .env  # edit CONTRACT_ADDRESS after deploy
```

### Run

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

### Test

```bash
# Live WebSocket stream
websocat ws://localhost:8000/ws

# Health check
curl http://localhost:8000/health

# Push a simulated SOC update (triggers broadcast to all WS clients)
curl -X POST http://localhost:8000/internal/soc \
  -H "Content-Type: application/json" \
  -H "X-Internal-Token: parallelpulse-internal-secret" \
  -d '{"bess_address":"0x123","soc_percent":75.0,"earnings_wei":0}'

# Read on-chain BESS state (requires CONTRACT_ADDRESS set in .env)
curl http://localhost:8000/bess/0xYourBESSAddress/state
```

### Architecture

```
Flutter client  ──WS /ws──────────────────────────────┐
                                                        │
Monad chain  ──eth_newFilter poll──► ChainEventListener─┼─► broadcast()
                                                        │
gsy-e sim runner ──POST /internal/soc──────────────────┘
```

### Environment Variables

| Variable           | Default                                    | Description                              |
|--------------------|--------------------------------------------|------------------------------------------|
| `CONTRACT_ADDRESS` | `0x000...000`                              | Deployed ParallelPulse contract address  |
| `RPC_URL`          | `https://testnet-rpc.monad.xyz`            | Monad JSON-RPC endpoint                  |
| `INTERNAL_TOKEN`   | `parallelpulse-internal-secret`            | Shared secret for `/internal/soc`        |
| `HOST`             | `0.0.0.0`                                  | Bind address                             |
| `PORT`             | `8000`                                     | Bind port                                |

### Notes

- Python 3.11+ required.
- Run `uvicorn` from the `backend/` directory so `.env` is found automatically.
- When `CONTRACT_ADDRESS` is the zero address the chain listener is disabled; the backend still relays `/internal/soc` events to WebSocket clients.
- All WebSocket messages conform to the `EventMessage` schema (unused fields are `null`).
