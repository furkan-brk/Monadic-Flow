---
name: ParallelPulse BESS Dashboard Project
description: Flutter client for a Battery Energy Storage System dashboard that connects to a WebSocket backend on ws://localhost:8000/ws
type: project
---

The Flutter client at `client/` is the ParallelPulse BESS (Battery Energy Storage System) dashboard.

**Why:** Visualises real-time energy market simulation data from the gsy-e backend (or a future dedicated backend at ws://localhost:8000/ws).

**Architecture decisions:**
- State management: `provider` (ChangeNotifier pattern) — `BESSStateNotifier` holds `BESSState`
- WebSocket: `web_socket_channel` via `WebSocketService` — auto-reconnects on error/done with 3s delay
- `BESSStateNotifier` constructor immediately subscribes to events and calls `ws.connect()`
- Both `WebSocketService` and `BESSStateNotifier` are created in `main()` outside the widget tree and injected via `MultiProvider`

**Event types from backend (ws://localhost:8000/ws):**
- `SOCUpdate` — updates socPercent and earningsWei
- `EmergencyActivated` — sets emergencyMode=true (5× pricing), carries bus_id and critical_load_ids
- `TransferSettled` — accumulates earningsWei (bess_address → load_address transfer)

**How to apply:** When adding new event types or UI widgets, follow the existing pattern: parse in `EventMessage.fromJson`, handle in `BESSStateNotifier._handleEvent`, reflect in `BESSState.copyWith`.
