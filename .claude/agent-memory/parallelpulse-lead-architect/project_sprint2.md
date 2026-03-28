---
name: Sprint 2 Grid Topology Visualization
description: Sprint 2 deliverables — IEEE 33-bus live grid viz, GridStatusUpdate event, BottomNav shell
type: project
---

Sprint 2 adds a live **IEEE 33-bus topology visualization screen** to the Flutter frontend, driven by a new `GridStatusUpdate` WebSocket event from the backend.

**Why:** User needs to see which buses have BESS units, which lines have failed, and where energy is being injected — matching the WhatsApp IEEE 33-bus schematic exactly.

## New Files

| File | Purpose |
|------|---------|
| `backend/app/grid_topology.py` | Static topology: BUS_TYPES, ADJACENCY, FAULT_LINE_MAP, LOAD_BUS_MAP, `build_grid_status_update()`, `bess_address_to_bus()` |
| `client/lib/core/models/grid_state.dart` | BusType, BusStatus, FeedingFlow, BusNodeState, GridTopologyNotifier |
| `client/lib/features/grid/grid_topology_screen.dart` | Main grid screen with InteractiveViewer, BESS summary cards |
| `client/lib/features/grid/widgets/ieee33_painter.dart` | CustomPainter: 33 buses, dashed-red failed lines, animated flow dots |
| `client/lib/features/grid/widgets/grid_legend.dart` | Colour legend row (orange/pink/green/cyan/X) |

## Modified Files

| File | Change |
|------|--------|
| `backend/app/models.py` | Added 5 new nullable fields: failed_buses, failed_lines, feeding_bess_buses, feeding_flows, bess_soc_map |
| `backend/app/chain_listener.py` | Emits GridStatusUpdate after EmergencyActivated and TransferSettled events; accepts soc_getter callable |
| `backend/app/main.py` | Maintains `_bess_soc_by_bus` dict; emits GridStatusUpdate after /internal/soc; sends initial GridStatusUpdate on WS connect; ChainEventListener gets soc_getter=_get_bess_soc |
| `backend/app/config.py` | Added bess_a_address, bess_b_address settings |
| `client/lib/core/models/event_message.dart` | Added 5 new nullable fields + safe fromJson parsers for matrix/map types |
| `client/lib/main.dart` | AppShell with IndexedStack + NavigationBar (Dashboard / Grid tabs); GridTopologyNotifier in MultiProvider; fault badge on Grid tab |

## Key Design Decisions

- **Painter repaint strategy**: `super(repaint: flowAnimation)` — the Animation<double> drives smooth dot travel; structural changes trigger repaint via `shouldRepaint`.
- **Normalised positions**: All 33 bus positions stored as Offset(0-1, 0-1), scaled to canvas size at paint time. Lateral B (top) at y=0.13, A2 at y=0.25, trunk at y=0.50, A1 at y=0.78.
- **IndexedStack**: Both screens stay alive when switching tabs — animation states preserved.
- **GridTopologyNotifier does NOT call ws.connect()** — BESSStateNotifier owns that. Both subscribe to the same broadcast stream.
- **Initial GridStatusUpdate on WS connect**: Backend sends current BESS SOC to new clients immediately.
- **Fault badge on Grid tab**: `Consumer<GridTopologyNotifier>` inside `_GridTabIcon` shows orange badge when `failedLineKeys.isNotEmpty`.

## New Env Vars (backend/.env)

```
BESS_A_ADDRESS=0x...   # Bus 22
BESS_B_ADDRESS=0x...   # Bus 12
```

**How to apply:** When adding features touching the grid viz, reference ieee33_painter.dart `_pos` map and grid_topology.py `ADJACENCY` list — these must stay in sync.
