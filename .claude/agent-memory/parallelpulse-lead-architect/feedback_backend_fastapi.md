---
name: Backend Technology Choice — FastAPI
description: Why FastAPI was chosen over Go/Node.js for the ParallelPulse backend service
type: feedback
---

Use Python FastAPI for the backend — not Go, not Node.js.

**Why:** The simulation layer (energy/parallel_pulse/) is already Python. web3.py event listening is Python. Same language = zero context switch during a 24h hackathon. Go would require learning go-ethereum (2-3h cost). Node.js would require duplicating ABI parsing. FastAPI is the fastest path.

**How to apply:** Whenever the backend/ directory needs new features, stay in Python/FastAPI. The backend is a thin relay — it polls Monad contract events via web3.py and forwards to Flutter via WebSocket. Don't add heavy logic here.
