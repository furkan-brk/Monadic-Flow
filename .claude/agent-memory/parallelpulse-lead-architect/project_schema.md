---
name: Inter-Layer EventMessage Schema
description: Canonical JSON schema for EventMessage crossing Python → Backend → Flutter WebSocket
type: project
---

All WebSocket messages from backend to Flutter follow this schema (all fields present, optional fields null):

```json
// EmergencyActivated (from contract event)
{
  "event_type": "EmergencyActivated",
  "bus_id": 17,
  "emergency_mode": true,
  "critical_load_ids": ["0xabc..."],
  "timestamp_ms": 1711584000000,
  "bess_address": null,
  "load_address": null,
  "amount_wh": null,
  "cost_wei": null,
  "soc_percent": null,
  "earnings_wei": null
}

// TransferSettled (from contract event)
{
  "event_type": "TransferSettled",
  "bess_address": "0x123...",
  "load_address": "0x456...",
  "amount_wh": 5000,
  "cost_wei": 25000000000000000,
  "timestamp_ms": 1711584030000,
  "bus_id": null,
  "emergency_mode": null,
  "soc_percent": null,
  "earnings_wei": null
}

// SOCUpdate (from Python runner.py → /internal/soc → broadcast)
{
  "event_type": "SOCUpdate",
  "bess_address": "0x123...",
  "soc_percent": 67.4,
  "earnings_wei": 50000000000000000,
  "timestamp_ms": 1711584060000,
  "bus_id": null,
  "load_address": null,
  "amount_wh": null,
  "cost_wei": null,
  "emergency_mode": null
}
```

## Python → Solidity Mapping
- `FaultSignal.bus_id: int` → `activateEmergency(uint256 busId, ...)`
- `FaultSignal.critical_load_ids: list[str]` → `address[]` via `keccak256(load_name)[-20 bytes]`
- SOC lives off-chain (not in contract) — relayed via `/internal/soc`

**How to apply:** Use this when implementing any layer that produces or consumes EventMessage. Dart `fromJson` must use `(json['soc_percent'] as num?)?.toDouble()` pattern.
